#!/bin/bash

set -euxo pipefail

docker_username=$1
docker_password=$2
img_name=$3
img_tag=${4:-latest}

if [[ $# -lt 2 ]]; then
   echo "[SYNTAX ERROR] example: ./build_image.sh depauna spring:hello latest"
   echo "[SYNTAX] ./build_image.sh docker-username docker-password image-name [img-tag]"
   exit 1
fi

docker build . -t "${docker_username}"/"${img_name}":"${img_tag}"

docker login -u $docker_username -p $docker_password
docker push "${docker_username}"/"${img_name}":"${img_tag}"
docker logout
