#!/usr/bin/env python3
"""Combina os datasets legítimo e malicioso em um único CSV final.

Uso:
    python script/merge_datasets.py --legitimo datasets/trafego_legitimo.csv --malicioso datasets/trafego_malicioso.csv --saida datasets/dataset_completo.csv
"""

import argparse
import csv
from pathlib import Path


def ler_csv(caminho: str):
    with open(caminho, "r", newline="", encoding="utf-8") as arquivo:
        return list(csv.reader(arquivo))


def combinar(arquivo_legitimo: str, arquivo_malicioso: str, saida: str) -> str:
    linhas_legitimas = ler_csv(arquivo_legitimo)
    linhas_maliciosas = ler_csv(arquivo_malicioso)

    if len(linhas_legitimas) < 2 or len(linhas_maliciosas) < 2:
        raise ValueError("Os arquivos de entrada devem conter cabeçalho e pelo menos uma linha de dados.")

    cabecalho = linhas_legitimas[0]
    dados = linhas_legitimas[1:] + linhas_maliciosas[1:]

    pasta_saida = Path(saida).parent
    pasta_saida.mkdir(parents=True, exist_ok=True)

    with open(saida, "w", newline="", encoding="utf-8") as arquivo:
        writer = csv.writer(arquivo)
        writer.writerow(cabecalho)
        writer.writerows(dados)

    return saida


def main() -> None:
    parser = argparse.ArgumentParser(description="Mescla dataset legítimo e malicioso em um único CSV.")
    parser.add_argument("--legitimo", required=True, help="Caminho do CSV legítimo.")
    parser.add_argument("--malicioso", required=True, help="Caminho do CSV malicioso.")
    parser.add_argument("--saida", required=True, help="Nome do CSV final combinado.")
    args = parser.parse_args()

    caminho_final = combinar(args.legitimo, args.malicioso, args.saida)
    print(f"Dataset combinado salvo em: {caminho_final}")


if __name__ == "__main__":
    main()
