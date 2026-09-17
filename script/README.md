# Geração de Dataset com Tráfego Real Capturado

Este diretório contém os scripts para capturar tráfego real da rede e extrair features para treinamento do IDS.

## Arquivos

- `capture_traffic.sh`: captura pacotes no roteador com tcpdump
- `extract_features.py`: extrai features de um arquivo PCAP
- `traffic_generator_legitimo.sh`: simula tráfego normal no cliente legítimo
- `traffic_generator_malicioso.sh`: simula ataques no cliente malicioso
- `merge_labeled_datasets.py`: junta datasets rotulados em um único CSV

## Dependências

No roteador:
```bash
sudo apt-get update
sudo apt-get install -y tcpdump python3 python3-pip
pip3 install scapy
```

Nos clientes:
```bash
sudo apt-get update
sudo apt-get install -y curl wget dnsutils iputils-ping openssh-client
```

No cliente malicioso (já instalado pelo Ansible):
```bash
nmap
hping3
hydra
```

## Passo a passo detalhado para gerar o dataset real (com múltiplas execuções)

### ⚠️ IMPORTANTE: Configuração e Preparação

Antes de começar, certifique-se de que:

1. **As VMs estão rodando:**
   ```bash
   vagrant status
   # Deve mostrar: cliente_classico_1, cliente_malicioso, roteador, cliente_classico_2, servidor - all running
   ```

2. **O roteador tem 2 GB de RAM** (verificado no Vagrantfile)

3. **Dependências no roteador:**
   ```bash
   vagrant ssh roteador
   
   # Dentro da VM roteador:
   sudo apt-get update
   sudo apt-get install -y tcpdump python3 python3-pip
   pip3 install scapy
   
   # Verificar instalação
   which tcpdump
   python3 -c "import scapy; print('Scapy OK')"
   ```

4. **Dependências no cliente normal:**
   ```bash
   vagrant ssh cliente_classico_1
   
   # Dentro da VM:
   sudo apt-get update
   sudo apt-get install -y curl wget dnsutils iputils-ping openssh-client
   exit
   ```

5. **Ferramentas já instaladas no cliente malicioso** (pelo Ansible):
   - nmap
   - hping3
   - hydra

---

## Fase 1: Capturar tráfego legítimo (ITERAÇÃO 1)

### Passo 1.1: Abrir Terminal 1 - Roteador para captura

```bash
# No seu computador host (Windows/Linux/Mac):
cd d:\faculdade\TCC  # ou seu caminho do projeto

# Conectar ao roteador
vagrant ssh roteador

# Dentro da VM roteador:
cd /vagrant
mkdir -p datasets  # Criar pasta se não existir
```

### Passo 1.2: Iniciar captura de pacotes

No mesmo Terminal 1 do roteador, execute:

```bash
# Isso vai rodar por exatamente 1 hora e gerar um arquivo .pcap com timestamp
bash script/capture_traffic.sh eth1
```

**Você verá:**
```
Iniciando captura de tráfego na interface eth1...
Arquivo: /vagrant/datasets/trafego_20250827_143022.pcap
Duração: 3600 segundos
```

✅ **Deixe rodando e abra outro terminal**

---

### Passo 1.3: Abrir Terminal 2 - Cliente normal para gerar tráfego

Enquanto o Terminal 1 captura no roteador, em outro terminal do seu computador:

```bash
cd d:\faculdade\TCC

# Conectar ao cliente normal
vagrant ssh cliente_classico_1

# Dentro da VM cliente:
cd /vagrant
```

### Passo 1.4: Gerar tráfego legítimo

No Terminal 2, execute:

```bash
# Isso vai rodar por 1 hora gerando tráfego normal
bash script/traffic_generator_legitimo.sh
```

**Você verá:**
```
Iniciando geração de tráfego legítimo por 3600 segundos...
Alvo: servidor em 192.168.57.20
[14:30:22] Gerando HTTP requests...
[14:30:22] Gerando DNS queries...
[14:30:22] Gerando ICMP...
[14:30:22] Tentando conexão SSH...
```

✅ **Deixe rodando também. Agora ambos estão capturando e gerando simultaneamente por 1 hora**

**Aguarde ~1 hora** até que ambos os terminais terminem.

---

### Passo 1.5: Extrair features do PCAP capturado

Depois que os 2 scripts terminarem, volte ao **Terminal 1 do roteador** e execute:

```bash
# Dentro do roteador (você ainda está em /vagrant):

# Listar os PCAPs gerados para confirmar
ls -lh datasets/*.pcap

# Você deve ver algo como:
# -rw-r--r-- ... 250M ... datasets/trafego_20250827_143022.pcap

# Extrair features (use o nome do seu arquivo PCAP)
python3 script/extract_features.py --pcap datasets/trafego_20250827_143022.pcap

# Isso vai gerar automaticamente:
# datasets/trafego_20250827_143022_features_20250827_150122.csv
```

**Você verá:**
```
Lendo arquivo PCAP: datasets/trafego_20250827_143022.pcap
Total de pacotes lidos: 45821
Total de fluxos identificados: 312
Fluxos processados com sucesso: 312
CSV gerado em: datasets/trafego_20250827_143022_features_20250827_150122.csv

⚠️  IMPORTANTE: Rotule manualmente o arquivo!
   - Abra o arquivo CSV
   - Na coluna 'label', preencha:
     0 = tráfego legítimo
     1 = tráfego malicioso
```

---

### Passo 1.6: Rotular o arquivo como LEGÍTIMO (0)

Ainda no **Terminal 1 do roteador**:

```bash
# Copie e cole este comando Python completo no Terminal:
python3 << 'EOF'
import csv
import glob

# Encontra o CSV mais recente gerado
csv_files = glob.glob('/vagrant/datasets/trafego_*_features_*.csv')
if csv_files:
    latest_csv = sorted(csv_files)[-1]  # Pega o mais recente
    print(f"Rotulando: {latest_csv}")
    
    with open(latest_csv, 'r', newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        linhas = list(reader)
    
    # Preenche label com 0 (legítimo)
    for linha in linhas:
        linha[-1] = '0'
    
    # Salva com novo nome
    output = latest_csv.replace('.csv', '_rotulado.csv')
    with open(output, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(linhas)
    
    print(f"✅ Rotulado e salvo como: {output}")
    print(f"Total de fluxos: {len(linhas)}")
else:
    print("❌ Nenhum CSV encontrado!")
EOF
```

**Resultado esperado:**
```
Rotulando: /vagrant/datasets/trafego_20250827_143022_features_20250827_150122.csv
✅ Rotulado e salvo como: /vagrant/datasets/trafego_20250827_143022_features_20250827_150122_rotulado.csv
Total de fluxos: 312
```

✅ **Fim da ITERAÇÃO 1 de tráfego legítimo**

---

## Repetir ITERAÇÃO 2 e 3 de tráfego legítimo

Repita os passos 1.1 a 1.6 **mais 2 vezes**.

Os timestamps garantem que cada execução gera novos arquivos:
- `trafego_20250827_160145.pcap` (iteração 2)
- `trafego_20250827_170356.pcap` (iteração 3)

Você terá **3 arquivos rotulados** ao final:
```
datasets/trafego_20250827_143022_features_20250827_150122_rotulado.csv
datasets/trafego_20250827_160145_features_20250827_163245_rotulado.csv
datasets/trafego_20250827_170356_features_20250827_173456_rotulado.csv
```

---

## Fase 2: Capturar tráfego malicioso (ITERAÇÃO 1)

### Passo 2.1: Abrir Terminal 1 - Roteador para captura

No Terminal 1 do roteador (ou reconecte):

```bash
vagrant ssh roteador
cd /vagrant
```

### Passo 2.2: Iniciar captura

```bash
bash script/capture_traffic.sh eth1
```

✅ **Deixe rodando**

---

### Passo 2.3: Abrir Terminal 2 - Cliente malicioso para gerar ataques

Em outro terminal:

```bash
cd d:\faculdade\TCC
vagrant ssh cliente_malicioso
cd /vagrant
```

### Passo 2.4: Gerar tráfego malicioso

```bash
bash script/traffic_generator_malicioso.sh
```

**Você verá:**
```
Iniciando geração de tráfego malicioso por 3600 segundos...
Alvo: servidor em 192.168.57.20 e cliente em 192.168.57.12
[15:00:00] Executando port scan...
[15:00:00] Gerando SYN flood...
[15:00:00] Tentando brute force SSH...
[15:00:00] Varredura UDP...
```

✅ **Deixe rodando. Aguarde ~1 hora**

---

### Passo 2.5: Extrair features

No **Terminal 1 do roteador**, após ambos terminarem:

```bash
# Listar os PCAPs
ls -lh datasets/*.pcap | tail -3

# Extrair do mais recente (tráfego malicioso)
python3 script/extract_features.py --pcap datasets/trafego_XXXXXXX_XXXXXX.pcap
```

**Você verá:**
```
Total de fluxos identificados: 287
Fluxos processados com sucesso: 287
CSV gerado em: datasets/trafego_XXXXXXX_XXXXXX_features_XXXXXXX_XXXXXX.csv
```

---

### Passo 2.6: Rotular o arquivo como MALICIOSO (1)

Ainda no **Terminal 1 do roteador**:

```bash
python3 << 'EOF'
import csv
import glob

csv_files = glob.glob('/vagrant/datasets/trafego_*_features_*.csv')
if csv_files:
    latest_csv = sorted(csv_files)[-1]
    print(f"Rotulando como MALICIOSO: {latest_csv}")
    
    with open(latest_csv, 'r', newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        linhas = list(reader)
    
    # Preenche label com 1 (malicioso)
    for linha in linhas:
        linha[-1] = '1'
    
    output = latest_csv.replace('.csv', '_rotulado.csv')
    with open(output, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(linhas)
    
    print(f"✅ Salvo como: {output}")
    print(f"Total de fluxos maliciosos: {len(linhas)}")
else:
    print("❌ Nenhum CSV encontrado!")
EOF
```

✅ **Fim da ITERAÇÃO 1 de tráfego malicioso**

---

## Repetir ITERAÇÃO 2 e 3 de tráfego malicioso

Repita os passos 2.1 a 2.6 **mais 2 vezes**.

Você terá **3 arquivos rotulados de malicioso** ao final.

---

## Fase 3: Verificar e listar todos os arquivos

No **Terminal 1 do roteador**:

```bash
# Listar todos os arquivos rotulados
ls -lh datasets/*_rotulado.csv

# Resultado esperado:
# 6 arquivos no total
# datasets/trafego_20250827_143022_features_20250827_150122_rotulado.csv (legítimo)
# datasets/trafego_20250827_160145_features_20250827_163245_rotulado.csv (legítimo)
# datasets/trafego_20250827_170356_features_20250827_173456_rotulado.csv (legítimo)
# datasets/trafego_20250827_180567_features_20250827_183667_rotulado.csv (malicioso)
# datasets/trafego_20250827_190678_features_20250827_193778_rotulado.csv (malicioso)
# datasets/trafego_20250827_200789_features_20250827_203889_rotulado.csv (malicioso)
```

---

## Fase 4: Combinar todos os arquivos rotulados em um dataset final

No **Terminal 1 do roteador**:

```bash
python3 << 'EOF'
import csv
import glob
import os

# Encontra todos os arquivos rotulados
rotulados = sorted(glob.glob('/vagrant/datasets/*_rotulado.csv'))

print(f"Encontrados {len(rotulados)} arquivos rotulados:")
for f in rotulados:
    label = open(f).readlines()[1].split(',')[-1].strip()
    print(f"  - {os.path.basename(f)} (label: {label})")

if len(rotulados) < 2:
    print("❌ Precisa de pelo menos 2 arquivos rotulados!")
    exit(1)

# Combina todos
cabecalho = None
todas_as_linhas = []

for arquivo in rotulados:
    with open(arquivo, 'r', newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        if cabecalho is None:
            cabecalho = next(reader)
        else:
            next(reader)  # skip header
        todas_as_linhas.extend(list(reader))

# Salva dataset final
output = '/vagrant/datasets/dataset_completo.csv'
with open(output, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(cabecalho)
    writer.writerows(todas_as_linhas)

print(f"\n✅ Dataset final gerado: {output}")
print(f"Total de fluxos: {len(todas_as_linhas)}")

# Conta legítimos vs maliciosos
with open(output) as f:
    reader = csv.reader(f)
    next(reader)  # skip header
    legit = sum(1 for row in reader if row[-1] == '0')
    
with open(output) as f:
    reader = csv.reader(f)
    next(reader)
    mal = sum(1 for row in reader if row[-1] == '1')

print(f"  - Tráfego legítimo: {legit} fluxos")
print(f"  - Tráfego malicioso: {mal} fluxos")
EOF
```

**Resultado esperado:**
```
Encontrados 6 arquivos rotulados:
  - trafego_20250827_143022_features_20250827_150122_rotulado.csv (label: 0)
  - trafego_20250827_160145_features_20250827_163245_rotulado.csv (label: 0)
  - trafego_20250827_170356_features_20250827_173456_rotulado.csv (label: 0)
  - trafego_20250827_180567_features_20250827_183667_rotulado.csv (label: 1)
  - trafego_20250827_190678_features_20250827_193778_rotulado.csv (label: 1)
  - trafego_20250827_200789_features_20250827_203889_rotulado.csv (label: 1)

✅ Dataset final gerado: /vagrant/datasets/dataset_completo.csv
Total de fluxos: 1847
  - Tráfego legítimo: 936 fluxos
  - Tráfego malicioso: 911 fluxos
```

✅ **Seu dataset está pronto para treinar o modelo!**

---

## Observações

- O arquivo CSV final `dataset_completo.csv` contém os 12 features + label (0 ou 1)
- Cada linha representa um fluxo de rede capturado
- O label indica se o fluxo foi legítimo (0) ou malicioso (1)
- Este dataset será usado para treinar o modelo Decision Tree

## Interfaces de rede no roteador

- `eth0`: NAT (conexão com o host)
- `eth1`: rede externa (192.168.56.0/24) com cliente_classico_1 e cliente_malicioso
- `eth2`: rede interna (192.168.57.0/24) com cliente_classico_2 e servidor

Você pode capturar em `eth1`, `eth2` ou ambas (use `any`):

```bash
bash script/capture_traffic.sh any datasets/trafego_completo.pcap 1800
```

## Troubleshooting

Se a extração de features falhar com erro de scapy:

```bash
pip3 install --upgrade scapy
```

Se tcpdump pedir permissões:

```bash
sudo bash script/capture_traffic.sh eth1 datasets/trafego.pcap 1800
```
```

Esse comando roda continuamente e só para quando você pressionar `Ctrl + C`.

### 2) Gerar o dataset malicioso no cliente atacante

No terminal da VM `cliente_malicioso` execute:

```bash
cd /vagrant
python3 script/generate_malicioso.py --output datasets/trafego_malicioso.csv --intervalo-segundos 0.5
```

Esse também roda até você interromper manualmente.

### 3) Copiar os arquivos CSV para o roteador

Depois de gerar os arquivos, copie ambos para a mesma pasta no `roteador`:

```bash
scp vagrant@192.168.56.11:/vagrant/datasets/trafego_legitimo.csv /vagrant/datasets/
scp vagrant@192.168.56.66:/vagrant/datasets/trafego_malicioso.csv /vagrant/datasets/
```

### 4) Juntar os dois datasets

No terminal do `roteador` ou em outra máquina central:

```bash
cd /vagrant
python3 script/merge_datasets.py --legitimo datasets/trafego_legitimo.csv --malicioso datasets/trafego_malicioso.csv --saida datasets/dataset_completo.csv
```

## Observações

- Os scripts criam a pasta de saída automaticamente.
- O comportamento padrão é contínuo: eles ficam gerando até você mandar parar com `Ctrl + C`.
- Se quiser limitar manualmente por quantidade, use `--max-registros`, por exemplo:

```bash
python3 script/generate_legitimo.py --output datasets/trafego_legitimo.csv --intervalo-segundos 0.5 --max-registros 5000
```

- O arquivo final `dataset_completo.csv` será usado para treinar o modelo de Machine Learning.

## Exemplo de uso rapido

```bash
# Cliente legítimo
cd /vagrant
python3 script/generate_legitimo.py --output datasets/trafego_legitimo.csv --intervalo-segundos 0.5

# Cliente malicioso
cd /vagrant
python3 script/generate_malicioso.py --output datasets/trafego_malicioso.csv --intervalo-segundos 0.5

# Roteador ou host central
cd /vagrant
python3 script/merge_datasets.py --legitimo datasets/trafego_legitimo.csv --malicioso datasets/trafego_malicioso.csv --saida datasets/dataset_completo.csv
```
