#!/bin/bash
set -euxo pipefail

docker_username=$1
img_name=$2
img_tag=${3:latest}
namespace=$4

helm upgrade --tls --tls-ca-cert ~/.helm/ca.pem --tls-cert ~/.helm/cert.pem --tls-key ~/.helm/key.pem --wait --install -f --namespace $namespace --set img.tag=$img_tag employee-amangement depauna/spring-backend

