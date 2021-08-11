# aws-eks-plugins
This is a set of EKS plugin scripts which will allow you to install and delete EKS plugins quickly

- **aws-lbc.sh** Installes the AWS Load Balancer Controller
- **cluster-autoscaler.sh** Installes the Cluster Autoscaller
- **ebs-csi.sh** Installes EBS-CSI Driver
- **efs-csi.sh** Installes EFS-CSI Driver

- **aws-lbc-del.sh** Deletes the AWS Load Balancer Controller
- **cluster-autoscaler-del.sh** Deletes the Cluster Autoscaller
- **ebs-csi-del.sh** Deletes EBS-CSI Driver
- **efs-csi-del.sh** Deletes EFS-CSI Driver

Prerequsite: eksctl, awscli, kubectl and helm

***Usage***
For all install scripts:
<scripts-name.sh> <eks-cluster-name> [no-iam] [region]

no-iam - do not create service account and IAM role (skip these steps, you have to have service account and IAM role created in advance)
region - to use non-default region (default region is specified in awscli)

For all deletion scripts:
<scripts-name.sh> <eks-cluster-name> [region]

region - to use non-default region (default region is specified in awscli)
