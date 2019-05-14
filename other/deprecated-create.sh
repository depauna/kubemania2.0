#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

curl -O curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.1/bin/linux/amd64/kubectl
chmod +x ./kubectl
echo $PATH
sudo mv ./kubectl /usr/bin/kubectl

export KUBECONFIG=admin.conf
CLUSTER=cluster.local
rm -rf ~/kubemania
mkdir ~/kubemania
for i in {11..20} {26..30}
do
  USER=user$i
#  adduser $USER
  useradd -p "*" -U -m $USER
  rm -rf /home/$USER/*
  rm -rf /home/$USER/.*
  mkdir /home/$USER/.ssh
  chmod 700 /home/$USER/.ssh
  touch /home/$USER/.ssh/authorized_keys
  chmod 600 /home/$USER/.ssh/authorized_keys
  usermod -a -G docker $USER
  ssh-keygen -t rsa -b 4096 -C $USER -f ~/kubemania/$USER -q -N ""
  cat ~/kubemania/$USER.pub > /home/$USER/.ssh/authorized_keys

## create config users
mkdir /home/$USER/.certs

kubectl create namespace $USER
openssl genrsa -out /home/$USER/.certs/$USER.key 2048
openssl req -new -key /home/$USER/.certs/$USER.key -out /home/$USER/.certs/$USER.csr -subj "/CN=$USER/O=kubemania"
openssl x509 -outform pem -in /etc/kubernetes/pki/ca.pem -out /etc/kubernetes/pki/ca.crt
openssl rsa -outform pem -in /etc/kubernetes/pki/ca-key.pem -out /etc/kubernetes/pki/ca.key
openssl x509 -req -in /home/$USER/.certs/$USER.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out /home/$USER/.certs/$USER.crt -days 500
kubectl config set-credentials $USER --client-certificate=/home/$USER/.certs/$USER.crt  --client-key=/home/$USER/.certs/$USER.key
kubectl config set-context $USER-context --cluster=$CLUSTER --namespace=$USER --user=$USER

  cat <<EOT > role-deployment-manager-$USER.yaml
  kind: Role
  apiVersion: rbac.authorization.k8s.io/v1beta1
  metadata:
    namespace: $USER
    name: deployment-manager
  rules:
  - apiGroups: ["", "extensions", "apps"]
    resources: ["*"] # ["deployments", "replicasets", "pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
EOT

kubectl apply -f role-deployment-manager-$USER.yaml

cat <<EOT > rolebinding-deployment-manager-$USER.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: deployment-manager-binding
  namespace: $USER
subjects:
- kind: User
  name: $USER
  apiGroup: ""
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: ""
EOT

kubectl create -f rolebinding-deployment-manager-$USER.yaml

cat <<EOT > /home/$USER/$USER.conf
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMrVENDQWVHZ0F3SUJBZ0lKQUlFOHNNMlFwMjRJTUEwR0NTcUdTSWIzRFFFQkN3VUFNQkl4RURBT0JnTlYKQkFNTUIydDFZbVV0WTJFd0lCY05NVGd4TURFNE1UTXpOak0yV2hnUE1qRXhPREE1TWpReE16TTJNelphTUJJeApFREFPQmdOVkJBTU1CMnQxWW1VdFkyRXdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCCkFRQ2pEQnYxa1REd1ZuWjBac3ZqdTRkUFFGc2hsamI1d0J0STVvNXF2WkFKaU96dDgxcHFJeDVRcFM4dE16YjgKM0NsS0xzNERGcTlRdVVaY3ZyMnRzTVFKRUdoWnpUb2NpbVBUM1ptbmp5SHNHSDl0RG5FRE9jMTBDdUdreEw0dgpSS1o1Y1VpRVhlcklwMFVIcm9PQzhESHF1TU9lQTVEWmJpb21vNFBHVVluQ083VzVWYXorbjd2eGp4QUhKS2MrCkNYL3lRM0RsNVFzQXk4K1hkV2NLbEk5c0lGanc0Z2ZmQUdmbUNMWWxzL1B4RnBPREQ1VHhxeHJtNXRxbGRhMksKVGNpd21WbU5vWDE5SkpSa0dnVzkzZk1aajJvYVpzUkUxMEJaOE1uaFYrNW80RjhQeURseTdPVnUyd3lWdnF1eApEUnZhQm5UOVhKYnJWeGdEYkdwdjlDTG5BZ01CQUFHalVEQk9NQjBHQTFVZERnUVdCQlJHbUtTUWN3ZjZGRm5mCkFScE5PRGhhV2xaSGp6QWZCZ05WSFNNRUdEQVdnQlJHbUtTUWN3ZjZGRm5mQVJwTk9EaGFXbFpIanpBTUJnTlYKSFJNRUJUQURBUUgvTUEwR0NTcUdTSWIzRFFFQkN3VUFBNElCQVFCVWJHVVlYbjA5bnF6VVQrL0NqL2NUNWRDTwpJNjR5MkIrT2NuYWNmejkxeU9qenRFN1RUSm9XcVJWck1BTEdLcHczaFVqRFVUaGhIOHk3UnJaL3N2THhmcExkCkxuQ2NBRlBLRnhHWnNOblRCNTRzZDdiSnpmMldiQ2hVMDErNFBySE81TnV0b3NMWlBybTdkTEplQXYyZWtjaUwKREoxb01qNGs3cXM3dzVnSTEyOUNVVzkvaXF0b0JhNytmZjU1UXhWeHVpWGJ0Zjg2UkdhVFhSaXFnUmc5TnlnNwpydm05N1NXeXF1V3BpeStkRUtES2N0cDcvVWZTWjBINllRNzJWMXpabVhLOWwvaERPdjN6NitBSThrVVhma09NCkdjL2pUWWU2VGRsblZoUHI4cWZRMHczeE5RcmNSMDYrZkRGejIveHVpS0xPTUdwa0VZUy84Z1VrTmZudwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    server: https://10.250.200.128:6443
  name: $CLUSTER
contexts:
- context:
    cluster: $CLUSTER
    namespace: $USER
    user: $USER
  name: $USER-context
current-context: $USER-context
kind: Config
preferences: {}
users:
- name: $USER
  user:
    as-user-extra: {}
    client-certificate: /home/$USER/.certs/$USER.crt
    client-key: /home/$USER/.certs/$USER.key
EOT

echo "export KUBECONFIG=/home/$USER/$USER.conf" >> /home/$USER/.bash_profile

##END config users

    chown -R $USER. /home/$USER/

done


rm -rf /home/core/./kubemania
mv ~/kubemania /home/core/.
chown -R core. /home/core/.