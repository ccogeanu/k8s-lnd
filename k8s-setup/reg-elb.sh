#!/bin/bash

if [[ ${#} -ne 4 ]]; then
  echo "Usage <cmd> region stack_name elb_target_group ext_security_group"
  exit 1
fi

echo "${@}"

AWS_REGION="${1}"
AWS_STACK_NAME="${2}"
ELB_TARGET_GROUP_ARN="${3}"
EXT_SECURITY_GROUP="${4}"

echo "-----DEBUG-----"
kubectl --kubeconfig=/root/.kube/config get all -o wide --all-namespaces
echo "-----DEBUG-----"

KONG_PROXY_PORT=$(kubectl --kubeconfig=/root/.kube/config get service kong-proxy --no-headers -o custom-columns="N:.spec.ports[0].nodePort")
echo "Kong local proxy port: ${KONG_PROXY_PORT}"

INSTANCES=$(aws ec2 describe-instances \
	            --region "${AWS_REGION}" \
		    --filters \
		          "Name=instance-state-name,Values=running" \
			  "Name=tag:aws:cloudformation:stack-name,Values=${AWS_STACK_NAME}" \
             | jq -r '.Reservations[].Instances[].InstanceId' \
	   )
for i in ${INSTANCES}; do
  echo "ELB target registration ${i}:${KONG_PROXY_PORT}"
  aws --region "${AWS_REGION}" \
	  elbv2 register-targets \
	         --target-group-arn "${ELB_TARGET_GROUP_ARN}" \
	         --targets "Id=${i},Port=${KONG_PROXY_PORT}"
done

aws --region "${AWS_REGION}" ec2 authorize-security-group-ingress --group-name "${EXT_SECURITY_GROUP}" --protocol tcp --port "${KONG_PROXY_PORT}"  --cidr 0.0.0.0/0
