import json
import os
from pathlib import Path

from dotenv import load_dotenv


# config.py가 들어 있는 server 폴더
SERVER_DIR = Path(__file__).resolve().parent

# ieum 프로젝트 최상위 폴더
PROJECT_DIR = SERVER_DIR.parent

# server/.env 파일을 불러옵니다.
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