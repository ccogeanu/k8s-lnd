#!/bin/bash

if [[ ${#} -ne 1 ]]; then
  echo "Usage <cmd> elb_public_dns"
  exit 1
fi

echo "${@}"

ELB_PUBLIC_DNS="${1}"

PUBLIC_DNS=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

PRIVATE_DNS=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo ${PUBLIC_DNS} ${PUBLIC_IP} ${PRIVATE_DNS} ${PRIVATE_IP}

mkdir -p /root/getkong
pushd /root/getkong
git clone https://github.com/Kong/kong-dist-kubernetes.git
pushd kong-dist-kubernetes

kubectl --kubeconfig=/root/.kube/config create -f postgres.yaml
ret=0
while [[ ${ret} -eq 0 ]]; do
  sleep 5
  kubectl --kubeconfig=/root/.kube/config get pods | egrep postgres | sed -E -e "s/\s+/:/g" | cut -d ':' -f 3 | egrep -v "^Running$"
  ret=${?}
done

kubectl --kubeconfig=/root/.kube/config create -f kong_migration_postgres.yaml
ret=0
while [[ ${ret} -eq 0 ]]; do
  sleep 5
  kubectl --kubeconfig=/root/.kube/config get job kong-migration -o wide --no-headers | sed -E -e "s/\s+/:/g" | cut -d ':' -f 3 | egrep -v "^1$"
  ret=${?}
done
kubectl --kubeconfig=/root/.kube/config delete -f kong_migration_postgres.yaml

kubectl --kubeconfig=/root/.kube/config create -f kong_postgres.yaml
ret=0
while [[ ${ret} -eq 0 ]]; do
  sleep 5
  kubectl --kubeconfig=/root/.kube/config get pods | egrep postgres | sed -E -e "s/\s+/:/g" | cut -d ':' -f 3 | egrep -v "^Running$"
  ret=${?}
done

popd
popd

eval $(kubectl --kubeconfig=/root/.kube/config get service/kong-admin --no-headers | sed -E -e "s/(\s|\/)+/:/g" -e "s/[^:]+:[^:]+:([^:]+):[^:]+:([^:]+):.*/export KONG_ADMIN_IP=\"\1\" KONG_ADMIN_PORT=\"\2\"/")
if [[ "${KONG_ADMIN_IP}x" == "x" || "${KONG_ADMIN_PORT}" == "x" ]]; then
  echo "Cannot obtain the service/kong-admin HOST:IP pair"
  exit 1
fi
echo "kong admin: " ${KONG_ADMIN_IP} ${KONG_ADMIN_PORT}

eval $(kubectl --kubeconfig=/root/.kube/config get service/kong-proxy --no-headers | sed -E -e "s/(\s|\/)+/:/g" -e "s/[^:]+:[^:]+:([^:]+):[^:]+:([^:]+):.*/export KONG_PROXY_IP=\"\1\" KONG_PROXY_PORT=\"\2\"/")
if [[ "${KONG_PROXY_IP}x" == "x" || "${KONG_PROXY_PORT}" == "x" ]]; then
  echo "Cannot obtain the service/kong-proxy HOST:IP pair"
  exit 1
fi
echo "kong proxy: " ${KONG_PROXY_IP} ${KONG_PROXY_PORT}

eval $(kubectl --kubeconfig=/root/.kube/config get service/kong-proxy-ssl --no-headers | sed -E -e "s/(\s|\/)+/:/g" -e "s/[^:]+:[^:]+:([^:]+):[^:]+:([^:]+):.*/export KONG_PROXY_SSL_IP=\"\1\" KONG_PROXY_SSL_PORT=\"\2\"/")
if [[ "${KONG_PROXY_SSL_IP}x" == "x" || "${KONG_PROXY_SSL_PORT}" == "x" ]]; then
  echo "Cannot obtain the service/kong-proxy-ssl HOST:IP pair"
  exit 1
fi
echo "kong proxy ssl: " ${KONG_PROXY_SSL_IP} ${KONG_PROXY_SSL_PORT}

eval $(kubectl --kubeconfig=/root/.kube/config get service/lnd-msvc --no-headers | sed -E -e "s/(\s|\/)+/:/g" -e "s/[^:]+:[^:]+:([^:]+):[^:]+:([^:]+):.*/export SVC_IP=\"\1\" SVC_PORT=\"\2\"/")
if [[ "${SVC_IP}x" == "x" || "${SVC_PORT}" == "x" ]]; then
  echo "Cannot obtain the microservice's HOST:IP pair"
  exit 1
fi
echo "microservice: " ${SVC_IP} ${SVC_PORT}


curl -s -X POST "http://${KONG_ADMIN_IP}:${KONG_ADMIN_PORT}/services" -d 'name=lnd-msvc' -d"url=http://${SVC_IP}:${SVC_PORT}" > /tmp/svcid.json
KONG_SVC_ID=$(jq '.id' /tmp/svcid.json)
if [[ "${KONG_SVC_ID}" == "null" ]]; then
  echo "Error creating the kong service"
  cat /tmp/svcid.json | jq '.'
  exit 1
fi
echo "Service ID: ${KONG_SVC_ID}"


curl -s -X POST -H "Content-Type: application/json" "http://${KONG_ADMIN_IP}:${KONG_ADMIN_PORT}/routes" -d"{\"hosts\": [\"${PRIVATE_DNS}\", \"${ELB_PUBLIC_DNS}\"], \"paths\": [\"/count\", \"/uppercase\"], \"strip_path\":false, \"service\": {\"id\":${KONG_SVC_ID}}}" > /tmp/routeid.json
KONG_ROUTE_ID=$(jq '.id' /tmp/routeid.json)
if [[ "${KONG_ROUTE_ID}" == "null" ]]; then
  echo "Error creating the kong route"
  cat /tmp/routeid.json | jq '.'
  exit 1
fi
echo "Route ID: ${KONG_ROUTE_ID}"

curl -s -XPOST -d'{"s":"some lower case string"}' -H "Host: ${ELB_PUBLIC_DNS}" "http://${KONG_PROXY_IP}:${KONG_PROXY_PORT}/uppercase"
#curl -s -XPOST -d'{"s":"some lower case string"}' -H "Host: ${PUBLIC_DNS}" "http://${KONG_PROXY_IP}:${KONG_PROXY_PORT}/count"
