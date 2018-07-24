#!/bin/bash

if [[ ${#} -ne 2 ]]; then
  echo "Usage <cmd> stackid bucketid"
  exit 1
fi

STACKID=$(echo -n "${1}" | sha1sum | cut -f 1 -d ' ')
S3BUCKET="${2}"

yum install -y docker kubeadm
#sed -E -i -e "s/^OPTIONS=\"/OPTIONS=\"--iptables=false --ip-masq=false /" /etc/sysconfig/docker
#sed -E -i -e "s/^(KUBELET_EXTRA_ARGS=)/\1\"--cloud-provider=aws\"/" /etc/sysconfig/kubelet
systemctl enable kubelet.service
systemctl enable docker.service
systemctl start docker.service
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables


w=1
ret=1
while [[ ${ret} -ne 0 ]]; do
  sleep ${w}
  aws s3 cp "s3://${S3BUCKET}/kubeadmjoin-${STACKID}.cmd" "kubeadmjoin-${STACKID}.cmd"
  ret=${?}
  w=30
done
bash "./kubeadmjoin-${STACKID}.cmd"
ret=${?}
if [[ ${ret} -ne 0 ]]; then
    echo "kubeadm join failed"
    exit ${ret}
fi
