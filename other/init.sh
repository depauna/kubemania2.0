#!/bin/bash

set -exuo pipefail

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# install kubectl
curl -O curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/kubectl
chmod +x ./kubectl
echo $PATH
sudo mv ./kubectl /usr/bin/kubectl

wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq-linux64
echo $PATH
sudo mv ./jq-linux64 /usr/bin/jq

# export the config
export KUBECONFIG=/root/config
rm -rf ~/kubemania
mkdir ~/kubemania

for i in {1..15}{15..30}
do
  USER=user${i}

  # remove all previous data
  userdel "$USER"
  rm -rf /home/"${USER}"/
  kubectl delete ns "$USER"

  # create users and keys for the users
  useradd -p "CQjhwTqLvJhdUHJT3kPp" -U -m "$USER"
  rm -rf /home/"$USER"/*
  mkdir /home/"$USER"/.ssh
  chmod 700 /home/"$USER"/.ssh
  touch /home/"$USER"/.ssh/authorized_keys
  chmod 600 /home/"$USER"/.ssh/authorized_keys
  usermod -a -G docker "$USER"
  ssh-keygen -t rsa -b 4096 -C "$USER" -f ~/kubemania/"$USER" -q -N ""
  cat ~/kubemania/"$USER".pub > /home/"$USER"/.ssh/authorized_keys

  # create kubernetes config for the users
  mkdir /home/"$USER"/.certs
  kubectl create namespace "$USER"

cat <<EOF > ~/kubemania/"${USER}"-sa.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "$USER"
  namespace: "$USER"
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: "$USER"
  name: "$USER"
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: "$USER"
  namespace: "$USER"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: "$USER"
subjects:
- kind: ServiceAccount
  name: "$USER"
  namespace: "$USER"

EOF

  kubectl create -f ~/kubemania/"${USER}"-sa.yaml
  certificate=$(kubectl get secret $(kubectl get sa "$USER" -n "$USER" -o jsonpath="{.secrets[].name}") -n "$USER" -o json | jq -r '.data["ca.crt"]')
  token=$(kubectl get secret $(kubectl get sa "$USER" -n "$USER" -o jsonpath="{.secrets[].name}") -n "$USER" -o json | jq -r '.data["token"]' | base64 -d)
  mkdir -p /home/"${USER}"/.kube

cat <<EOF > /home/"${USER}"/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: "$certificate"
    server: https://kubernetes-elb-depauna-127443764.eu-west-1.elb.amazonaws.com:6443
  name: "$USER"
contexts:
- context:
    cluster: "$USER"
    namespace: "$USER"
    user: "$USER"
  name: "$USER"
current-context: "$USER"
kind: Config
preferences: {}
users:
- name: "$USER"
  user:
    token: "$token"
EOF

   chown -R "${USER}":"${USER}" /home/"${USER}"/

done