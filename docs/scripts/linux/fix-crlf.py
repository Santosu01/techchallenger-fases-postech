#!/usr/bin/env python3
"""Converte scripts .sh de CRLF para LF (uso local/WSL)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
paths = [
    ROOT / "gitops/scripts/sync-configmap-from-aws.sh",
    ROOT / "docs/scripts/linux/bootstrap-epico3.sh",
    ROOT / "docs/scripts/linux/install-argocd.sh",
    ROOT / "docs/scripts/linux/update-aws-credentials.sh",
    ROOT / "docs/scripts/linux/push-all-ecr.sh",
]
for path in paths:
    data = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    path.write_bytes(data)
    print(f"fixed {path}")
