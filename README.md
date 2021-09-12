# aws-eks-plugins
This is a set of EKS plugin scripts which will allow you to install and delete EKS plugins quickly

- **aws-lbc.sh** Installs the AWS Load Balancer Controller
- **cluster-autoscaler.sh** Installs the Cluster Autoscaller
- **ebs-csi.sh** Installs EBS-CSI Driver
- **efs-csi.sh** Installs EFS-CSI Driver

- **aws-lbc-del.sh** Deletes the AWS Load Balancer Controller
- **cluster-autoscaler-del.sh** Deletes the Cluster Autoscaller
- **ebs-csi-del.sh** Deletes EBS-CSI Driver
- **efs-csi-del.sh** Deletes EFS-CSI Driver

### Prerequsite: eksctl, awscli, kubectl and helm have to be installed

### Usage

For all install scripts:<br>
```
scripts-name.sh <eks-cluster-name> [no-iam] [region]
```
no-iam - do not create service account and IAM role (skip these steps, you have to have service account and IAM role created in advance)<br>
region - to use non-default region (default region is specified in awscli)

For all deletion scripts:<br>
```
scripts-name.sh <eks-cluster-name> [region]
```
region - to use non-default region (default region is specified in awscli)

Examples:
```
cluster-autoscaler.sh my-cluster us-west-2
aws-lbc.sh my-cluster us-west-2 no-iam
ebs-csi.sh my-cluster
ebs-csi-del.sh my-cluster
cluster-autoscaler-del.sh my-cluster us-west-2
```
<<<<<<< HEAD

=======
>>>>>>> 58d2613449ad3f1c5cc7b9ac4a9f050566f07067
