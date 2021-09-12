#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# Container Insights (Fluent Bit) deletion script v0.1
# -----------------------------------------------------------------------------
# Deletes current Container Insights (Fluent Bit) installation (if it exists)
# Developed by Sam Stewart @babaiant
# eksctl, kubectl and awscli have to be preinstalled
#
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "cont-insights-fluent-bit-del.sh <eks-cluster-name> [region]"
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
# Setting up kubectl credentials and getting cluster version
#
set -e
aws eks --region $REGION update-kubeconfig --name $1
set +e
#------------------------------------------------------------------------------
# Deleting previous installation
#
ClusterName=$1
RegionName=$REGION
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl  -o /tmp/cwagent-fluent-bit-quickstart.yaml \
  https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml
sed -i "s/{{cluster_name}}/${ClusterName}/; s/{{region_name}}/${RegionName}/; s/{{http_server_toggle}}/\"${FluentBitHttpServer}\"/" /tmp/cwagent-fluent-bit-quickstart.yaml
sed -i "s/{{http_server_port}}/\"${FluentBitHttpPort}\"/; s/{{read_from_head}}/\"${FluentBitReadFromHead}\"/; s/{{read_from_tail}}/\"${FluentBitReadFromTail}\"/" /tmp/cwagent-fluent-bit-quickstart.yaml
kubectl delete -f /tmp/cwagent-fluent-bit-quickstart.yaml
#------------------------------------------------------------------------------
# Deleting service acount and IAM role
#
eksctl delete iamserviceaccount \
  --cluster=$1 \
  --namespace=amazon-cloudwatch \
  --name=cloudwatch-agent \
  --wait \
  --region=$REGION
eksctl delete iamserviceaccount \
  --cluster=$1 \
  --namespace=amazon-cloudwatch \
  --name=fluent-bit \
  --wait \
  --region=$REGION
