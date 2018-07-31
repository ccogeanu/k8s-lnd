# k8s-lnd

This repository provides the scripts and the instructions for deploying a small kubernetes cluster composed of a master and a node on the AWS cloud and deploying a small microservice proxied by Kong.

The scripts and the guide in this repository were developed on the AWS region us-west-2. They can be customized for a different or a configurable region, but at this time that's the only supported region.

## Create the microservice docker image

The required commands for creating the microservice docker image which will later be deploayed in the cluster:
  - create a AWS container registry repository named "k8s-lnd-msvc"
  - run the following:
```
git clone https://github.com/ccogeanu/k8s-lnd.git
cd microservice
$(aws ecr get-login --no-include-email --region us-west-2)
docker build --build-arg SOURCE_LOCATION=./ --no-cache -t k8s-lnd-msvc .
docker tag k8s-lnd-msvc:latest <your_reg_id>.dkr.ecr.us-west-2.amazonaws.com/k8s-lnd-msvc:latest
docker push <your_reg_id>.dkr.ecr.us-west-2.amazonaws.com/k8s-lnd-msvc:latest
```

If nothing fails, a Docker image should be pushed now in your AWS account's container registry.

## Deploy the cluster

The cluster is deployed automatically by a AWS CloudFormation stack created from the [cloudformation-lnd.template](https://github.com/ccogeanu/k8s-lnd/blob/master/k8s-setup/cloudformation-lnd.template) template.

The template expects a value for the parameter **s3clustersetup**, which is the name of a S3 bucket where the master node will create a file with information for the node(s) to use for joining the cluster. Although the nodes could get the node setup scripts directly from this github repository, currently the template will get these scripts from the same S3 bucket. Therefore, before creating the CloudFormation stack, do the following:
  - create a S3 bucket
  - copy the k8s-setup directory from this repository to the bucket
  - then create the stack by providing a name and the name of the newly created S3 bucket as the value for the **s3clustersetup** template argument
```
VPCID=$(aws ec2 describe-vpcs --filter "Name=isDefault,Values=true" | jq -r '.Vpcs[0].VpcId')
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPCID}" | jq -r '.Subnets[].SubnetId' | tr '\n' ',' | sed -E -e 's/,$//')
aws cloudformation create-stack --stack-name <<MY_STACK_NAME>> --template-body file://k8s-setup/cloudformation-lnd.template --parameters "ParameterKey=s3clustersetup,ParameterValue=<<S3_BUCKET_ID>>" "ParameterKey=subnets,ParameterValue=\"${SUBNETS}\"" "ParameterKey=vpcid,ParameterValue=${VPCID}" --capabilities CAPABILITY_IAM
```

The following actions are performed during the deployment of the cluster:
  - the CloudFormation template will create 2 EC2 instances, a node IAM role, 2 security groups and a network Elastic Load Balancer.
  - for each EC2 instance, the necessary packages (k8s, docker, ebtables, etc.) are installed on top of a Amazon Linux 2 AMI
  - the cluster is configured by kubeadm
  - the cluster CNI's is configured with Calico
  - a small microservice image is being deployed and it's port exposed as a service in the cluster; the image is hosted in the AWS's account container registry, pushed there earlier as described in the above section
  - Kong is deployed
  - Kong is configured as a proxy to the deployed microservice with the ELB's DNS and the master's private DNS as the proxied hosts
  - a few requests will be send to the Kong proxy to verify the service is accessible
  - the ELB will be configured from the master node to target the 2 EC2 instances on the Kong proxy's dynamically assigned port
  - one of the security groups, holding the rules for external access, will be configured from the master node to accept connections on the Kong proxy's port from the Internet.

## Test the deployment

curl "http://$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[0].DNSName')/count" -d '{"s":"some lower case string"}'
