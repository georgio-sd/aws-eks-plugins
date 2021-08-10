#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# Cluster Autoscaler deployment script v0.1
# -----------------------------------------------------------------------------
# Deletes current Cluster Autoscaler installation (if it exists) and installs a new one
# Developed by Sam Stewart @babaiant
# eksctl, kubectl and awscli have to be preinstalled
#
# no-iam - do not create service account and IAM role
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "cluster-autoscaler.sh <eks-cluster-name> [no-iam] [region]"
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
CLUSTER_VER=$(aws eks describe-cluster --name $1 --region $REGION --query 'cluster.version' --output text)
#------------------------------------------------------------------------------
# Setting up kubectl credentials and getting cluster version
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
curl -o /tmp/cluster-autoscaler.yaml \
  https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
curl -o /tmp/version.go \
  https://raw.githubusercontent.com/kubernetes/autoscaler/cluster-autoscaler-release-${CLUSTER_VER}/cluster-autoscaler/version/version.go
CA_VER=$(sed -n 's/const ClusterAutoscalerVersion = "\(.*\)"/\1/p' /tmp/version.go)

sed -i -z "s/---/@/g; s/[^@]*\nkind: ServiceAccount[^@]*@//g; s/@/---/g" /tmp/cluster-autoscaler.yaml
sed -i -z "s/<YOUR CLUSTER NAME>/$1\n            - --balance-similar-node-groups\n            - --skip-nodes-with-system-pods=false/g" /tmp/cluster-autoscaler.yaml
sed -i "s/cluster-autoscaler:.*/cluster-autoscaler:v${CA_VER}/g" /tmp/cluster-autoscaler.yaml
sed -i -z "s/limits:\n              cpu: \([0-9]*\)m\n              memory: [0-9]*Mi/limits:\n              cpu: \1m\n              memory: 1200Mi/g" /tmp/cluster-autoscaler.yaml
sed -i "s/prometheus.io\/port: '8085'/prometheus.io\/port: '8085'\n        cluster-autoscaler.kubernetes.io\/safe-to-evict: 'false'/g" /tmp/cluster-autoscaler.yaml
kubectl delete -f /tmp/cluster-autoscaler.yaml
#------------------------------------------------------------------------------
# Recreating service acount and IAM role
#
if [ "$2" != "no-iam" ] && [ "$3" != "no-iam" ]; then
  eksctl delete iamserviceaccount \
    --cluster=$1 \
    --namespace=kube-system \
    --name=cluster-autoscaler \
    --wait \
    --region=$REGION
  POLICY_ID=$(aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT}:policy/AmazonEKSClusterAutoscalerPolicy --query 'Policy.PolicyId' --output text 2>/dev/null)
  if [ "$POLICY_ID" = "" ]; then
    printf "{\n    \"Version\": \"2012-10-17\",\n    \"Statement\": [\n        {\n            \"Effect\": \"Allow\",\n            \"Action\": [\n" > /tmp/iam_policy.json
    printf "                \"autoscaling:DescribeAutoScalingGroups\",\n                \"autoscaling:DescribeAutoScalingInstances\",\n" >> /tmp/iam_policy.json
    printf "                \"autoscaling:DescribeLaunchConfigurations\",\n                \"autoscaling:DescribeTags\",\n" >> /tmp/iam_policy.json
    printf "                \"autoscaling:SetDesiredCapacity\",\n                \"autoscaling:TerminateInstanceInAutoScalingGroup\",\n"  >> /tmp/iam_policy.json
    printf "                \"ec2:DescribeLaunchTemplateVersions\"\n            ],\n            \"Resource\": [\"*\"]\n        }\n    ]\n}\n" >> /tmp/iam_policy.json
    aws iam create-policy \
      --policy-name AmazonEKSClusterAutoscalerPolicy \
      --policy-document file:///tmp/iam_policy.json
  fi
  eksctl create iamserviceaccount \
    --cluster=$1 \
    --namespace=kube-system \
    --name=cluster-autoscaler \
    --attach-policy-arn=arn:aws:iam::${ACCOUNT}:policy/AmazonEKSClusterAutoscalerPolicy \
    --override-existing-serviceaccounts \
    --approve \
    --region=$REGION
fi
#------------------------------------------------------------------------------
# AWS LBC deployment
#
kubectl apply -f /tmp/cluster-autoscaler.yaml
