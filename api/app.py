import os
from datetime import datetime, timedelta, timezone
from flask import Flask, request, jsonify, send_from_directory
from werkzeug.utils import secure_filename

app = Flask(__name__)

UPLOAD_DIR = os.path.join(os.getcwd(), "images")
os.makedirs(UPLOAD_DIR, exist_ok=True)

IMAGE_URL_PREFIX = "/images"

# 한국 표준시 (UTC+9 고정)
KST = timezone(timedelta(hours=9), name="KST")

# 메모리 저장소 (for debug)
obstacles = []

@app.route("/api/upload-image", methods=["POST"])
def upload_image():
    if "file" not in request.files:
        return jsonify({
            "status": "error",
            "message": "file 필드(이미지)가 필요합니다."
        }), 400

    file = request.files["file"]

    if file.filename == "":
        return jsonify({
            "status": "error",
            "message": "파일 이름이 비어 있습니다."
        }), 400

    original_name = secure_filename(file.filename)

    now_kst = datetime.now(KST)
    timestamp_str = now_kst.strftime("%Y%m%dT%H%M%S%f%z")
    saved_name = f"{timestamp_str}_{original_name}"

    save_path = os.path.join(UPLOAD_DIR, saved_name)
    file.save(save_path)

    relative_path = f"{IMAGE_URL_PREFIX}/{saved_name}"

    return jsonify({
        "status": "ok",
        "message": "이미지 업로드 성공",
        "imagePath": relative_path,
        "uploadedAtKST": now_kst.isoformat()
    }), 200


@app.route(f"{IMAGE_URL_PREFIX}/<path:filename>", methods=["GET"])
def serve_image(filename):
    return send_from_directory(UPLOAD_DIR, filename)


@app.route("/api/obstacles", methods=["POST"])
def receive_obstacle():
    data = request.get_json(silent=True)

    # 요청 원본 바디 출력
    print("==== [DEBUG] Raw request JSON ====")
    print(data)
    print("=================================")

    if data is None:
        return jsonify({
            "status": "error",
            "message": "JSON 본문이 필요합니다."
        }), 400

    required_fields = ["userid", "obstacleName", "lat", "lon", "time", "image"]
    missing = [field for field in required_fields if field not in data]

    if missing:
        print(f"[DEBUG] missing fields: {missing}")
        return jsonify({
            "status": "error",
            "message": f"다음 필드가 누락되었습니다: {', '.join(missing)}"
        }), 400

    # lat/lon 변환 시도
    try:
        lat_val = float(data["lat"])
        lon_val = float(data["lon"])
    except (TypeError, ValueError):
        print("[DEBUG] lat/lon 변환 실패:", data.get("lat"), data.get("lon"))
        return jsonify({
            "status": "error",
            "message": "lat, lon은 숫자여야 합니다."
        }), 400

    # time 파싱 시도
    time_raw = data["time"]
    try:
        parsed_client_time = datetime.fromisoformat(time_raw.replace("Z", "+00:00"))
        time_parsed_ok = True
    except ValueError:
        parsed_client_time = None
        time_parsed_ok = False

    # 서버 시각 (KST)
    received_at_kst = datetime.now(KST)

    # 디버깅 정보 추가 출력
    print("==== [DEBUG] Parsed values ====")
    print("userid:", data["userid"])
    print("obstacleName:", data["obstacleName"])
    print("lat_val:", lat_val, "lon_val:", lon_val)
    print("client_time_raw:", time_raw)
    print("client_time_parsed_ok:", time_parsed_ok, "parsed_client_time:", parsed_client_time)
    print("server_received_at_kst:", received_at_kst.isoformat())
    print("image_path:", data["image"])
    print("=================================")

    entry = {
        "userid": data["userid"],
        "obstacleName": data["obstacleName"],
        "lat": lat_val,
        "lon": lon_val,
        "time": time_raw,
        "image": data["image"],
        "serverReceivedAt": received_at_kst.isoformat()
    }

    obstacles.append(entry)

    return jsonify({
        "status": "ok",
        "message": "장애물 정보 수신 완료",
        "data": entry,
        "timeParsedOk": time_parsed_ok
    }), 200


@app.route("/api/obstacles", methods=["GET"])
def list_obstacles():
    return jsonify({
        "count": len(obstacles),
        "items": obstacles
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
