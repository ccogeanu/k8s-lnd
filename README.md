# k8s-lnd

The scripts and the guide in this repository were developed on the AWS region us-west-2. They can be customized for a different or a configurable region, but at this time that's the only supported region.

## Create the microservice docker image

The required commands for creating the microservice docker image which will later be deploayed in the cluster:
  - create a AWS container registry repository named "k8s-lnd-msvc"
  - clone this repository
  - cwd to the microservice directory
  - run the following
docker build --build-arg SOURCE_LOCATION=./ --no-cache -t k8s-lnd-msvc .
docker tag k8s-lnd-msvc:latest <your_reg_id>.dkr.ecr.us-west-2.amazonaws.com/k8s-lnd-msvc:latest
docker push <your_reg_id>.dkr.ecr.us-west-2.amazonaws.com/k8s-lnd-msvc:latest

If nothing fails, a Docker image should be pushed now in your AWS account's container registry.

## Deploy the cluster

The cluster is deployed automatically by a AWS CloudFormation stack created from this template.

The template expects one parameter <>, which is the name of a S3 bucket where the master node will create a file with information for the node(s) to use for joining the cluster. Although the nodes could get the node setup scripts directly from this github repository, currently the template will get these scripts from the same S3 bucket. Therefore, before creating the CloudFormation stack, you need to create a S3 bucket, copy the k8s-setup directory from this repository to the bucket. Then create the stack by providing a name and the name of the newly created S3 bucket as the value for the <> argument.

The following actions are performed during the deployment of the cluster:
  - the necessary packages (k8s, docker, ebtables, etc.) are installed on top of a Amazon Linux 2 AMI
  - the cluster is configured by kubeadm
  - the cluster CNI's is configured with Calico
  - a small microservice image is being deployed and it port exposed as a service in the cluster; the image is hosted in the AWS's account container registry, pushed there earlier as described in the above section
  - Kong is deployed
  - Kong is configured as a proxy to the deployed microservice
  - a few requests will be send to the Kong proxy to verify the service is accessible
