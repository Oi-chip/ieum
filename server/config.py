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


# 공공데이터포털은 하나의 서비스키를 승인받은 여러 API에 공통으로 사용합니다.
# 기존 개발 환경이 바로 깨지지 않도록 예전 변수명도 임시로 지원합니다.
DATA_GO_KR_API_KEY = (
    os.getenv("DATA_GO_KR_API_KEY")
    or os.getenv("TAGO_API_KEY")
)
