#!/bin/bash

AWS_REGION="${1}"
AWS_STACK_NAME="${2}"
ELB_TARGET_GROUP_ARN="${3}"
ELB_TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-west-2:166720137260:targetgroup/elbs-Target-1QGO5WMD45SV6/2a9b058964c59b98"

KONG_PROXY_PORT=$(kubectl get service kong-proxy --no-headers -o custom-columns="N:.spec.ports[0].nodePort")

INSTANCES=$(aws ec2 describe-instances \
	            --region "${AWS_REGION}" \
		    --filters \
		          "Name=instance-state-name,Values=running" \
			  "Name=tag:aws:cloudformation:stack-name,Values=${AWS_STACK_NAME}" \
             | jq -r '.Reservations[].Instances[].InstanceId' \
	   )
for i in ${INSTANCES}; do
  echo ${i}
  aws --region "${AWS_REGION}" \
	  elbv2 register-targets \
	         --target-group-arn "${ELB_TARGET_GROUP_ARN}" \
	         --targets "Id=${i},Port=${KONG_PROXY_PORT}"
done

