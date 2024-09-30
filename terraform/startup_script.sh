#!/bin/bash

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command was successful
check_success() {
    if [ $? -eq 0 ]; then
        log "SUCCESS: $1"
    else
        log "ERROR: $1 failed"
        exit 1
    fi
}

# Update and upgrade the system
log "Updating and upgrading the system..."
sudo apt-get update && sudo apt-get upgrade -y
check_success "System update and upgrade"

# Install containerd
log "Installing containerd..."
sudo apt-get install -y containerd
check_success "Containerd installation"

# Configure kernel modules
log "Configuring kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
check_success "Kernel module configuration"

# Configure sysctl settings
log "Configuring sysctl settings..."
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
check_success "Sysctl configuration"

# Configure containerd
log "Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo systemctl restart containerd
check_success "Containerd configuration"

# Additional Kubernetes settings
log "Configuring additional Kubernetes settings..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
check_success "Additional Kubernetes settings"

# Install Kubernetes components
log "Installing Kubernetes components..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
check_success "Kubernetes components installation"

# Enable and start kubelet
log "Enabling and starting kubelet..."
sudo systemctl enable --now kubelet
check_success "Kubelet activation"

# Final sysctl configurations
log "Applying final sysctl configurations..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
check_success "Final sysctl configurations"

log "Script execution completed successfully"