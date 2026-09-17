#!/bin/bash
# Script para gerar tráfego legítimo no cliente normal
# Simula comportamento normal de rede: HTTP, DNS, ICMP

# NÃO use 'set -e': queremos continuar mesmo se um comando falhar

TARGET_SERVER="192.168.57.20"
TARGET_CLIENT2="192.168.57.12"
DURATION=${1:-3600}  # padrão: 1 hora (3600 segundos)

echo "Iniciando geração de tráfego legítimo por ${DURATION} segundos..."
echo "Alvo: servidor em ${TARGET_SERVER}"
echo "Log: /tmp/traffic_legitimo_$(date +%s).log"
LOG_FILE="/tmp/traffic_legitimo_$(date +%s).log"

END_TIME=$(($(date +%s) + DURATION))

# Função para parar ao pressionar Ctrl+C
trap "echo 'Tráfego legítimo interrompido'; exit 0" SIGINT SIGTERM

while [ $(date +%s) -lt $END_TIME ]; do
    # HTTP requests
    echo "[$(date '+%H:%M:%S')] Gerando HTTP requests..." | tee -a "$LOG_FILE"
    for i in {1..20}; do
        curl -s --connect-timeout 3 "http://${TARGET_SERVER}/" > /dev/null 2>&1 &
    done

    # DNS queries
    echo "[$(date '+%H:%M:%S')] Gerando DNS queries..." | tee -a "$LOG_FILE"
    for i in {1..5}; do
        nslookup google.com 127.0.0.53 > /dev/null 2>&1 &
        nslookup github.com 127.0.0.53 > /dev/null 2>&1 &
    done

    # ICMP (ping)
    echo "[$(date '+%H:%M:%S')] Gerando ICMP..." | tee -a "$LOG_FILE"
    ping -c 5 ${TARGET_SERVER} > /dev/null 2>&1 &

    # SSH para servidor (com timeout explícito)
    echo "[$(date '+%H:%M:%S')] Tentando conexão SSH..." | tee -a "$LOG_FILE"
    for i in {1..3}; do
        timeout 5 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no vagrant@${TARGET_SERVER} "echo 'connection test'" > /dev/null 2>&1 &
    done

    # Aguarda apenas 1 segundo antes da próxima iteração
    sleep 1

done

echo "Geração de tráfego legítimo concluída."
