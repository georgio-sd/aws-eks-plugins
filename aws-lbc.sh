#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# AWS Load Balancer Controller deployment script v0.1
# -----------------------------------------------------------------------------
# Deletes current AWS Load Balancer Controller installation (if it exists) and installs a new one
# Developed by Sam Stewart @babaiant
# eksctl, kubectl, helm and awscli have to be preinstalled
#
# no-iam - do not create service account and IAM role
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "aws-lbc.sh <eks-cluster-name> [no-iam] [region]"
  exit 1
fi
#------------------------------------------------------------------------------
# Getting region and account number
#
if [ "$2" != "no-iam" ] && [ "$2" != "" ]; then
  REGION="$2"
elif [ "$3" != "no-iam" ] && [ "$3" != "" ]; then
  REGION="$3"
else
  REGION=$(aws configure get region)
fi
ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
CLUSTER_VPC=$(aws eks describe-cluster --name $1 --region $REGION --query 'cluster.resourcesVpcConfig.vpcId' --output text)
#------------------------------------------------------------------------------
# Setting up kubectl credentials
#
set -e
aws eks --region $REGION update-kubeconfig --name $1
set +e
#------------------------------------------------------------------------------
# Creating an oidc provider
#
eksctl utils associate-iam-oidc-provider --cluster $1 --approve --region $REGION
#------------------------------------------------------------------------------
# Deleting previous installation
#
helm uninstall aws-load-balancer-controller -n kube-system
#------------------------------------------------------------------------------
# Recreating service acount and IAM role
#
if [ "$2" != "no-iam" ] && [ "$3" != "no-iam" ]; then
  eksctl delete iamserviceaccount \
    --cluster=$1 \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --wait \
    --region=$REGION
  POLICY_ID=$(aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy --query 'Policy.PolicyId' --output text 2>/dev/null)
  if [ "$POLICY_ID" = "" ]; then
    curl -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
    aws iam create-policy \
      --policy-name AWSLoadBalancerControllerIAMPolicy \
      --policy-document file:///tmp/iam_policy.json
  fi
  eksctl create iamserviceaccount \
    --cluster=$1 \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::${ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve \
    --region=$REGION
fi
#------------------------------------------------------------------------------
# AWS LBC deployment
#
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$1 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$REGION \
  --set vpcId=$CLUSTER_VPC \
  --set replicaCount=1 \
  --namespace kube-system
