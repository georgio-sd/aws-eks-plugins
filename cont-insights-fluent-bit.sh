#!/bin/bash -x
#
# -----------------------------------------------------------------------------
# Container Insights (Fluent Bit) deployment script v0.1
# -----------------------------------------------------------------------------
# Deletes current Container Insights installation (if it exists) and installs a new one
# Developed by Sam Stewart @babaiant
# eksctl, kubectl and awscli have to be preinstalled
#
# no-iam - do not create service account and IAM role
# region - to use non-default region
#
if [ "$1" = "" ]; then
  echo "Usage:"
  echo "cont-insights-fluent-bit.sh <eks-cluster-name> [no-iam] [region]"
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
ClusterName=$1
RegionName=$REGION
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl  -o /tmp/cwagent-fluent-bit-quickstart.yaml \
  https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml
sed -i -z "s/---/@/g; s/[^@]*\nkind: ServiceAccount[^@]*@//g; s/[^@]*\nkind: Namespace[^@]*@//g" /tmp/cwagent-fluent-bit-quickstart.yaml
sed -i "s/^@/---/" /tmp/cwagent-fluent-bit-quickstart.yaml
sed -i "s/{{cluster_name}}/${ClusterName}/; s/{{region_name}}/${RegionName}/; s/{{http_server_toggle}}/\"${FluentBitHttpServer}\"/" /tmp/cwagent-fluent-bit-quickstart.yaml
sed -i "s/{{http_server_port}}/\"${FluentBitHttpPort}\"/; s/{{read_from_head}}/\"${FluentBitReadFromHead}\"/; s/{{read_from_tail}}/\"${FluentBitReadFromTail}\"/" /tmp/cwagent-fluent-bit-quickstart.yaml
kubectl delete -f /tmp/cwagent-fluent-bit-quickstart.yaml
#------------------------------------------------------------------------------
# Recreating service acount and IAM role
#
if [ "$2" != "no-iam" ] && [ "$3" != "no-iam" ]; then
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
  eksctl create iamserviceaccount \
    --cluster=$1 \
    --namespace=amazon-cloudwatch \
    --name=cloudwatch-agent \
    --attach-policy-arn=arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
    --override-existing-serviceaccounts \
    --approve \
    --region=$REGION
  eksctl create iamserviceaccount \
    --cluster=$1 \
    --namespace=amazon-cloudwatch \
    --name=fluent-bit \
    --attach-policy-arn=arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
    --override-existing-serviceaccounts \
    --approve \
    --region=$REGION
fi
#------------------------------------------------------------------------------
# Container Insights deployment
#
kubectl apply -f /tmp/cwagent-fluent-bit-quickstart.yaml
