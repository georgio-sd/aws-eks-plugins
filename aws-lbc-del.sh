#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# AWS Load Balancer Controller deletion script v0.1
# -----------------------------------------------------------------------------
# Deletes current AWS Load Balancer Controller installation (if it exists)
# Developed by Sam Stewart @babaiant
# eksctl, kubectl, helm and awscli have to be preinstalled
#
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "aws-lbc-del.sh <eks-cluster-name> [region]"
  exit 1
fi
#------------------------------------------------------------------------------
# Getting region and account number
#
if [ "$2" != "" ]; then
  REGION="$2"
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
#curl -o /tmp/v2_2_0_full.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.0/docs/install/v2_2_0_full.yaml
#sed -i -z "s/---/@/g; s/[^@]*\nkind: ServiceAccount[^@]*@//g; s/@/---/g; s/your-cluster-name/$1/g" /tmp/v2_2_0_full.yaml
#kubectl delete -f /tmp/v2_2_0_full.yaml
#kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.1.1/cert-manager.yaml 2> /dev/null
helm uninstall aws-load-balancer-controller -n kube-system
#------------------------------------------------------------------------------
# Deleting service acount and IAM role
#
eksctl delete iamserviceaccount \
  --cluster=$1 \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --wait \
  --region $REGION
