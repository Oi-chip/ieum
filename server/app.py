from flask import Flask, jsonify
from flask_cors import CORS

from routes.bus import bus_blueprint

# Flask 서버 객체를 만듭니다.
app = Flask(__name__)

# 브라우저에서도 한글 JSON이 그대로 보이도록 설정합니다.
app.json.ensure_ascii = False

# Flutter 앱이 서버에 요청할 수 있도록 허용합니다.
CORS(app)

# 버스 기능의 주소들을 Flask 앱에 등록합니다.
app.register_blueprint(bus_blueprint)


@app.get("/")
def home():
    return jsonify({
        "success": True,
        "message": "이음 서버에 접속했습니다."
    })

# 서버가 정상적으로 작동하는지 확인하는 주소입니다.
@app.get("/api/health")
def health_check():
    return jsonify(
        {
            "success": True,
            "message": "이음 서버가 정상적으로 실행 중입니다.",
        }
    )


# 앱의 메인 기능 목록을 보내주는 주소입니다.
@app.get("/api/services")
def get_services():
    return jsonify(
        {
            "success": True,
            "services": [
                {
                    "id": "bus",
                    "name": "버스 정보",
                },
                {
                    "id": "medical",
                    "name": "병원·약국",
                },
                {
                    "id": "village",
                    "name": "마을 소식",
                },
                {
                    "id": "weather",
                    "name": "날씨",
                },
            ],
        }
    )


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True,
    )
