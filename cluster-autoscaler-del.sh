#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# Cluster Autoscaler deletion script v0.1
# -----------------------------------------------------------------------------
# Deletes current Cluster Autoscaler installation (if it exists)
# Developed by Sam Stewart @babaiant
# eksctl, kubectl and awscli have to be preinstalled
#
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "cluster-autoscaler-del.sh <eks-cluster-name> [region]"
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
# Setting up kubectl credentials and getting cluster version
#
set -e
aws eks --region $REGION update-kubeconfig --name $1
set +e
#------------------------------------------------------------------------------
# Deleting previous installation
#
curl -o /tmp/cluster-autoscaler.yaml \
  https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

sed -i -z "s/---/@/g; s/[^@]*\nkind: ServiceAccount[^@]*@//g; s/@/---/g" /tmp/cluster-autoscaler.yaml
kubectl delete -f /tmp/cluster-autoscaler.yaml
#------------------------------------------------------------------------------
# Deleting service acount and IAM role
#
eksctl delete iamserviceaccount \
  --cluster=$1 \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --wait \
  --region=$REGION
