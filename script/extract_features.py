#!/usr/bin/env python3
"""Extrai features de um arquivo PCAP e cria um CSV sem label.

O usuário deve rotular manualmente depois:
    0 = tráfego legítimo
    1 = tráfego malicioso

Dependência: scapy
    pip3 install scapy
"""

import argparse
import csv
import os
import sys
import time
from collections import defaultdict
from typing import Dict, List

try:
    from scapy.all import rdpcap, TCP, UDP, ICMP, IP
except ImportError:
    print("Erro: scapy não instalado. Execute: pip3 install scapy")
    sys.exit(1)

FEATURES = [
    "duration",
    "total_packets",
    "total_bytes",
    "packet_rate",
    "avg_interarrival_time",
    "syn_count",
    "ack_count",
    "rst_count",
    "fin_count",
    "unique_dst_ports",
    "connection_success_rate",
    "bytes_per_second",
    "label",  # vazio para o usuário rotular depois
]


def extrair_features_de_fluxo(packets_do_fluxo: List) -> Dict:
    """Extrai features de uma lista de pacotes que compõem um fluxo."""
    if not packets_do_fluxo:
        return None

    tempos = []
    syn_count = 0
    ack_count = 0
    rst_count = 0
    fin_count = 0
    dst_ports = set()
    total_bytes = 0
    conexoes_sucesso = 0
    conexoes_total = 0

    for pkt in packets_do_fluxo:
        if not pkt.haslayer(IP):
            continue

        # Tempo
        tempos.append(pkt.time)

        # TCP flags
        if pkt.haslayer(TCP):
            flags = pkt[TCP].flags
            if flags & 0x02:  # SYN
                syn_count += 1
            if flags & 0x10:  # ACK
                ack_count += 1
            if flags & 0x04:  # RST
                rst_count += 1
            if flags & 0x01:  # FIN
                fin_count += 1

            dst_ports.add(pkt[TCP].dport)

        # Bytes
        total_bytes += len(pkt)

    # Cálculos
    if not tempos:
        return None

    if len(tempos) > 1:
        duration = float(tempos[-1] - tempos[0])
        if duration == 0:
            duration = 0.001
    else:
        duration = 0.001

    total_packets = len(packets_do_fluxo)
    packet_rate = round(total_packets / duration, 4) if duration > 0 else 0

    # Intervalo entre pacotes
    interarrivals = []
    for i in range(1, len(tempos)):
        interarrivals.append(float(tempos[i] - tempos[i - 1]))
    avg_interarrival_time = round(sum(interarrivals) / len(interarrivals), 4) if interarrivals else 0

    # Taxa de sucesso de conexão (aproximada por ACK/SYN)
    connection_success_rate = round(ack_count / (syn_count + 1), 4)

    bytes_per_second = round(total_bytes / duration, 4) if duration > 0 else 0

    return {
        "duration": round(duration, 4),
        "total_packets": total_packets,
        "total_bytes": total_bytes,
        "packet_rate": packet_rate,
        "avg_interarrival_time": avg_interarrival_time,
        "syn_count": syn_count,
        "ack_count": ack_count,
        "rst_count": rst_count,
        "fin_count": fin_count,
        "unique_dst_ports": len(dst_ports),
        "connection_success_rate": connection_success_rate,
        "bytes_per_second": bytes_per_second,
        "label": "",  # vazio para o usuário rotular
    }


def extrair_do_pcap(pcap_path: str, output_path: str | None = None) -> None:
    """Lê um arquivo PCAP e extrai features por fluxo."""
    # Se output_path for None, gera um nome com timestamp
    if output_path is None:
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        pcap_nome = os.path.basename(pcap_path).replace('.pcap', '')
        output_path = f"datasets/{pcap_nome}_features_{timestamp}.csv"

    print(f"Lendo arquivo PCAP: {pcap_path}")

    try:
        packets = rdpcap(pcap_path)
    except FileNotFoundError:
        print(f"Erro: arquivo {pcap_path} não encontrado.")
        sys.exit(1)
    except Exception as e:
        print(f"Erro ao ler PCAP: {e}")
        sys.exit(1)

    print(f"Total de pacotes lidos: {len(packets)}")

    # Agrupar pacotes por fluxo bidirecional
    fluxos = defaultdict(list)
    for pkt in packets:
        if not pkt.haslayer(IP):
            continue

        src_ip = pkt[IP].src
        dst_ip = pkt[IP].dst

        # Identificar porta de origem e destino
        if pkt.haslayer(TCP):
            src_port = pkt[TCP].sport
            dst_port = pkt[TCP].dport
            protocolo = "TCP"
        elif pkt.haslayer(UDP):
            src_port = pkt[UDP].sport
            dst_port = pkt[UDP].dport
            protocolo = "UDP"
        elif pkt.haslayer(ICMP):
            src_port = 0
            dst_port = 0
            protocolo = "ICMP"
        else:
            continue

        # Chave do fluxo bidirecional: normalizar para parear ida e volta no mesmo fluxo
        ep1 = (src_ip, src_port)
        ep2 = (dst_ip, dst_port)
        if ep1 <= ep2:
            chave_fluxo = (src_ip, src_port, dst_ip, dst_port, protocolo)
        else:
            chave_fluxo = (dst_ip, dst_port, src_ip, src_port, protocolo)

        fluxos[chave_fluxo].append(pkt)

    print(f"Total de fluxos identificados: {len(fluxos)}")

    # Extrair features de cada fluxo
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    contador_fluxos = 0

    with open(output_path, "w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(FEATURES)

        for chave_fluxo, packets_do_fluxo in fluxos.items():
            features = extrair_features_de_fluxo(packets_do_fluxo)
            if features:
                linha = [features[feat] for feat in FEATURES]
                writer.writerow(linha)
                contador_fluxos += 1

    print(f"Fluxos processados com sucesso: {contador_fluxos}")
    print(f"CSV gerado em: {output_path}")
    print("\n⚠️  IMPORTANTE: Rotule manualmente o arquivo!")
    print("   - Abra o arquivo CSV")
    print("   - Na coluna 'label', preencha:")
    print("     0 = tráfego legítimo")
    print("     1 = tráfego malicioso")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extrai features de um arquivo PCAP e cria CSV sem label."
    )
    parser.add_argument("--pcap", required=True, help="Caminho do arquivo PCAP de entrada.")
    parser.add_argument(
        "--output",
        default=None,
        help="Caminho do arquivo CSV de saída. Se omitido, usa timestamp automaticamente.",
    )
    args = parser.parse_args()

    extrair_do_pcap(args.pcap, args.output)


if __name__ == "__main__":
    main()
