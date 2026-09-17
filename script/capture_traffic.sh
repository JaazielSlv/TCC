#!/bin/bash
# Script para capturar tráfego no roteador
# Captura pacotes de ambas as interfaces de rede

TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [[ "$1" =~ ^[0-9]+$ ]]; then
    DURATION=$1
    INTERFACE=${2:-any}
    OUTPUT_FILE=${3:-/vagrant/datasets/trafego_${TIMESTAMP}.pcap}
else
    INTERFACE=${1:-any}
    OUTPUT_FILE=${2:-/vagrant/datasets/trafego_${TIMESTAMP}.pcap}
    DURATION=${3:-3600}
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Iniciando captura de tráfego na interface ${INTERFACE}..."
echo "Arquivo: ${OUTPUT_FILE}"
echo "Duração: ${DURATION} segundos"
echo ""
echo "Para interromper, pressione Ctrl + C"
echo ""

# Verifica se tcpdump está disponível
if ! command -v tcpdump &> /dev/null; then
    echo "❌ Erro: tcpdump não encontrado. Instale com: sudo apt-get install tcpdump"
    exit 1
fi

# Captura com tcpdump usando sudo
# -i: interface
# -w: escreve em arquivo
# -U: flush do buffer
# timeout: encerra após DURATION segundos
sudo timeout ${DURATION} tcpdump -i ${INTERFACE} -w ${OUTPUT_FILE} -U 2>&1 | tee /tmp/tcpdump_output.log

echo ""
echo "Captura finalizada."
echo "Arquivo salvo em: ${OUTPUT_FILE}"

# Verificar tamanho do arquivo
if [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "Tamanho do arquivo: $SIZE"
    
    # Contar pacotes no PCAP
    PACKET_COUNT=$(tcpdump -r "$OUTPUT_FILE" 2>/dev/null | wc -l)
    if [ $PACKET_COUNT -gt 0 ]; then
        echo "Pacotes capturados: $PACKET_COUNT"
    fi
else
    echo "❌ Erro: arquivo não foi criado!"
    exit 1
fi
