"""OpenBR Matchmaker — simple HTTP service.

Endpoints:
  POST /queue          — join matchmaking queue
  GET  /status/<id>    — check queue status
  GET  /servers        — list registered game servers
  POST /register       — register a game server
  GET  /health         — health check

Environment:
  BR_SECRET: shared secret for auth
  GAME_SERVERS: comma-separated host:port list
"""

import json
import os
import time
import uuid
from flask import Flask, request, jsonify

app = Flask(__name__)

BR_SECRET = os.environ.get("BR_SECRET", "dev-secret-change-me")
GAME_SERVERS = [s.strip() for s in os.environ.get("GAME_SERVERS", "localhost:7777").split(",") if s.strip()]

# In-memory state (use Redis/DB in production)
queue = []  # list of {id, region, skill, timestamp}
servers = {}  # server_id -> {host, port, players, max_players, region}


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "servers": len(servers), "queue": len(queue)})


@app.route("/register", methods=["POST"])
def register_server():
    data = request.get_json() or {}
    if data.get("secret") != BR_SECRET:
        return jsonify({"error": "unauthorized"}), 403
    sid = data.get("id", str(uuid.uuid4()))
    servers[sid] = {
        "host": data.get("host", "localhost"),
        "port": data.get("port", 7777),
        "players": data.get("players", 0),
        "max_players": data.get("max_players", 128),
        "region": data.get("region", "default"),
        "last_heartbeat": time.time(),
    }
    return jsonify({"id": sid, "status": "registered"})


@app.route("/servers", methods=["GET"])
def list_servers():
    # Remove stale servers (no heartbeat in 30s)
    now = time.time()
    stale = [sid for sid, s in servers.items() if now - s["last_heartbeat"] > 30]
    for sid in stale:
        del servers[sid]
    return jsonify({"servers": list(servers.values())})


@app.route("/queue", methods=["POST"])
def join_queue():
    data = request.get_json() or {}
    player_id = data.get("player_id", str(uuid.uuid4()))
    region = data.get("region", "default")
    skill = data.get("skill", 1000)

    entry = {
        "id": player_id,
        "region": region,
        "skill": skill,
        "timestamp": time.time(),
    }
    queue.append(entry)
    return jsonify({"player_id": player_id, "status": "queued", "position": len(queue)})


@app.route("/status/<player_id>", methods=["GET"])
def queue_status(player_id):
    # Find player in queue
    for i, entry in enumerate(queue):
        if entry["id"] == player_id:
            # Try to match with a server
            for sid, server in servers.items():
                if server["players"] < server["max_players"] and server["region"] == entry["region"]:
                    queue.pop(i)
                    return jsonify({
                        "status": "matched",
                        "server": server,
                        "token": BR_SECRET,
                    })
            return jsonify({"status": "waiting", "position": i + 1})

    return jsonify({"status": "not_found"}), 404


@app.route("/match_result", methods=["POST"])
def match_result():
    data = request.get_json() or {}
    # Record match result for ELO/analytics
    print(f"Match result: {json.dumps(data)}")
    return jsonify({"status": "recorded"})


if __name__ == "__main__":
    # Seed servers from env
    for s in GAME_SERVERS:
        if ":" in s:
            host, port = s.rsplit(":", 1)
            servers[f"env-{host}"] = {
                "host": host,
                "port": int(port),
                "players": 0,
                "max_players": 128,
                "region": "default",
                "last_heartbeat": time.time(),
            }
    print(f"Matchmaker starting on :8080 (servers: {GAME_SERVERS})")
    app.run(host="0.0.0.0", port=8080)