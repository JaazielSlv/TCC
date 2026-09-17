#!/usr/bin/env python3
"""Combina dois CSVs rotulados (legítimo e malicioso) em um único dataset final.

Uso:
    python script/merge_labeled_datasets.py \\
        --legitimo datasets/trafego_legitimo_rotulado.csv \\
        --malicioso datasets/trafego_malicioso_rotulado.csv \\
        --saida datasets/dataset_completo.csv
"""

import argparse
import csv
from pathlib import Path


from typing import List, Union


def ler_csv(caminho: str) -> List[List[str]]:
    with open(caminho, "r", newline="", encoding="utf-8") as arquivo:
        return list(csv.reader(arquivo))


def combinar(entradas_legitimas: Union[str, List[str]], entradas_maliciosas: Union[str, List[str]], saida: str) -> str:
    files_legit = [entradas_legitimas] if isinstance(entradas_legitimas, str) else entradas_legitimas
    files_malic = [entradas_maliciosas] if isinstance(entradas_maliciosas, str) else entradas_maliciosas

    linhas_legitimas: List[List[str]] = []
    linhas_maliciosas: List[List[str]] = []
    cabecalho = None

    for f in files_legit:
        conteudo = ler_csv(f)
        if conteudo:
            if cabecalho is None:
                cabecalho = conteudo[0]
            linhas_legitimas.extend(conteudo[1:])

    for f in files_malic:
        conteudo = ler_csv(f)
        if conteudo:
            if cabecalho is None:
                cabecalho = conteudo[0]
            linhas_maliciosas.extend(conteudo[1:])

    if not cabecalho or (not linhas_legitimas and not linhas_maliciosas):
        raise ValueError("Os arquivos de entrada devem conter cabeçalho e dados.")

    # Verificar se tem coluna label
    if "label" not in cabecalho:
        print("Aviso: coluna 'label' não encontrada no cabeçalho.")

    dados = linhas_legitimas + linhas_maliciosas

    pasta_saida = Path(saida).parent
    pasta_saida.mkdir(parents=True, exist_ok=True)

    with open(saida, "w", newline="", encoding="utf-8") as arquivo:
        writer = csv.writer(arquivo)
        writer.writerow(cabecalho)
        writer.writerows(dados)

    return saida


def main() -> None:
    parser = argparse.ArgumentParser(description="Mescla datasets legítimo e malicioso rotulados em um único CSV.")
    parser.add_argument("--legitimo", nargs="+", required=True, help="Caminho do CSV ou CSVs legítimos (rotulados com 0).")
    parser.add_argument("--malicioso", nargs="+", required=True, help="Caminho do CSV ou CSVs maliciosos (rotulados com 1).")
    parser.add_argument("--saida", required=True, help="Nome do CSV final combinado.")
    args = parser.parse_args()

    caminho_final = combinar(args.legitimo, args.malicioso, args.saida)
    print(f"Dataset combinado salvo em: {caminho_final}")


if __name__ == "__main__":
    main()
