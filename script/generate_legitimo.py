#!/usr/bin/env python3
"""Gera um dataset sintético de tráfego legítimo para o IDS.

Formato de saída:
    duration,total_packets,total_bytes,packet_rate,avg_interarrival_time,syn_count,
    ack_count,rst_count,fin_count,unique_dst_ports,connection_success_rate,bytes_per_second,label

Label:
    0 = tráfego legítimo
"""

import argparse
import csv
import os
import random
import signal
import sys
import time
from typing import List

FEATURES: List[str] = [
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
    "label",
]


def gerar_fluxo_legitimo(rng: random.Random) -> List[float]:
    duration = round(rng.uniform(0.5, 25.0), 4)
    total_packets = rng.randint(10, 500)
    total_bytes = rng.randint(500, 120000)
    packet_rate = round(rng.uniform(0.8, 40.0), 4)
    avg_interarrival_time = round(rng.uniform(0.01, 0.7), 4)
    syn_count = rng.randint(0, 12)
    ack_count = rng.randint(5, 180)
    rst_count = rng.randint(0, 12)
    fin_count = rng.randint(3, 120)
    unique_dst_ports = rng.randint(1, 10)
    connection_success_rate = round(rng.uniform(0.7, 1.0), 4)
    bytes_per_second = round(rng.uniform(50.0, 5000.0), 4)

    return [
        duration,
        total_packets,
        total_bytes,
        packet_rate,
        avg_interarrival_time,
        syn_count,
        ack_count,
        rst_count,
        fin_count,
        unique_dst_ports,
        connection_success_rate,
        bytes_per_second,
        0,
    ]


def gerar_dataset(output_path: str, seed: int = 42, intervalo_segundos: float = 0.5, max_registros: int | None = None) -> str:
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    rng = random.Random(seed)
    contador = 0

    with open(output_path, "w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(FEATURES)

        print(f"Gerando tráfego legítimo até você interromper manualmente. Arquivo: {output_path}")

        def encerrar_sinal(sig, frame):
            print("\nInterrupção recebida. Encerrando geração do dataset legítimo.")
            raise KeyboardInterrupt

        signal.signal(signal.SIGINT, encerrar_sinal)
        signal.signal(signal.SIGTERM, encerrar_sinal)

        try:
            while True:
                if max_registros is not None and contador >= max_registros:
                    break
                writer.writerow(gerar_fluxo_legitimo(rng))
                contador += 1
                time.sleep(intervalo_segundos)
        except KeyboardInterrupt:
            pass

    print(f"Dataset legítimo finalizado. Registros gerados: {contador}")
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Gera dataset contínuo de tráfego legítimo até você encerrar manualmente.")
    parser.add_argument("--output", default="datasets/trafego_legitimo.csv", help="Caminho do CSV gerado.")
    parser.add_argument("--intervalo-segundos", type=float, default=0.5, help="Tempo entre registros gerados em segundos.")
    parser.add_argument("--max-registros", type=int, default=None, help="Opcional: limite máximo de registros. Se omitido, o script roda até ser interrompido manualmente.")
    parser.add_argument("--seed", type=int, default=42, help="Semente aleatória.")
    args = parser.parse_args()

    gerar_dataset(args.output, args.seed, args.intervalo_segundos, args.max_registros)


if __name__ == "__main__":
    main()
