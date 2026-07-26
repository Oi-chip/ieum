import json
import os
from dotenv import load_dotenv

load_dotenv()

def load_region(region_id="bonghwa"):
    path = f"../region_data/Bonghwa/region.json"
    with open(path, encoding="utf-8") as f:
        return json.load(f)

TAGO_API_KEY = os.getenv("TAGO_API_KEY")
HOSPITAL_API_KEY = os.getenv("HOSPITAL_API_KEY")
WEATHER_API_KEY = os.getenv("WEATHER_API_KEY")