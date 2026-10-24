package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"
)

var (
	secret  []byte
	servers []string
	rr      uint64
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func init() {
	secret = []byte(env("BR_SECRET", "dev-secret-change-me"))
	for _, s := range strings.Split(env("GAME_SERVERS", "127.0.0.1:7777"), ",") {
		if s = strings.TrimSpace(s); s != "" {
			servers = append(servers, s)
		}
	}
	if len(servers) == 0 {
		servers = []string{"127.0.0.1:7777"}
	}
}

type matchRequest struct {
	PlayerID string `json:"player_id"`
	Region   string `json:"region"`
}

type matchResponse struct {
	Server string `json:"server"`
	Token  string `json:"token"`
	Exp    int64  `json:"exp"`
}

// sign returns hex(payload) + "." + hex(HMAC-SHA256(payload)).
// The Godot server verifies exactly this format in server/auth.gd.
func sign(payload []byte) string {
	mac := hmac.New(sha256.New, secret)
	mac.Write(payload)
	return hex.EncodeToString(payload) + "." + hex.EncodeToString(mac.Sum(nil))
}

func handleMatch(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		http.Error(w, "POST only", http.StatusMethodNotAllowed)
		return
	}

	var req matchRequest
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.PlayerID == "" {
		req.PlayerID = "anon"
	}

	exp := time.Now().Add(5 * time.Minute).Unix()
	payload, err := json.Marshal(map[string]any{
		"sub":    req.PlayerID,
		"region": req.Region,
		"exp":    exp,
	})
	if err != nil {
		http.Error(w, "encode error", http.StatusInternalServerError)
		return
	}

	i := atomic.AddUint64(&rr, 1)
	resp := matchResponse{
		Server: servers[int(i)%len(servers)],
		Token:  sign(payload),
		Exp:    exp,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/v1/match", handleMatch)
	mux.HandleFunc("/healthz", handleHealth)

	addr := env("LISTEN_ADDR", ":8080")
	log.Printf("matchmaker listening on %s (servers=%v)", addr, servers)
	log.Fatal(http.ListenAndServe(addr, mux))
}
