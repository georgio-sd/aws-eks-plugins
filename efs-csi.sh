#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# AWS EFS-CSI Driver deployment script v0.1
# -----------------------------------------------------------------------------
# Deletes current EFS-CSI Driver installation (if it exists) and installs a new one
# Developed by Sam Stewart @babaiant
# eksctl, kubectl, helm and awscli have to be preinstalled
#
# no-iam - do not create service account and IAM role
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "efs-csi.sh <eks-cluster-name> [no-iam] [region]"
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
helm uninstall aws-efs-csi-driver -n kube-system
#------------------------------------------------------------------------------
# Recreating service acount and IAM role
#
if [ "$2" != "no-iam" ] && [ "$3" != "no-iam" ]; then
  eksctl delete iamserviceaccount \
    --cluster=$1 \
    --namespace=kube-system \
    --name=efs-csi-controller-sa \
    --wait \
    --region=$REGION
  POLICY_ID=$(aws iam get-policy --policy-arn arn:aws:iam::${ACCOUNT}:policy/AmazonEKS_EFS_CSI_Driver_Policy --query 'Policy.PolicyId' --output text 2>/dev/null)
  if [ "$POLICY_ID" = "" ]; then
    curl -o /tmp/iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json
    aws iam create-policy \
      --policy-name AmazonEKS_EFS_CSI_Driver_Policy \
      --policy-document file:///tmp/iam_policy.json
  fi
  eksctl create iamserviceaccount \
    --cluster=$1 \
    --namespace=kube-system \
    --name=efs-csi-controller-sa \
    --attach-policy-arn=arn:aws:iam::${ACCOUNT}:policy/AmazonEKS_EFS_CSI_Driver_Policy \
    --override-existing-serviceaccounts \
    --approve \
    --region=$REGION
fi
#------------------------------------------------------------------------------
# AWS LBC deployment
#
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update
helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --set image.repository=602401143452.dkr.ecr.${REGION}.amazonaws.com/eks/aws-efs-csi-driver \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa \
  --set replicaCount=1 \
  --namespace kube-system
