#!/bin/bash
# =============================================================================
# MinIO POC - EC2 Setup Script
# Instance: t3.large (2 vCPU, 8GB RAM, 30GB disk)
# OS: Amazon Linux 2023 or Ubuntu 22.04
# =============================================================================

set -e

echo "=============================================="
echo "MinIO POC - EC2 Setup"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}[+] $1${NC}"
}

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

print_step "Detected OS: $OS"

# =============================================================================
# 1. Install Docker
# =============================================================================
print_step "Installing Docker..."

if [ "$OS" = "amzn" ]; then
    # Amazon Linux
    sudo yum update -y
    sudo yum install -y docker git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
elif [ "$OS" = "ubuntu" ]; then
    # Ubuntu (docker-compose is installed separately as standalone binary)
    sudo apt-get update
    sudo apt-get install -y docker.io git
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
else
    echo "Unsupported OS. Please install Docker manually."
    exit 1
fi

# =============================================================================
# 2. Install Docker Compose
# =============================================================================
print_step "Installing Docker Compose..."

DOCKER_COMPOSE_VERSION="v2.24.0"
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# =============================================================================
# 3. Install MinIO Client (mc)
# =============================================================================
print_step "Installing MinIO Client (mc)..."

curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# =============================================================================
# 4. Install Python and ML dependencies
# =============================================================================
print_step "Installing Python and ML dependencies..."

if [ "$OS" = "amzn" ]; then
    sudo yum install -y python3 python3-pip
elif [ "$OS" = "ubuntu" ]; then
    sudo apt-get install -y python3 python3-pip python3-venv
fi

# Create virtual environment for ML demo
python3 -m venv ~/ml-venv
source ~/ml-venv/bin/activate
pip install --upgrade pip
pip install minio pandas numpy scikit-learn

# =============================================================================
# 5. Clone Repository
# =============================================================================
print_step "Cloning MinIO POC repository..."

cd ~
if [ -d "minio-poc" ]; then
    cd minio-poc
    git pull
else
    git clone https://github.com/rodrigodlima/minio-poc.git
    cd minio-poc
fi

# =============================================================================
# 6. Start Services
# =============================================================================
print_step "Starting services (this may take a few minutes on first run)..."

# Need to use newgrp or re-login for docker group to take effect
# Using sudo for now
sudo docker-compose up -d --build

print_step "Waiting for services to be ready..."
sleep 30

# =============================================================================
# 7. Setup Erasure Coding Demo
# =============================================================================
print_step "Setting up Erasure Coding demo..."

cd ~/minio-poc/examples/erasure-coding
rm -rf ./data 2>/dev/null || true
mkdir -p ./data/disk{1,2,3,4}
sudo docker-compose -f docker-compose.erasure.yml up -d

sleep 10

mc alias set erasure-demo http://localhost:9010 myminio minio123
mc mb erasure-demo/test-bucket --ignore-existing
echo "CONFIDENTIAL: Financial Report Q1 2025" > /tmp/report.txt
mc cp /tmp/report.txt erasure-demo/test-bucket/

# =============================================================================
# 8. Verify Installation
# =============================================================================
print_step "Verifying installation..."

echo ""
echo "Docker version:"
docker --version

echo ""
echo "Docker Compose version:"
docker-compose --version

echo ""
echo "MinIO Client version:"
mc --version

echo ""
echo "Running containers:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=============================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=============================================="
echo ""
echo "Services running:"
echo "  - MinIO Console (main):    http://<EC2-IP>:9001"
echo "  - MinIO API (main):        http://<EC2-IP>:9000"
echo "  - MinIO Console (erasure): http://<EC2-IP>:9011"
echo "  - MinIO API (erasure):     http://<EC2-IP>:9010"
echo "  - OpenSearch Dashboards:   http://<EC2-IP>:5601"
echo "  - Go API:                  http://<EC2-IP>:8080"
echo ""
echo "Credentials:"
echo "  - MinIO: myminio / minio123"
echo ""
echo "To run the demo:"
echo "  cd ~/minio-poc"
echo "  cat DEMO_SCRIPT_COMPACT.md"
echo ""
echo "To activate Python ML environment:"
echo "  source ~/ml-venv/bin/activate"
echo ""
echo -e "${YELLOW}NOTE: You may need to logout and login again for docker group to take effect${NC}"
echo -e "${YELLOW}Or run: newgrp docker${NC}"
