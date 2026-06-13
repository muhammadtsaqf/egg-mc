#!/bin/bash
# ============================================================
#  Pterodactyl Egg - Minecraft Universal Entrypoint
#  Script startup yang dijalankan setiap kali server dimulai
# ============================================================

set -euo pipefail

# --- Warna untuk logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "${BLUE}[STEP]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# ============================================================
# VARIABEL DARI PTERODACTYL
# ============================================================
SERVER_TYPE="${SERVER_TYPE:-paper}"
MC_VERSION="${MC_VERSION:-latest}"
MAX_MEMORY="${MAX_MEMORY:-1024}"
MIN_MEMORY="${MIN_MEMORY:-512}"
JAVA_FLAGS="${JAVA_FLAGS:-}"
SERVER_PORT="${SERVER_PORT:-25565}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-120}"
SERVER_HOST="${SERVER_HOST:-}"
SERVER_MOTD="${SERVER_MOTD:-§a§lMinecraft Server §r§7| Powered by Pterodactyl}"
ONLINE_MODE="${ONLINE_MODE:-true}"
CF_TUNNEL_TOKEN="${CF_TUNNEL_TOKEN:-}"

# Normalisasi huruf kecil
SERVER_TYPE=$(echo "$SERVER_TYPE" | tr '[:upper:]' '[:lower:]')

# ============================================================
# BANNER
# ============================================================
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║     🎮 Pterodactyl Minecraft Universal Egg        ║"
echo "  ║        Powered by Antigravity Egg Project         ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Server Type${NC} : ${GREEN}$SERVER_TYPE${NC}"
echo -e "  ${BOLD}MC Version  ${NC} : ${GREEN}$MC_VERSION${NC}"
echo -e "  ${BOLD}Memori      ${NC} : ${GREEN}${MIN_MEMORY}M - ${MAX_MEMORY}M${NC}"
echo -e "  ${BOLD}Port        ${NC} : ${GREEN}$SERVER_PORT${NC}"
if [ -n "$SERVER_HOST" ]; then
echo -e "  ${BOLD}Host/Domain ${NC} : ${CYAN}$SERVER_HOST:$SERVER_PORT${NC}"
fi
echo -e "  ${BOLD}Online Mode ${NC} : ${GREEN}$ONLINE_MODE${NC}"
if [ -n "$CF_TUNNEL_TOKEN" ]; then
echo -e "  ${BOLD}CF Tunnel   ${NC} : ${CYAN}✅ Aktif${NC}"
else
echo -e "  ${BOLD}CF Tunnel   ${NC} : ${YELLOW}Tidak aktif${NC}"
fi
echo ""

# ============================================================
# CLOUDFLARE TUNNEL
# ============================================================
start_cloudflare_tunnel() {
    if [ -z "$CF_TUNNEL_TOKEN" ]; then
        return 0
    fi

    if ! command -v cloudflared &>/dev/null; then
        warn "cloudflared tidak ditemukan, CF Tunnel dilewati"
        return 0
    fi

    step "Memulai Cloudflare Tunnel..."
    log "Menghubungkan ke Cloudflare Network..."

    # Jalankan cloudflared di background
    cloudflared tunnel --no-autoupdate run --token "$CF_TUNNEL_TOKEN" \
        > /tmp/cloudflared.log 2>&1 &

    local cf_pid=$!
    echo "$cf_pid" > /tmp/cloudflared.pid

    # Tunggu koneksi terbentuk (max 15 detik)
    local retries=0
    while [ $retries -lt 15 ]; do
        if grep -q "Connection .* registered" /tmp/cloudflared.log 2>/dev/null || \
           grep -q "Registered tunnel connection" /tmp/cloudflared.log 2>/dev/null || \
           grep -q "conns=1" /tmp/cloudflared.log 2>/dev/null; then
            success "Cloudflare Tunnel berhasil terhubung!"
            if [ -n "$SERVER_HOST" ]; then
                log "Player bisa connect di: ${CYAN}${SERVER_HOST}${NC}"
            fi
            return 0
        fi
        sleep 1
        retries=$((retries + 1))
    done

    # Cek apakah proses masih berjalan
    if kill -0 "$cf_pid" 2>/dev/null; then
        warn "Cloudflare Tunnel berjalan (koneksi masih dalam proses)"
    else
        warn "Cloudflare Tunnel gagal start. Cek token kamu."
        warn "Log: $(cat /tmp/cloudflared.log | tail -5)"
    fi
}

# ============================================================
# APPLY KONFIGURASI KE server.properties
# ============================================================
apply_server_config() {
    # Skip untuk server proxy
    case "$SERVER_TYPE" in
        bungeecord|bungee|waterfall|velocity)
            return 0
            ;;
    esac

    [ ! -f server.properties ] && return 0

    log "Mengaplikasikan konfigurasi ke server.properties..."

    # Fungsi helper untuk set property dengan aman (tanpa sed delimiter conflict)
    set_property() {
        local key="$1"
        local value="$2"
        if grep -q "^${key}=" server.properties 2>/dev/null; then
            # Hapus baris konfigurasi yang lama
            grep -v "^${key}=" server.properties > server.properties.tmp
            mv server.properties.tmp server.properties
        fi
        # Tambahkan nilai baru di akhir file
        echo "${key}=${value}" >> server.properties
    }

    # Set port
    set_property "server-port" "$SERVER_PORT"

    # Set online mode
    set_property "online-mode" "$ONLINE_MODE"

    # Set MotD
    if [ -n "$SERVER_MOTD" ]; then
        set_property "motd" "$SERVER_MOTD"
    fi

    # Jika domain diset, tampilkan info koneksi
    if [ -n "$SERVER_HOST" ]; then
        log "Server bisa diakses di: ${CYAN}${SERVER_HOST}:${SERVER_PORT}${NC}"
        # Tambahkan komentar info di server.properties
        if grep -q "^# Host:" server.properties 2>/dev/null; then
            grep -v "^# Host:" server.properties > server.properties.tmp
            mv server.properties.tmp server.properties
        fi
        # Taruh di paling atas file
        echo "# Host: ${SERVER_HOST}:${SERVER_PORT}" | cat - server.properties > temp && mv temp server.properties
    fi

    success "server.properties berhasil diupdate"
}

# ============================================================
# CLOUDFLARE TUNNEL
# ============================================================
start_cloudflare_tunnel() {
    if command -v cloudflared &>/dev/null; then
        if [ -n "${CF_WEB_TUNNEL_TOKEN:-}" ]; then
            log "Menjalankan Cloudflare Tunnel (Web Panel) di background..."
            cloudflared tunnel run --token "$CF_WEB_TUNNEL_TOKEN" > /home/container/logs/cloudflared-web.log 2>&1 &
        fi
    else
        if [ -n "${CF_WEB_TUNNEL_TOKEN:-}" ]; then
            warn "Token Cloudflare terdeteksi, tetapi binary 'cloudflared' tidak ditemukan di dalam sistem!"
        fi
    fi
}

# ============================================================
# DETEKSI JAVA VERSION YANG TEPAT
# ============================================================
select_java() {
    # Deteksi versi Java berdasarkan versi Minecraft
    local major_version=0

    # Extract major version number dari MC_VERSION (e.g., 1.21.4 -> 21)
    if [[ "$MC_VERSION" =~ ^1\.([0-9]+) ]]; then
        major_version="${BASH_REMATCH[1]}"
    elif [[ "${MC_VERSION,,}" == "latest" ]]; then
        # Jika versi "latest", gunakan versi major tertinggi yang saat ini tersedia (MC 1.22+ butuh Java 25)
        major_version=25
    fi

    local java_cmd="java"

    # Java requirements per versi MC:
    # MC 1.17+ butuh Java 16+
    # MC 1.18+ butuh Java 17+
    # MC 1.20.5+ butuh Java 21+
    # MC 1.22+ butuh Java 25+
    if [ "$major_version" -ge 25 ] 2>/dev/null; then
        # MC 1.22+ / Latest - Java 25
        if command -v /opt/java/25/bin/java &>/dev/null; then
            java_cmd="/opt/java/25/bin/java"
        fi
        log "Menggunakan Java 25 (MC 1.22+ / latest)" >&2
    elif [ "$major_version" -ge 21 ] 2>/dev/null; then
        # MC 1.21+ - Java 21
        if command -v /usr/lib/jvm/java-21-openjdk-amd64/bin/java &>/dev/null; then
            java_cmd="/usr/lib/jvm/java-21-openjdk-amd64/bin/java"
        elif command -v /opt/java/21/bin/java &>/dev/null; then
            java_cmd="/opt/java/21/bin/java"
        fi
        log "Menggunakan Java 21 (MC 1.21+)" >&2
    elif [ "$major_version" -ge 18 ] 2>/dev/null; then
        # MC 1.18-1.20.4 - Java 17
        if command -v /usr/lib/jvm/java-17-openjdk-amd64/bin/java &>/dev/null; then
            java_cmd="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
        elif command -v /opt/java/17/bin/java &>/dev/null; then
            java_cmd="/opt/java/17/bin/java"
        fi
        log "Menggunakan Java 17 (MC 1.18-1.20.4)" >&2
    elif [ "$major_version" -ge 17 ] 2>/dev/null; then
        # MC 1.17 - Java 16+
        log "Menggunakan Java default (MC 1.17)" >&2
    else
        # MC 1.16 ke bawah - Java 8/11
        if command -v /usr/lib/jvm/java-11-openjdk-amd64/bin/java &>/dev/null; then
            java_cmd="/usr/lib/jvm/java-11-openjdk-amd64/bin/java"
        elif command -v /opt/java/11/bin/java &>/dev/null; then
            java_cmd="/opt/java/11/bin/java"
        fi
        log "Menggunakan Java 11 (MC 1.16 ke bawah)" >&2
    fi

    echo "$java_cmd"
}

# ============================================================
# GENERATE AIKAR'S FLAGS (JVM Optimization)
# ============================================================
get_java_flags() {
    local mem="$1"
    local server_type="$2"

    # Aikar's Flags - Optimal untuk Minecraft server
    local aikar_flags=(
        "-XX:+UseG1GC"
        "-XX:+ParallelRefProcEnabled"
        "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions"
        "-XX:+DisableExplicitGC"
        "-XX:+AlwaysPreTouch"
        "-XX:G1NewSizePercent=30"
        "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M"
        "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5"
        "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15"
        "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5"
        "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem"
        "-XX:MaxTenuringThreshold=1"
        "-Dusing.aikars.flags=https://mcflags.emc.gs"
        "-Daikars.new.flags=true"
    )

    # Tambahan untuk RAM >= 12GB
    if [ "$mem" -ge 12288 ]; then
        aikar_flags+=("-XX:G1NewSizePercent=40" "-XX:G1MaxNewSizePercent=50" "-XX:G1HeapRegionSize=16M" "-XX:G1ReservePercent=15" "-XX:InitiatingHeapOccupancyPercent=20")
    fi

    echo "${aikar_flags[*]}"
}

# ============================================================
# CEK DAN BUAT EULA
# ============================================================
ensure_eula() {
    case "$SERVER_TYPE" in
        bungeecord|bungee|waterfall|velocity)
            return 0
            ;;
    esac

    if [ ! -f eula.txt ] || ! grep -q "eula=true" eula.txt 2>/dev/null; then
        log "Membuat eula.txt..."
        echo "eula=true" > eula.txt
    fi
}

# ============================================================
# CEK SERVER JAR
# ============================================================
check_server_jar() {
    if [ ! -f server.jar ]; then
        warn "server.jar tidak ditemukan!"
        warn "Pastikan proses instalasi sudah berjalan."
        warn "Menjalankan ulang installer..."

        # Jalankan installer jika tersedia
        if [ -f /mnt/user-data/volumes/install.sh ]; then
            bash /mnt/user-data/volumes/install.sh
        elif [ -f /install.sh ]; then
            bash /install.sh
        else
            error "Tidak bisa menemukan install.sh. Reinstall server dari panel Pterodactyl!"
        fi
    fi

    log "Server JAR ditemukan: server.jar ($(du -sh server.jar | cut -f1))"
}

# ============================================================
# STARTUP KHUSUS FORGE (Modern 1.17+)
# ============================================================
start_forge() {
    local java_cmd="$1"
    shift
    local jvm_args=("$@")

    if [ -f "run.sh" ]; then
        log "Mendeteksi Forge modern (run.sh), menjalankan via run.sh..."
        # Modifikasi run.sh untuk menyertakan memori custom
        export JAVA_TOOL_OPTIONS="${jvm_args[*]}"
        exec bash run.sh nogui
    elif [ -f "forge-server-launcher.jar" ]; then
        exec "$java_cmd" "${jvm_args[@]}" -jar forge-server-launcher.jar nogui
    else
        exec "$java_cmd" "${jvm_args[@]}" -jar server.jar nogui
    fi
}

# ============================================================
# MAIN STARTUP
# ============================================================
main() {
    step "Mempersiapkan server..."

    # Pastikan kita di direktori yang benar
    cd /home/container

    # Cek server.jar
    check_server_jar

    # Pastikan EULA ada
    ensure_eula

    # Apply konfigurasi server (host, port, motd, online-mode)
    apply_server_config

    # Mulai Cloudflare Tunnel jika token tersedia
    start_cloudflare_tunnel

    # Mulai Web Panel Frontend jika diaktifkan
    if [ "${WEB_PANEL_ENABLED,,}" == "true" ]; then
        log "Mempersiapkan Web Frontend (Node.js)..."
        
        # Pindahkan web folder ke /home/container/web agar pengguna bisa mengedit HTML/CSS
        if [ ! -d "/home/container/web" ]; then
            log "Mengcopy default web panel ke /home/container/web..."
            cp -r /opt/minecraft-web /home/container/web
            # Pastikan permission benar
            chown -R container:container /home/container/web 2>/dev/null || true
        fi

        log "Memulai Web Panel di background..."
        # Export semua variable penting agar terbaca oleh Node.js
        export SERVER_PORT="${SERVER_PORT:-25565}"
        export SERVER_HOST="${SERVER_HOST:-127.0.0.1}"
        export MC_VERSION="${MC_VERSION:-latest}"
        export SERVER_TYPE="${SERVER_TYPE:-vanilla}"
        export SERVER_MOTD="${SERVER_MOTD:-Minecraft Server}"
        export WEB_ADMIN_USERNAME="${WEB_ADMIN_USERNAME:-admin}"
        export WEB_ADMIN_PASSWORD="${WEB_ADMIN_PASSWORD:-admin123}"
        
        # Jika .env belum ada, copy dari template
        if [ ! -f "/home/container/web/.env" ] && [ -f "/opt/minecraft-web/.env" ]; then
            cp /opt/minecraft-web/.env /home/container/web/.env
        fi
        
        # Pindah ke direktori web PENGGUNA, jalankan npm start di background, lalu kembali
        (cd /home/container/web && npm start > /dev/null 2>&1 &)
    fi

    # Pilih Java yang tepat
    JAVA_CMD=$(select_java)

    # Cek versi Java yang akan dipakai
    JAVA_VER=$("$JAVA_CMD" -version 2>&1 | head -1)
    log "Java: $JAVA_VER"

    # Susun JVM arguments
    local auto_flags
    auto_flags=$(get_java_flags "$MAX_MEMORY" "$SERVER_TYPE")

    # Gunakan custom flags jika ada, kalau tidak pakai Aikar's flags
    local jvm_flags
    if [ -n "$JAVA_FLAGS" ]; then
        jvm_flags="$JAVA_FLAGS"
        log "Menggunakan custom Java flags"
    else
        jvm_flags="$auto_flags"
        log "Menggunakan Aikar's optimized flags"
    fi

    # Susun argumen lengkap
    local jvm_args=(
        "-Xms${MIN_MEMORY}M"
        "-Xmx${MAX_MEMORY}M"
        $jvm_flags
    )

    # Log argumen startup
    echo ""
    echo -e "  ${BOLD}Command startup:${NC}"
    echo -e "  ${CYAN}$JAVA_CMD ${jvm_args[*]} -jar server.jar nogui${NC}"
    echo ""

    step "Menjalankan server ${SERVER_TYPE}..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Jalankan server berdasarkan tipe
    case "$SERVER_TYPE" in
        forge)
            start_forge "$JAVA_CMD" "${jvm_args[@]}"
            ;;
        bungeecord|bungee|waterfall|velocity)
            # Proxy server - tanpa nogui flag yang sama
            exec "$JAVA_CMD" "${jvm_args[@]}" -jar server.jar
            ;;
        quilt)
            # Quilt launcher khusus
            if [ -f "quilt-server-launch.jar" ]; then
                exec "$JAVA_CMD" "${jvm_args[@]}" -jar quilt-server-launch.jar nogui
            else
                exec "$JAVA_CMD" "${jvm_args[@]}" -jar server.jar nogui
            fi
            ;;
        *)
            # Vanilla, Paper, Spigot, Fabric, Purpur
            exec "$JAVA_CMD" "${jvm_args[@]}" -jar server.jar nogui
            ;;
    esac
}

main
