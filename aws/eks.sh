#!/bin/bash

# Step 1: Install Terraform
terraform_version=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M '.current_version')
curl -O "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip"
unzip terraform_${terraform_version}_linux_amd64.zip
mkdir -p ~/bin
mv terraform ~/bin/
terraform version

# Step 2: Prepare environment for EKS
sudo mkdir -p /opt/eks
sudo chown cloudshell-user /opt/eks
cd /opt/eks

# Step 3: Clone the course repository
git clone https://github.com/kodekloudhub/amazon-elastic-kubernetes-service-course
cd amazon-elastic-kubernetes-service-course/eks

# Step 4: Source the environment check script
source check-environment.sh

# Step 5: Initialize and apply Terraform
terraform init
terraform plan
terraform apply -auto-approve

# Step 6: Output Terraform results and capture the NodeInstanceRole
node_instance_role=$(terraform output -raw NodeInstanceRole)
echo "NodeInstanceRole: $node_instance_role"

# Step 7: Attach ElasticLoadBalancingFullAccess policy to eksWorkerNodeRole
aws iam attach-role-policy --role-name eksWorkerNodeRole --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
echo "ElasticLoadBalancingFullAccess policy attached to eksWorkerNodeRole"

# Step 8: Create a KUBECONFIG for kubectl
aws eks update-kubeconfig --region us-east-1 --name demo-eks

# Step 9: Download the aws-auth-cm.yaml template
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/aws-auth-cm.yaml

# Step 10: Replace the placeholder in aws-auth-cm.yaml with the NodeInstanceRole
echo "Updating aws-auth-cm.yaml with the NodeInstanceRole..."
sed -i "s|<ARN of instance role (not instance profile)>|$node_instance_role|" aws-auth-cm.yaml

# Step 11: Apply the updated aws-auth ConfigMap
kubectl apply -f aws-auth-cm.yaml

sleep 60
# Step 12: Verify node status
kubectl get node -o wide
echo "EKS Cluster is Ready"
    
# Step 13: Istio installing steps
echo "Installing Istio"
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.25.1/
export PATH=$PWD/bin:$PATH
istioctl install --set profile=default -y
kubectl label namespace default istio-injection=enabled

# Step 14: HELM installing steps
cd ../
echo "Installing Helm"
sudo yum update -y 
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Step 15: AWS ALB Controller installing steps
echo "Installing AWS ALB Controller"
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system   --set clusterName=demo-eks --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller

echo "Now you can apply yaml files !!!"
