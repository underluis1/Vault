import json
import os

DATA_DIR = os.path.expanduser("~/.local_vault")
DATA_FILE = os.path.join(DATA_DIR, "vault.json")


def load_vault() -> dict:
    if not os.path.exists(DATA_FILE):
        return {"entries": []}
    with open(DATA_FILE, "r") as f:
        return json.load(f)


def save_vault(data: dict):
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(DATA_FILE, "w") as f:
        json.dump(data, f, indent=2)
