#!/bin/bash

STACK_ID_TOKEN=$(echo -n "${STACK_ID}" | sha1sum | cut -f 1 -d ' ')

echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

kubeadm config images pull
kubeadm init --pod-network-cidr=192.168.0.0/16 | tee kubeadminit.log | egrep "kubeadm join" > "kubeadmjoin-${STACK_ID_TOKEN}.cmd"
ret=${?}
if [[ "${ret}" -ne 0 ]]; then
  echo "kubeadm init failed"
  exit ${ret}
fi

mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
mkdir -p /home/ec2-user/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config

aws s3 cp "kubeadmjoin-${STACK_ID_TOKEN}.cmd" "s3://${SETUP_BUCKET}"

kubectl --kubeconfig=/root/.kube/config cluster-info

#kubectl --kubeconfig=/root/.kube/config apply -f aws-k8s-cni-mod.yaml
kubectl --kubeconfig=/root/.kube/config apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
kubectl --kubeconfig=/root/.kube/config apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml

ret=0
while [[ ${ret} -eq 0 ]]; do
  sleep 5
  kubectl --kubeconfig=/root/.kube/config get nodes --no-headers | sed -E -e "s/\s+/:/g" | cut -f 2 -d ':' | egrep -v "^Ready$"
  ret=${?}
done

eval $(aws ecr get-login --no-include-email --region=us-west-2 | sed -E -e "s/docker login -u (\S+) -p (\S+) https:\/\/(\S+)/export DOCKER_USER='\1' DOCKER_PASSWORD='\2' DOCKER_SERVER='\3'/")
kubectl --kubeconfig=/root/.kube/config create secret docker-registry ecr --docker-server="${DOCKER_SERVER}" --docker-username="${DOCKER_USER}" --docker-password="${DOCKER_PASSWORD}"
kubectl --kubeconfig=/root/.kube/config get serviceaccounts default -o yaml > /tmp/sa.yaml
echo -e "imagePullSecrets:\n- name: ecr\n" >> /tmp/sa.yaml
kubectl --kubeconfig=/root/.kube/config replace serviceaccount default -f /tmp/sa.yaml

eval $(aws ecr get-login --no-include-email --region=us-west-2 --registry-ids 602401143452 | sed -E -e "s/docker login -u (\S+) -p (\S+) https:\/\/(\S+)/export DOCKER_USER='\1' DOCKER_PASSWORD='\2' DOCKER_SERVER='\3'/")
kubectl --kubeconfig=/root/.kube/config --namespace=kube-system create secret docker-registry ecr-aws-vpc-cni --docker-server="${DOCKER_SERVER}" --docker-username="${DOCKER_USER}" --docker-password="${DOCKER_PASSWORD}"
unset DOCKER_SERVER
unset DOCKER_USER
unset DOCKER_PASSWORD

kubectl --kubeconfig=/root/.kube/config create -f lnd-msvc.yaml
kubectl --kubeconfig=/root/.kube/config expose deployment.apps/lnd-msvc


