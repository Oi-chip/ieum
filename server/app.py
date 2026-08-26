from flask import Flask, jsonify
from flask_cors import CORS

if __package__:
    from .routes.bus import bus_blueprint
    from .routes.hospital import hospital_blueprint
    from .routes.weather import weather_blueprint
else:
    from routes.bus import bus_blueprint
    from routes.hospital import hospital_blueprint
    from routes.weather import weather_blueprint

app = Flask(__name__)

app.json.ensure_ascii = False

CORS(app)

app.register_blueprint(bus_blueprint)
app.register_blueprint(hospital_blueprint)
app.register_blueprint(weather_blueprint)

@app.get("/")
def home():
    return jsonify({
        "success": True,
        "message": "이음 서버에 접속했습니다."
    })

@app.get("/api/health")
def health_check():
    return jsonify(
        {
            "success": True,
            "message": "이음 서버가 정상적으로 실행 중입니다.",
        }
    )

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
