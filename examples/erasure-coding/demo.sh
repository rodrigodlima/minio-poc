#!/bin/bash

# =============================================================================
# MinIO Erasure Coding & WORM Demo Script
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Check if mc (MinIO Client) is installed
check_mc() {
    if ! command -v mc &> /dev/null; then
        print_step "Installing MinIO Client (mc)..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install minio/stable/mc
        else
            curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
            chmod +x mc
            sudo mv mc /usr/local/bin/
        fi
    fi
}

# Start the demo environment
start() {
    print_step "Starting MinIO with 4 disks (Erasure Coding mode)..."

    # Clean previous data
    rm -rf ./data
    mkdir -p ./data/disk{1,2,3,4}

    docker compose -f docker-compose.erasure.yml up -d

    echo "Waiting for MinIO to be ready..."
    sleep 5

    # Configure mc alias
    mc alias set erasure-demo http://localhost:9010 myminio minio123 --api S3v4 2>/dev/null || true

    print_step "MinIO is running!"
    echo "Console: http://localhost:9011"
    echo "API:     http://localhost:9010"
    echo ""
    echo "Login: myminio / minio123"
}

# Upload test files
upload() {
    print_step "Creating test bucket and uploading files..."

    mc mb erasure-demo/test-bucket --ignore-existing

    # Create test files
    echo "This is test file 1 - Important data!" > /tmp/file1.txt
    echo "This is test file 2 - Critical information!" > /tmp/file2.txt
    echo "This is test file 3 - Sensitive content!" > /tmp/file3.txt

    # Upload files
    mc cp /tmp/file1.txt erasure-demo/test-bucket/
    mc cp /tmp/file2.txt erasure-demo/test-bucket/
    mc cp /tmp/file3.txt erasure-demo/test-bucket/

    print_step "Files uploaded successfully!"
    mc ls erasure-demo/test-bucket/
}

# Show disk distribution
show_disks() {
    print_step "Showing data distribution across disks..."

    echo -e "\n${YELLOW}Disk 1:${NC}"
    find ./data/disk1 -type f 2>/dev/null | head -10 || echo "  (empty or metadata only)"

    echo -e "\n${YELLOW}Disk 2:${NC}"
    find ./data/disk2 -type f 2>/dev/null | head -10 || echo "  (empty or metadata only)"

    echo -e "\n${YELLOW}Disk 3:${NC}"
    find ./data/disk3 -type f 2>/dev/null | head -10 || echo "  (empty or metadata only)"

    echo -e "\n${YELLOW}Disk 4:${NC}"
    find ./data/disk4 -type f 2>/dev/null | head -10 || echo "  (empty or metadata only)"

    echo -e "\n${GREEN}Total files per disk:${NC}"
    echo "Disk 1: $(find ./data/disk1 -type f 2>/dev/null | wc -l) files"
    echo "Disk 2: $(find ./data/disk2 -type f 2>/dev/null | wc -l) files"
    echo "Disk 3: $(find ./data/disk3 -type f 2>/dev/null | wc -l) files"
    echo "Disk 4: $(find ./data/disk4 -type f 2>/dev/null | wc -l) files"
}

# Simulate disk failure
fail_disk() {
    local disk_num=${1:-1}

    print_warning "Simulating failure of Disk $disk_num..."

    # Stop container first
    docker compose -f docker-compose.erasure.yml stop minio-erasure

    # Corrupt/delete disk data
    rm -rf "./data/disk${disk_num}"
    mkdir -p "./data/disk${disk_num}"

    # Restart container
    docker compose -f docker-compose.erasure.yml start minio-erasure

    sleep 3

    print_step "Disk $disk_num has been wiped! Let's check if data is still accessible..."
}

# Verify data is still accessible
verify() {
    print_step "Verifying data integrity..."

    echo "Attempting to read files from MinIO..."
    echo ""

    echo -e "${YELLOW}file1.txt content:${NC}"
    mc cat erasure-demo/test-bucket/file1.txt 2>/dev/null && echo -e "${GREEN}✓ Success!${NC}" || echo -e "${RED}✗ Failed!${NC}"

    echo ""
    echo -e "${YELLOW}file2.txt content:${NC}"
    mc cat erasure-demo/test-bucket/file2.txt 2>/dev/null && echo -e "${GREEN}✓ Success!${NC}" || echo -e "${RED}✗ Failed!${NC}"

    echo ""
    echo -e "${YELLOW}file3.txt content:${NC}"
    mc cat erasure-demo/test-bucket/file3.txt 2>/dev/null && echo -e "${GREEN}✓ Success!${NC}" || echo -e "${RED}✗ Failed!${NC}"

    echo ""
    print_step "Listing all files in bucket:"
    mc ls erasure-demo/test-bucket/
}

# Fail two disks (max tolerance for 4 disks with EC:2)
fail_two_disks() {
    print_warning "Simulating failure of Disk 1 AND Disk 2..."

    docker compose -f docker-compose.erasure.yml stop minio-erasure

    rm -rf "./data/disk1"
    rm -rf "./data/disk2"
    mkdir -p "./data/disk1"
    mkdir -p "./data/disk2"

    docker compose -f docker-compose.erasure.yml start minio-erasure

    sleep 3

    print_step "Disks 1 and 2 have been wiped! Checking data..."
}

# Show erasure coding info
info() {
    print_step "Erasure Coding Configuration"

    echo "With 4 disks, MinIO uses:"
    echo ""
    echo "  ┌────────────────────────────────────┐"
    echo "  │  EC:2 (Erasure Code with 2 parity) │"
    echo "  ├────────────────────────────────────┤"
    echo "  │  Data shards:   2                  │"
    echo "  │  Parity shards: 2                  │"
    echo "  │  Total disks:   4                  │"
    echo "  │  Max failures:  2 disks            │"
    echo "  │  Efficiency:    50%                │"
    echo "  └────────────────────────────────────┘"
    echo ""
    echo "  Distribution example:"
    echo ""
    echo "  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐"
    echo "  │Disk 1│ │Disk 2│ │Disk 3│ │Disk 4│"
    echo "  │ Data │ │ Data │ │Parity│ │Parity│"
    echo "  └──────┘ └──────┘ └──────┘ └──────┘"
    echo ""
}

# =============================================================================
# WORM (Write Once Read Many) - Object Locking Demo
# =============================================================================

# Create WORM bucket
worm_setup() {
    print_step "Setting up WORM (Object Locking) bucket..."

    # Create bucket with object locking enabled
    mc mb erasure-demo/compliance-bucket --with-lock 2>/dev/null || true

    # Set default retention: COMPLIANCE mode, 1 day
    # COMPLIANCE = cannot be deleted even by admin
    # GOVERNANCE = admin can bypass with special permission
    mc retention set --default COMPLIANCE "1d" erasure-demo/compliance-bucket

    echo ""
    echo -e "${GREEN}WORM bucket created with:${NC}"
    echo "  • Object Locking: ENABLED"
    echo "  • Mode: COMPLIANCE (cannot delete, even admin)"
    echo "  • Retention: 1 day"
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│  WORM = Write Once Read Many                    │${NC}"
    echo -e "${CYAN}├─────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│  • Data cannot be modified after write          │${NC}"
    echo -e "${CYAN}│  • Data cannot be deleted until retention ends  │${NC}"
    echo -e "${CYAN}│  • Required for: LGPD, SOX, HIPAA, SEC 17a-4    │${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"
}

# Upload file to WORM bucket
worm_upload() {
    print_step "Uploading file to WORM bucket..."

    # Create a compliance document
    echo "CONFIDENTIAL FINANCIAL REPORT - $(date)" > /tmp/financial_report.txt
    echo "This document is protected by WORM retention." >> /tmp/financial_report.txt
    echo "It cannot be deleted or modified." >> /tmp/financial_report.txt

    mc cp /tmp/financial_report.txt erasure-demo/compliance-bucket/

    echo ""
    echo -e "${GREEN}File uploaded to WORM bucket!${NC}"
    mc ls erasure-demo/compliance-bucket/
}

# Try to delete WORM file (will fail)
worm_try_delete() {
    print_step "Attempting to DELETE the protected file..."

    # Get the version ID of the file
    VERSION_ID=$(mc ls --versions --json erasure-demo/compliance-bucket/financial_report.txt 2>/dev/null | grep -o '"versionId":"[^"]*"' | head -1 | cut -d'"' -f4)

    echo -e "${YELLOW}Trying to permanently delete the file version...${NC}"
    echo -e "${YELLOW}Running: mc rm --version-id $VERSION_ID erasure-demo/compliance-bucket/financial_report.txt${NC}"
    echo ""

    # Try to delete the specific version (this will fail with WORM)
    if mc rm --version-id "$VERSION_ID" erasure-demo/compliance-bucket/financial_report.txt 2>&1; then
        echo -e "${RED}Unexpected: File was deleted!${NC}"
    else
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ DELETE BLOCKED BY OBJECT LOCKING!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "The file is protected by WORM retention."
        echo "It cannot be permanently deleted until the retention period ends."
        echo ""
        echo -e "${CYAN}This protects against:${NC}"
        echo "  • Ransomware attacks"
        echo "  • Accidental deletion"
        echo "  • Malicious insiders"
        echo "  • Even administrator mistakes"
    fi
}

# Show that original version is preserved
worm_show_versions() {
    print_step "Showing protected versions..."

    echo -e "${YELLOW}All versions of the file:${NC}"
    mc ls --versions erasure-demo/compliance-bucket/financial_report.txt

    echo ""
    echo -e "${CYAN}Each version is independently protected.${NC}"
    echo "New versions can be added, but old versions cannot be deleted."
    echo "This is immutable storage - the audit trail is preserved."
}

# Show WORM status
worm_status() {
    print_step "Checking Object Lock status..."

    echo -e "${YELLOW}Bucket retention policy:${NC}"
    mc retention info erasure-demo/compliance-bucket

    echo ""
    echo -e "${YELLOW}File is still there and readable:${NC}"
    mc cat erasure-demo/compliance-bucket/financial_report.txt
}

# Full WORM demo
worm_demo() {
    print_step "Running full WORM demo..."

    worm_setup
    sleep 1
    worm_upload
    sleep 1
    worm_try_delete
    sleep 1
    worm_status
}

# Stop and cleanup
stop() {
    print_step "Stopping MinIO..."
    docker compose -f docker-compose.erasure.yml down
}

# Full cleanup
clean() {
    print_step "Cleaning up everything..."
    docker compose -f docker-compose.erasure.yml down -v 2>/dev/null || true
    rm -rf ./data
    mc alias rm erasure-demo 2>/dev/null || true
    print_step "Cleanup complete!"
}

# Show help
help() {
    echo "MinIO Erasure Coding & WORM Demo"
    echo ""
    echo "Usage: ./demo.sh <command>"
    echo ""
    echo "ERASURE CODING Commands:"
    echo "  start       Start MinIO with 4 disks"
    echo "  upload      Upload test files"
    echo "  show-disks  Show data distribution across disks"
    echo "  info        Show erasure coding configuration"
    echo "  fail-disk   Simulate single disk failure (usage: fail-disk [1-4])"
    echo "  fail-two    Simulate two disk failures"
    echo "  verify      Verify data is still accessible"
    echo ""
    echo "WORM (Object Locking) Commands:"
    echo "  worm-demo   Run full WORM demo (setup + upload + try delete)"
    echo "  worm-setup  Create WORM bucket with retention policy"
    echo "  worm-upload Upload file to WORM bucket"
    echo "  worm-delete Try to delete (will be BLOCKED)"
    echo "  worm-status Show retention status"
    echo ""
    echo "General:"
    echo "  stop        Stop MinIO"
    echo "  clean       Stop and remove all data"
    echo ""
    echo "DEMO SEQUENCE (10 min presentation):"
    echo ""
    echo "  Erasure Coding (5 min):"
    echo "    1. ./demo.sh start"
    echo "    2. ./demo.sh upload"
    echo "    3. ./demo.sh info"
    echo "    4. ./demo.sh fail-disk 1"
    echo "    5. ./demo.sh verify        # Data still works!"
    echo "    6. ./demo.sh fail-two"
    echo "    7. ./demo.sh verify        # Data STILL works!"
    echo ""
    echo "  WORM (2 min):"
    echo "    8. ./demo.sh worm-demo     # Full WORM demonstration"
    echo ""
    echo "  Cleanup:"
    echo "    9. ./demo.sh clean"
}

# Main
check_mc

case "${1:-help}" in
    start)       start ;;
    upload)      upload ;;
    show-disks)  show_disks ;;
    info)        info ;;
    fail-disk)   fail_disk "${2:-1}" ;;
    fail-two)    fail_two_disks ;;
    verify)      verify ;;
    worm-demo)   worm_demo ;;
    worm-setup)  worm_setup ;;
    worm-upload) worm_upload ;;
    worm-delete) worm_try_delete ;;
    worm-status) worm_status ;;
    stop)        stop ;;
    clean)       clean ;;
    *)           help ;;
esac
