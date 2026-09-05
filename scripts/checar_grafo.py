#!/usr/bin/env python3
"""Verifica a integridade do grafo do vault Solar Brain.

Falha (exit 1) se houver wikilink apontando para nota inexistente.
Avisa (exit 0) sobre notas orfas — sem nenhuma conexao de entrada ou saida.

Uso:  python3 scripts/checar_grafo.py
"""
import re
import sys
from pathlib import Path

VAULT = Path(__file__).resolve().parent.parent / "Solar Brain"
LINK = re.compile(r"\[\[([^\]|#]+)")


def main() -> int:
    if not VAULT.is_dir():
        print(f"vault nao encontrado: {VAULT}")
        return 1

    notas = {p.stem: p for p in VAULT.rglob("*.md") if p.stem != "README"}
    hubs = {n for n, c in notas.items() if "tipo: hub" in c.read_text(encoding="utf-8")}
    saidas: dict[str, set[str]] = {}
    entradas: dict[str, set[str]] = {n: set() for n in notas}
    quebrados: list[tuple[str, str]] = []

    for nome, caminho in notas.items():
        alvos = {a.strip() for a in LINK.findall(caminho.read_text(encoding="utf-8"))}
        alvos.discard(nome)
        saidas[nome] = alvos
        for alvo in sorted(alvos):
            if alvo in notas:
                entradas[alvo].add(nome)
            else:
                quebrados.append((nome, alvo))

    orfas = sorted(n for n in notas if not saidas[n] and not entradas[n])
    arestas = sum(len(v) for v in saidas.values()) - len(quebrados)

    print(f"notas:    {len(notas)}")
    print(f"arestas:  {arestas}")
    print(f"quebrados:{len(quebrados)}")
    print(f"orfas:    {len(orfas)}")

    if quebrados:
        print("\nLinks quebrados:")
        for origem, alvo in quebrados:
            print(f"  {origem}  ->  [[{alvo}]]")
    if orfas:
        print("\nNotas orfas (nao aparecem conectadas no grafo):")
        for n in orfas:
            print(f"  {n}")

    sem_entrada = sorted(
        n for n in notas if not entradas[n] and n not in orfas and n not in hubs
    )
    if sem_entrada:
        print("\nSem backlink (ninguem aponta para elas):")
        for n in sem_entrada:
            print(f"  {n}")

    return 1 if quebrados else 0


if __name__ == "__main__":
    sys.exit(main())
