#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# AWS EFS-CSI Driver deletion script v0.1
# -----------------------------------------------------------------------------
# Deletes current EFS-CSI Driver installation (if it exists)
# Developed by Sam Stewart @babaiant
# eksctl, kubectl, helm and awscli have to be preinstalled
#
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "efs-csi-del.sh <eks-cluster-name> [region]"
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
#------------------------------------------------------------------------------
# Setting up kubectl credentials
#
set -e
aws eks --region $REGION update-kubeconfig --name $1
set +e
#------------------------------------------------------------------------------
# Deleting previous installation
#
helm uninstall aws-efs-csi-driver -n kube-system
#------------------------------------------------------------------------------
# Deleting service acount and IAM role
#
eksctl delete iamserviceaccount \
  --cluster=$1 \
  --namespace=kube-system \
  --name=efs-csi-controller-sa \
  --wait \
  --region=$REGION
