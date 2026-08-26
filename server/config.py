import json
import os
from pathlib import Path

from dotenv import load_dotenv

SERVER_DIR = Path(__file__).resolve().parent

PROJECT_DIR = SERVER_DIR.parent

load_dotenv(SERVER_DIR / ".env")

def load_region():
    region_path = (
        PROJECT_DIR
        / "region_data"
        / "Bonghwa"
        / "region.json"
    )

    with region_path.open(encoding="utf-8") as file:
        return json.load(file)

data_go_API_KEY = os.getenv("data_go_API_KEY")
DATA_GO_API_KEY = data_go_API_KEY
