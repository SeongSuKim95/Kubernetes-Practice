#!/bin/bash
# EC2 first-boot: single-node kubeadm + Calico + ingress-nginx (baremetal/NodePort).
# Logs: /var/log/bootstrap-k8s.log
set -euo pipefail
exec > >(tee -a /var/log/bootstrap-k8s.log) 2>&1

export DEBIAN_FRONTEND=noninteractive
K8S_VERSION="${K8S_VERSION:-1.29}"
CALICO_VERSION="${CALICO_VERSION:-v3.28.0}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-v1.11.2}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"

echo "=== [bootstrap-k8s] start $(date -Is) ==="

# --- IMDSv2 metadata (public IP may be empty without EIP) ---
# Set at provision time (Elastic IP) so apiserver cert includes stable public IP before association.
BOOTSTRAP_EIP='__BOOTSTRAP_EIP_PLACEHOLDER__'

TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -fsS -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/local-ipv4")
PUBLIC_IP=$(curl -fsS -H "X-aws-ec2-metadata-token: ${TOKEN}" "http://169.254.169.254/latest/meta-data/public-ipv4" || true)
EXTRA_SANS="127.0.0.1,${PRIVATE_IP}"
if [[ -n "${BOOTSTRAP_EIP}" ]]; then
  EXTRA_SANS="${EXTRA_SANS},${BOOTSTRAP_EIP}"
elif [[ -n "${PUBLIC_IP}" ]]; then
  EXTRA_SANS="${EXTRA_SANS},${PUBLIC_IP}"
fi

# --- Kernel / swap (kubeadm) ---
swapoff -a || true
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab || true
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay || true
modprobe br_netfilter || true
cat <<EOF >/etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# --- containerd ---
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" >/etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y containerd.io

mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' >/etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# --- kubeadm / kubelet / kubectl ---
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" >/etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- kubeadm init (single control-plane node) ---
kubeadm init \
  --pod-network-cidr="${POD_CIDR}" \
  --apiserver-advertise-address="${PRIVATE_IP}" \
  --apiserver-cert-extra-sans="${EXTRA_SANS}" \
  --node-name "$(hostname -s)"

export KUBECONFIG=/etc/kubernetes/admin.conf

# --- Calico ---
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

# --- Allow workloads on control plane (single-node lab) ---
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true

# --- Wait for node Ready ---
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# --- ingress-nginx (baremetal = NodePort 80/443 on controller Service) ---
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_NGINX_VERSION}/deploy/static/provider/baremetal/deploy.yaml"

# --- kubeconfig for ubuntu (SSH users) ---
if id ubuntu &>/dev/null; then
  mkdir -p /home/ubuntu/.kube
  cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
  chown -R ubuntu:ubuntu /home/ubuntu/.kube
fi

echo "=== [bootstrap-k8s] done $(date -Is) ==="
echo "Public IP (if any): ${PUBLIC_IP:-<none yet — attach EIP or use IMDS after EIP>}"
echo "Use: ssh ubuntu@${PUBLIC_IP:-$PRIVATE_IP}  kubectl get nodes"
