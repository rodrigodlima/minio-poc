#!/bin/bash

# =============================================================================
# MinIO WORM Demo - Ransomware Protection (2.5 min presentation)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear_screen() {
    clear
}

pause() {
    echo ""
    read -p "Pressione ENTER para continuar..."
    echo ""
}

# Check mc
check_mc() {
    if ! command -v mc &> /dev/null; then
        echo "Instalando MinIO Client..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install minio/stable/mc
        else
            curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
            chmod +x mc && sudo mv mc /usr/local/bin/
        fi
    fi
}

# =============================================================================
# DEMO STEPS
# =============================================================================

step1_start() {
    clear_screen
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║     MinIO WORM - PROTEÇÃO CONTRA RANSOMWARE                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}Iniciando ambiente MinIO...${NC}"
    echo ""

    rm -rf ./data 2>/dev/null
    mkdir -p ./data/disk{1,2,3,4}
    docker compose -f docker-compose.erasure.yml up -d 2>/dev/null

    echo "Aguardando MinIO iniciar..."
    sleep 5

    mc alias set erasure-demo http://localhost:9010 myminio minio123 --api S3v4 2>/dev/null || true

    echo -e "${GREEN}✓ MinIO pronto!${NC}"
}

step2_create_worm_bucket() {
    clear_screen
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  PASSO 1: Criar Bucket com Object Locking (WORM)              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    echo -e "${YELLOW}Criando bucket com proteção WORM...${NC}"
    echo ""
    echo -e "${CYAN}$ mc mb erasure-demo/backup-critico --with-lock${NC}"
    mc mb erasure-demo/backup-critico --with-lock 2>/dev/null || true

    echo ""
    echo -e "${CYAN}$ mc retention set --default COMPLIANCE \"1d\" erasure-demo/backup-critico${NC}"
    mc retention set --default COMPLIANCE "1d" erasure-demo/backup-critico 2>/dev/null || true

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ BUCKET CRIADO COM PROTEÇÃO WORM                            ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║  Modo: COMPLIANCE (nem admin pode deletar)                    ║${NC}"
    echo -e "${GREEN}║  Retenção: 1 dia (configurável para anos)                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

step3_upload_critical_data() {
    clear_screen
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  PASSO 2: Upload de Dados Críticos                            ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    # Create realistic backup files
    echo "BACKUP FINANCEIRO - $(date)" > /tmp/backup_financeiro.txt
    echo "================================" >> /tmp/backup_financeiro.txt
    echo "Receita Q4: R$ 15.000.000,00" >> /tmp/backup_financeiro.txt
    echo "Despesas Q4: R$ 8.500.000,00" >> /tmp/backup_financeiro.txt
    echo "Lucro: R$ 6.500.000,00" >> /tmp/backup_financeiro.txt

    echo -e "${YELLOW}Fazendo upload do backup crítico...${NC}"
    echo ""
    echo -e "${CYAN}$ mc cp backup_financeiro.txt erasure-demo/backup-critico/${NC}"
    mc cp /tmp/backup_financeiro.txt erasure-demo/backup-critico/

    echo ""
    echo -e "${GREEN}✓ Arquivo armazenado com proteção WORM${NC}"
    echo ""
    echo -e "${YELLOW}Conteúdo do arquivo:${NC}"
    echo ""
    mc cat erasure-demo/backup-critico/backup_financeiro.txt
}

step4_ransomware_attack() {
    clear_screen
    echo -e "${BOLD}${RED}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  SIMULAÇÃO: ATAQUE DE RANSOMWARE                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    echo -e "${RED}${BOLD}Cenário: Atacante obteve credenciais de ADMINISTRADOR${NC}"
    echo ""
    echo -e "${MAGENTA}Atacante tentando deletar todos os backups...${NC}"
    echo ""

    sleep 1

    # Get version ID
    VERSION_ID=$(mc ls --versions --json erasure-demo/backup-critico/backup_financeiro.txt 2>/dev/null | grep -o '"versionId":"[^"]*"' | head -1 | cut -d'"' -f4)

    echo -e "${RED}$ mc rm --version-id $VERSION_ID erasure-demo/backup-critico/backup_financeiro.txt${NC}"
    echo ""

    sleep 1

    # Try to delete (will fail)
    if mc rm --version-id "$VERSION_ID" erasure-demo/backup-critico/backup_financeiro.txt 2>&1; then
        echo -e "${RED}Arquivo deletado!${NC}"
    else
        echo ""
        sleep 1
        echo -e "${GREEN}${BOLD}"
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║                                                               ║"
        echo "║   🛡️  DELEÇÃO BLOQUEADA PELO OBJECT LOCKING!                  ║"
        echo "║                                                               ║"
        echo "║   O atacante NÃO CONSEGUIU deletar os dados!                  ║"
        echo "║                                                               ║"
        echo "║   Mesmo com acesso de ADMINISTRADOR, os dados estão           ║"
        echo "║   protegidos até o fim do período de retenção.                ║"
        echo "║                                                               ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    fi
}

step5_verify_data() {
    clear_screen
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  PASSO 4: Verificar que Dados Estão Intactos                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    echo -e "${YELLOW}Verificando integridade dos dados após o ataque...${NC}"
    echo ""

    echo -e "${CYAN}$ mc cat erasure-demo/backup-critico/backup_financeiro.txt${NC}"
    echo ""
    mc cat erasure-demo/backup-critico/backup_financeiro.txt

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  ✓ DADOS 100% INTACTOS!                                       ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║                                                               ║"
    echo "║  WORM protege contra:                                         ║"
    echo "║    • Ransomware                                               ║"
    echo "║    • Deleção acidental                                        ║"
    echo "║    • Funcionários maliciosos                                  ║"
    echo "║    • Erros de administradores                                 ║"
    echo "║                                                               ║"
    echo "║  Compliance: LGPD, SOX, HIPAA, SEC 17a-4                      ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

step6_show_retention() {
    clear_screen
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  Status da Retenção                                           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    echo -e "${CYAN}$ mc retention info erasure-demo/backup-critico${NC}"
    echo ""
    mc retention info erasure-demo/backup-critico

    echo ""
    echo -e "${YELLOW}Configurações disponíveis:${NC}"
    echo ""
    echo "  • COMPLIANCE: Ninguém pode deletar (nem root/admin)"
    echo "  • GOVERNANCE: Admin pode bypassar com permissão especial"
    echo "  • Retenção: De minutos até anos"
    echo ""
}

cleanup() {
    echo ""
    echo -e "${YELLOW}Limpando ambiente de demonstração...${NC}"
    docker compose -f docker-compose.erasure.yml down 2>/dev/null || true
    rm -rf ./data 2>/dev/null || true
    mc alias rm erasure-demo 2>/dev/null || true
    echo -e "${GREEN}✓ Ambiente limpo${NC}"
}

# =============================================================================
# FULL DEMO (2.5 minutes)
# =============================================================================

full_demo() {
    check_mc

    step1_start
    pause

    step2_create_worm_bucket
    pause

    step3_upload_critical_data
    pause

    step4_ransomware_attack
    pause

    step5_verify_data
    pause

    step6_show_retention

    echo ""
    echo -e "${BOLD}${GREEN}Demo concluída!${NC}"
    echo ""
    read -p "Pressione ENTER para limpar o ambiente (ou Ctrl+C para manter)..."
    cleanup
}

# Quick demo without pauses (for practice)
quick_demo() {
    check_mc
    step1_start
    step2_create_worm_bucket
    step3_upload_critical_data
    step4_ransomware_attack
    step5_verify_data
    step6_show_retention
}

# =============================================================================
# MAIN
# =============================================================================

case "${1:-demo}" in
    demo)       full_demo ;;
    quick)      quick_demo ;;
    start)      check_mc && step1_start ;;
    bucket)     step2_create_worm_bucket ;;
    upload)     step3_upload_critical_data ;;
    attack)     step4_ransomware_attack ;;
    verify)     step5_verify_data ;;
    retention)  step6_show_retention ;;
    clean)      cleanup ;;
    *)
        echo "MinIO WORM - Ransomware Protection Demo"
        echo ""
        echo "Uso: ./demo-ransomware.sh [comando]"
        echo ""
        echo "Comandos:"
        echo "  demo      Demo completa com pausas (2.5 min)"
        echo "  quick     Demo rápida sem pausas (para treinar)"
        echo "  clean     Limpar ambiente"
        echo ""
        echo "Passos individuais:"
        echo "  start     Iniciar MinIO"
        echo "  bucket    Criar bucket WORM"
        echo "  upload    Upload de dados"
        echo "  attack    Simular ataque ransomware"
        echo "  verify    Verificar dados intactos"
        echo "  retention Mostrar status retenção"
        ;;
esac
