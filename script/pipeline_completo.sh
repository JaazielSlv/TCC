#!/bin/bash
# Pipeline completo para gerar dataset: captura + extração + labeling + merge
# Uso: bash script/pipeline_completo.sh [legítimo|malicioso|merge]

set -e

VAGRANT_DIR="/vagrant"
SCRIPT_DIR="${VAGRANT_DIR}/script"
DATASETS_DIR="${VAGRANT_DIR}/datasets"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1" >&2
}

# Verificar se está no roteador
if [[ ! -f /etc/hostname ]] || ! grep -q "roteador" /etc/hostname 2>/dev/null; then
    log_error "Este script deve ser executado NO ROTEADOR!"
    log_info "Execute: vagrant ssh roteador"
    exit 1
fi

# Verificar se /vagrant está acessível
if [[ ! -d "$VAGRANT_DIR" ]]; then
    log_error "Diretório $VAGRANT_DIR não encontrado!"
    exit 1
fi

# ============ FASE 1: CAPTURAR TRÁFEGO ============
capturar_trafego() {
    local tipo=$1  # "legítimo" ou "malicioso"
    local duracao=${2:-3600}  # 1 hora padrão
    local iteracao=$3
    
    log_info "=== CAPTURANDO TRÁFEGO $tipo (Iteração $iteracao) ==="
    log_info "Duração: $duracao segundos"
    log_info "IMPORTANTE: Inicie o gerador de tráfego em outro terminal AGORA!"
    log_info "  Legítimo: vagrant ssh cliente_classico_1 && cd /vagrant && bash script/traffic_generator_legitimo.sh"
    log_info "  Malicioso: vagrant ssh cliente_malicioso && cd /vagrant && bash script/traffic_generator_malicioso.sh"
    log_info "Captura iniciando em 5 segundos..."
    sleep 5
    
    bash "$SCRIPT_DIR/capture_traffic.sh" "$duracao"
    
    # Encontrar o arquivo PCAP mais recente
    PCAP_FILE=$(ls -t "$DATASETS_DIR"/trafego_*.pcap 2>/dev/null | head -1)
    
    if [[ -z "$PCAP_FILE" ]]; then
        log_error "Nenhum arquivo PCAP foi criado!"
        return 1
    fi
    
    log_info "PCAP capturado: $(basename "$PCAP_FILE")"
    echo "$PCAP_FILE"
}

# ============ FASE 2: EXTRAIR FEATURES ============
extrair_features() {
    local pcap_file=$1
    local tipo=$2  # "legítimo" ou "malicioso"
    local iteracao=$3
    
    if [[ ! -f "$pcap_file" ]]; then
        log_error "Arquivo PCAP não encontrado: $pcap_file"
        return 1
    fi
    
    log_info "=== EXTRAINDO FEATURES ($tipo, Iteração $iteracao) ==="
    log_info "Entrada: $(basename "$pcap_file")"
    
    cd "$VAGRANT_DIR"
    python3 "$SCRIPT_DIR/extract_features.py" --pcap "$pcap_file"
    
    # Encontrar o arquivo CSV mais recente
    CSV_FILE=$(ls -t "$DATASETS_DIR"/*_features_*.csv 2>/dev/null | head -1)
    
    if [[ -z "$CSV_FILE" ]]; then
        log_error "Nenhum arquivo CSV foi criado!"
        return 1
    fi
    
    log_info "Features extraídas: $(basename "$CSV_FILE")"
    echo "$CSV_FILE"
}

# ============ FASE 3: ROTULAR DATASET ============
rotular_dataset() {
    local csv_file=$1
    local label=$2  # 0 para legítimo, 1 para malicioso
    local tipo=$3
    local iteracao=$4
    
    if [[ ! -f "$csv_file" ]]; then
        log_error "Arquivo CSV não encontrado: $csv_file"
        return 1
    fi
    
    log_info "=== ROTULANDO DATASET ($tipo=$label, Iteração $iteracao) ==="
    
    # Criar arquivo temporário com labels
    local csv_labeled="${csv_file%.csv}_labeled_$label.csv"
    
    # Adicionar labels à coluna final
    awk -F',' -v OFS=',' -v label="$label" 'NR==1 {print; next} {$(NF)=label; print}' "$csv_file" > "$csv_labeled.tmp"
    mv "$csv_labeled.tmp" "$csv_labeled"
    
    log_info "Dataset rotulado: $(basename "$csv_labeled")"
    echo "$csv_labeled"
}

# ============ FASE 4: MESCLAR DATASETS ============
mesclar_datasets() {
    log_info "=== MESCLANDO TODOS OS DATASETS ==="
    
    cd "$VAGRANT_DIR"
    
    # Coletar todos os CSVs rotulados
    local legit_files=($(ls -t "$DATASETS_DIR"/*_labeled_0.csv 2>/dev/null | head -3))
    local malici_files=($(ls -t "$DATASETS_DIR"/*_labeled_1.csv 2>/dev/null | head -3))
    
    if [[ ${#legit_files[@]} -eq 0 ]] || [[ ${#malici_files[@]} -eq 0 ]]; then
        log_error "Não há datasets legítimos ou maliciosos para mesclar!"
        log_error "Legítimos encontrados: ${#legit_files[@]}"
        log_error "Maliciosos encontrados: ${#malici_files[@]}"
        return 1
    fi
    
    log_info "Datasets legítimos a mesclar: ${#legit_files[@]}"
    log_info "Datasets maliciosos a mesclar: ${#malici_files[@]}"
    
    python3 "$SCRIPT_DIR/merge_labeled_datasets.py" \
        --legitimo "${legit_files[@]}" \
        --malicioso "${malici_files[@]}" \
        --saida "$DATASETS_DIR/dataset_completo.csv"
    
    if [[ -f "$DATASETS_DIR/dataset_completo.csv" ]]; then
        local num_linhas=$(tail -n +2 "$DATASETS_DIR/dataset_completo.csv" | wc -l)
        log_info "Dataset final criado com sucesso!"
        log_info "Total de fluxos: $num_linhas"
        echo "$DATASETS_DIR/dataset_completo.csv"
    else
        log_error "Falha ao criar dataset completo!"
        return 1
    fi
}

# ============ MENU PRINCIPAL ============
mostrar_menu() {
    echo ""
    echo -e "${GREEN}========== PIPELINE DE GERAÇÃO DE DATASET ==========${NC}"
    echo "1. Capturar tráfego LEGÍTIMO (3 iterações de 1 hora)"
    echo "2. Capturar tráfego MALICIOSO (3 iterações de 1 hora)"
    echo "3. Extrair features de todos os PCAPs"
    echo "4. Rotular e mesclar datasets"
    echo "5. Executar pipeline COMPLETO (1 + 2 + 3 + 4)"
    echo "6. Teste RÁPIDO (60 segundos cada)"
    echo "7. Verificar dados existentes"
    echo "0. Sair"
    echo -e "${GREEN}==================================================${NC}"
    echo ""
}

# ============ OPÇÃO: TESTE RÁPIDO ============
teste_rapido() {
    log_info "=== TESTE RÁPIDO (60 segundos) ==="
    log_info "Passo 1: Iniciando captura por 60 segundos"
    log_info "Passo 2: Em OUTRO terminal, execute:"
    log_info "  vagrant ssh cliente_classico_1 && cd /vagrant && bash script/traffic_generator_legitimo.sh 60"
    log_info ""
    read -p "Pressione ENTER quando o gerador estiver pronto..."
    
    PCAP=$(capturar_trafego "TEST" 60 "1")
    CSV=$(extrair_features "$PCAP" "TEST" "1")
    
    log_info "Teste concluído!"
    log_info "PCAP: $PCAP"
    log_info "CSV: $CSV"
    
    # Contar linhas
    local linhas=$(tail -n +2 "$CSV" | wc -l)
    log_info "Total de fluxos extraídos: $linhas"
    
    if [[ $linhas -lt 10 ]]; then
        log_warning "Volume de tráfego muito baixo! Verifique se o gerador rodou."
    fi
}

# ============ OPÇÃO: VERIFICAR DADOS ============
verificar_dados() {
    echo ""
    log_info "=== DADOS DISPONÍVEIS ==="
    
    echo -e "\n${YELLOW}Arquivos PCAP:${NC}"
    ls -lh "$DATASETS_DIR"/trafego_*.pcap 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    
    echo -e "\n${YELLOW}Arquivos CSV (features):${NC}"
    ls -lh "$DATASETS_DIR"/*_features_*.csv 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    
    echo -e "\n${YELLOW}Arquivos CSV (labeled):${NC}"
    ls -lh "$DATASETS_DIR"/*_labeled_*.csv 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    
    echo -e "\n${YELLOW}Dataset final:${NC}"
    if [[ -f "$DATASETS_DIR/dataset_completo.csv" ]]; then
        local size=$(ls -lh "$DATASETS_DIR/dataset_completo.csv" | awk '{print $5}')
        local linhas=$(tail -n +2 "$DATASETS_DIR/dataset_completo.csv" | wc -l)
        echo "  dataset_completo.csv ($size, $linhas fluxos)"
    else
        echo "  ❌ Ainda não criado"
    fi
    echo ""
}

# ============ EXECUÇÃO ============
if [[ $# -eq 0 ]]; then
    # Modo interativo
    while true; do
        mostrar_menu
        read -p "Escolha uma opção: " opcao
        
        case $opcao in
            1)
                for i in {1..3}; do
                    PCAP=$(capturar_trafego "LEGÍTIMO" 3600 $i)
                    CSV=$(extrair_features "$PCAP" "LEGÍTIMO" $i)
                    CSV=$(rotular_dataset "$CSV" 0 "LEGÍTIMO" $i)
                    log_info "Iteração $i concluída: $CSV"
                done
                ;;
            2)
                for i in {1..3}; do
                    PCAP=$(capturar_trafego "MALICIOSO" 3600 $i)
                    CSV=$(extrair_features "$PCAP" "MALICIOSO" $i)
                    CSV=$(rotular_dataset "$CSV" 1 "MALICIOSO" $i)
                    log_info "Iteração $i concluída: $CSV"
                done
                ;;
            3)
                cd "$VAGRANT_DIR"
                for pcap in "$DATASETS_DIR"/trafego_*.pcap; do
                    if [[ ! -f "${pcap%.*}_features_*.csv" ]]; then
                        log_info "Extraindo features de $(basename "$pcap")"
                        python3 "$SCRIPT_DIR/extract_features.py" --pcap "$pcap"
                    fi
                done
                ;;
            4)
                mesclar_datasets
                ;;
            5)
                log_info "Pipeline completo não implementado interativamente. Use opções 1-4."
                ;;
            6)
                teste_rapido
                ;;
            7)
                verificar_dados
                ;;
            0)
                log_info "Saindo..."
                exit 0
                ;;
            *)
                log_error "Opção inválida!"
                ;;
        esac
    done
else
    # Modo linha de comando
    case "$1" in
        legítimo)
            PCAP=$(capturar_trafego "LEGÍTIMO" ${2:-3600} 1)
            CSV=$(extrair_features "$PCAP" "LEGÍTIMO" 1)
            rotular_dataset "$CSV" 0 "LEGÍTIMO" 1
            ;;
        malicioso)
            PCAP=$(capturar_trafego "MALICIOSO" ${2:-3600} 1)
            CSV=$(extrair_features "$PCAP" "MALICIOSO" 1)
            rotular_dataset "$CSV" 1 "MALICIOSO" 1
            ;;
        merge)
            mesclar_datasets
            ;;
        teste)
            teste_rapido
            ;;
        *)
            log_error "Uso: bash script/pipeline_completo.sh [legítimo|malicioso|merge|teste]"
            exit 1
            ;;
    esac
fi
