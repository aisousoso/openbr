# OpenBR dedicated server — Docker image
# Build: docker build -t openbr-server -f server/Dockerfile .
# Run:   docker run -p 7777:7777/udp openbr-server -- --dev-auth --port=7777

FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download Godot 4.4.1 headless binary
ARG GODOT_VERSION=4.4.1
RUN wget -q -O /tmp/godot.zip \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp/godot-bin \
    && mv "/tmp/godot-bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -rf /tmp/godot.zip /tmp/godot-bin

# Copy project
WORKDIR /app
COPY . /app

# Expose game port (UDP)
EXPOSE 7777/udp

ENTRYPOINT ["godot", "--headless", "--path", "/app", "res://server/main.tscn", "--"]
CMD ["--port=7777", "--dev-auth"]