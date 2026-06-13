#!/bin/bash
# ============================================================
#  Pterodactyl Egg - Minecraft Universal Installer
#  Mendukung: Vanilla, Paper, Spigot, Forge, Fabric,
#             Quilt, Purpur, BungeeCord, Waterfall, Velocity
# ============================================================

set -euo pipefail

# --- Warna untuk logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log()     { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()    { echo -e "${BLUE}[STEP]${NC} $1"; }
success() { echo -e "${CYAN}[OK]${NC} $1"; }

# --- Variabel lingkungan dari Pterodactyl ---
SERVER_TYPE="${SERVER_TYPE:-paper}"
MC_VERSION="${MC_VERSION:-latest}"
BUILD_NUMBER="${BUILD_NUMBER:-latest}"
FORGE_VERSION="${FORGE_VERSION:-latest}"
FABRIC_VERSION="${FABRIC_VERSION:-latest}"
QUILT_VERSION="${QUILT_VERSION:-latest}"

# Normalisasi huruf kecil
SERVER_TYPE=$(echo "$SERVER_TYPE" | tr '[:upper:]' '[:lower:]')

echo ""
echo "============================================================"
echo "   Pterodactyl Egg - Minecraft Universal Installer"
echo "============================================================"
echo "  Server Type : $SERVER_TYPE"
echo "  MC Version  : $MC_VERSION"
echo "============================================================"
echo ""

# ============================================================
# FUNGSI UTILITY
# ============================================================

install_dependencies() {
    # Dependensi sudah diinstal langsung di dalam Docker image
    # Fungsi ini dibiarkan kosong agar tidak memunculkan pesan error "Read-only file system"
    :
}

get_latest_minecraft_version() {
    local manifest
    manifest=$(curl -sSL "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json")
    echo "$manifest" | jq -r '.latest.release'
}

resolve_mc_version() {
    if [ "$MC_VERSION" = "latest" ]; then
        if [ "$SERVER_TYPE" = "paper" ]; then
            MC_VERSION=$(curl -sSL "https://api.papermc.io/v2/projects/paper" 2>/dev/null | jq -r '.versions[-1]')
        elif [ "$SERVER_TYPE" = "purpur" ]; then
            MC_VERSION=$(curl -sSL "https://api.purpurmc.org/v2/purpur" 2>/dev/null | jq -r '.versions[-1]')
        elif [ "$SERVER_TYPE" = "waterfall" ]; then
            MC_VERSION=$(curl -sSL "https://api.papermc.io/v2/projects/waterfall" 2>/dev/null | jq -r '.versions[-1]')
        elif [ "$SERVER_TYPE" = "velocity" ]; then
            MC_VERSION=$(curl -sSL "https://api.papermc.io/v2/projects/velocity" 2>/dev/null | jq -r '.versions[-1]')
        else
            MC_VERSION=$(get_latest_minecraft_version)
        fi
        log "Versi terbaru yang tersedia untuk $SERVER_TYPE: $MC_VERSION"
    fi
}

check_java() {
    if ! command -v java &>/dev/null; then
        warn "Java tidak ditemukan! Pastikan image Docker sudah menyertakan Java."
    else
        JAVA_VERSION=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}')
        log "Java versi: $JAVA_VERSION"
    fi
}

write_eula() {
    echo "eula=true" > eula.txt
    success "EULA diterima (eula.txt dibuat)"
}

write_server_properties() {
    if [ ! -f server.properties ]; then
        cat > server.properties << 'EOF'
#Minecraft server properties
enable-jmx-monitoring=false
rcon.port=25575
level-seed=
gamemode=survival
enable-command-block=false
enable-query=false
generator-settings={}
enforce-secure-profile=true
level-name=world
motd=\u00A7a\u00A7lMinecraft Server\u00A7r \u00A7b| Powered by Pterodactyl
query.port=25565
pvp=true
generate-structures=true
max-chained-neighbor-updates=1000000
difficulty=easy
network-compression-threshold=256
max-tick-time=60000
require-resource-pack=false
use-native-transport=true
max-players=20
online-mode=true
enable-status=true
allow-flight=false
initial-disabled-packs=
broadcast-rcon-to-ops=true
view-distance=10
server-ip=
resource-pack-prompt=
allow-nether=true
server-port=25565
enable-rcon=false
sync-chunk-writes=true
op-permission-level=4
prevent-proxy-connections=false
hide-online-players=false
resource-pack=
entity-broadcast-range-percentage=100
simulation-distance=10
rcon.password=
player-idle-timeout=0
force-gamemode=false
rate-limit=0
hardcore=false
white-list=false
broadcast-console-to-ops=true
spawn-npcs=true
previews-chat=false
spawn-animals=true
log-ips=true
function-permission-level=2
initial-enabled-packs=vanilla
level-type=minecraft\:normal
text-filtering-config=
spawn-monsters=true
enforce-whitelist=false
spawn-protection=16
max-world-size=29999984
EOF
        success "server.properties dibuat"
    else
        log "server.properties sudah ada, tidak ditimpa"
    fi
}

# ============================================================
# INSTALLER: VANILLA
# ============================================================
install_vanilla() {
    step "Menginstal Minecraft Vanilla..."
    resolve_mc_version

    local manifest_url
    manifest_url=$(curl -sSL "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json" \
        | jq -r --arg ver "$MC_VERSION" '.versions[] | select(.id == $ver) | .url')

    if [ -z "$manifest_url" ]; then
        error "Versi Minecraft '$MC_VERSION' tidak ditemukan!"
    fi

    local server_url
    server_url=$(curl -sSL "$manifest_url" | jq -r '.downloads.server.url')

    log "Mendownload Vanilla $MC_VERSION..."
    curl -sSL -o server.jar "$server_url"
    success "Vanilla $MC_VERSION berhasil didownload!"
}

# ============================================================
# INSTALLER: PAPER
# ============================================================
install_paper() {
    step "Menginstal PaperMC..."
    resolve_mc_version

    # [WORKAROUND] Bypass khusus untuk versi 26.1.2 (Karena API PaperMC belum update)
    if [ "$MC_VERSION" = "26.1.2" ]; then
        log "Mendownload Paper 26.1.2 (Early Access Build #69)..."
        curl -sSL -o server.jar "https://github.com/muhammadtsaqf/egg-mc/raw/main/paper/paper-26.1.2-69.jar"
        success "Paper 26.1.2 build #69 berhasil didownload secara manual!"
        return 0
    fi

    local api_url="https://api.papermc.io/v2/projects/paper/versions/$MC_VERSION"
    local builds_json
    builds_json=$(curl -sSL "$api_url" 2>/dev/null || echo "")

    if [ -z "$builds_json" ] || echo "$builds_json" | grep -q '"error"'; then
        error "Versi Paper '$MC_VERSION' tidak tersedia. Cek https://papermc.io/downloads"
    fi

    if [ "$BUILD_NUMBER" = "latest" ]; then
        BUILD_NUMBER=$(echo "$builds_json" | jq -r '.builds[-1]')
    fi

    local jar_name="paper-$MC_VERSION-$BUILD_NUMBER.jar"
    local download_url="https://api.papermc.io/v2/projects/paper/versions/$MC_VERSION/builds/$BUILD_NUMBER/downloads/$jar_name"

    log "Mendownload Paper $MC_VERSION build #$BUILD_NUMBER..."
    curl -sSL -o server.jar "$download_url"
    success "Paper $MC_VERSION build #$BUILD_NUMBER berhasil didownload!"
}

# ============================================================
# INSTALLER: PURPUR
# ============================================================
install_purpur() {
    step "Menginstal Purpur..."
    resolve_mc_version

    if [ "$BUILD_NUMBER" = "latest" ]; then
        BUILD_NUMBER=$(curl -sSL "https://api.purpurmc.org/v2/purpur/$MC_VERSION" | jq -r '.builds.latest')
    fi

    local download_url="https://api.purpurmc.org/v2/purpur/$MC_VERSION/$BUILD_NUMBER/download"

    log "Mendownload Purpur $MC_VERSION build #$BUILD_NUMBER..."
    curl -sSL -o server.jar "$download_url"
    success "Purpur $MC_VERSION build #$BUILD_NUMBER berhasil didownload!"
}

# ============================================================
# INSTALLER: SPIGOT (via BuildTools)
# ============================================================
install_spigot() {
    step "Menginstal Spigot via BuildTools..."
    resolve_mc_version

    log "Mendownload BuildTools..."
    curl -sSL -o BuildTools.jar "https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"

    log "Build Spigot $MC_VERSION (proses ini bisa memakan waktu 10-30 menit)..."
    java -jar BuildTools.jar --rev "$MC_VERSION" --output-dir . > buildtools.log 2>&1 || {
        warn "BuildTools error, lihat buildtools.log untuk detail"
        cat buildtools.log | tail -50
        error "Gagal build Spigot"
    }

    # Cari file hasil build
    local spigot_jar
    spigot_jar=$(ls spigot-*.jar 2>/dev/null | head -1)
    if [ -z "$spigot_jar" ]; then
        error "File spigot JAR tidak ditemukan setelah build!"
    fi

    mv "$spigot_jar" server.jar
    rm -f BuildTools.jar craftbukkit-*.jar
    success "Spigot $MC_VERSION berhasil dibangun!"
}

# ============================================================
# INSTALLER: FORGE
# ============================================================
install_forge() {
    step "Menginstal Minecraft Forge..."
    resolve_mc_version

    local promotions_url="https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"
    local promotions
    promotions=$(curl -sSL "$promotions_url")

    if [ "$FORGE_VERSION" = "latest" ]; then
        # Coba latest, kalau tidak ada coba recommended
        FORGE_VERSION=$(echo "$promotions" | jq -r --arg ver "$MC_VERSION" '.promos["\($ver)-latest"] // .promos["\($ver)-recommended"] // empty')
        if [ -z "$FORGE_VERSION" ]; then
            error "Tidak ada Forge versi untuk Minecraft $MC_VERSION. Cek https://files.minecraftforge.net/"
        fi
    fi

    local forge_full="$MC_VERSION-$FORGE_VERSION"
    local installer_url="https://maven.minecraftforge.net/net/minecraftforge/forge/$forge_full/forge-$forge_full-installer.jar"

    log "Mendownload Forge Installer $forge_full..."
    curl -sSL -o forge-installer.jar "$installer_url" || error "Gagal download Forge installer"

    log "Menginstal Forge (mode server)..."
    java -jar forge-installer.jar --installServer . > forge-install.log 2>&1 || {
        cat forge-install.log | tail -30
        error "Gagal instalasi Forge"
    }

    rm -f forge-installer.jar forge-installer.jar.log

    # Forge 1.17+ menggunakan run.sh
    if [ -f "run.sh" ]; then
        log "Forge modern ditemukan (run.sh), membuat wrapper server.jar..."
        # Buat wrapper script
        cat > start-forge.sh << 'FORGEEOF'
#!/bin/bash
bash run.sh nogui
FORGEEOF
        chmod +x start-forge.sh
        # Buat dummy server.jar agar Pterodactyl happy
        echo "#!/bin/bash" > server.jar
    else
        # Forge lama: cari forge-*-universal.jar
        local forge_jar
        forge_jar=$(ls forge-*-universal.jar 2>/dev/null | head -1)
        if [ -n "$forge_jar" ]; then
            mv "$forge_jar" server.jar
        else
            # Forge 1.17+ juga bisa ada forge-*.jar saja
            forge_jar=$(ls forge-*.jar 2>/dev/null | grep -v installer | head -1)
            [ -n "$forge_jar" ] && mv "$forge_jar" server.jar
        fi
    fi

    success "Forge $forge_full berhasil diinstal!"
}

# ============================================================
# INSTALLER: FABRIC
# ============================================================
install_fabric() {
    step "Menginstal Fabric Loader..."
    resolve_mc_version

    # Ambil versi Fabric Loader terbaru jika 'latest'
    if [ "$FABRIC_VERSION" = "latest" ]; then
        FABRIC_VERSION=$(curl -sSL "https://meta.fabricmc.net/v2/versions/loader" | jq -r '.[0].version')
        log "Fabric Loader versi terbaru: $FABRIC_VERSION"
    fi

    # Ambil versi Installer Fabric terbaru
    local installer_version
    installer_version=$(curl -sSL "https://meta.fabricmc.net/v2/versions/installer" | jq -r '.[0].version')
    log "Fabric Installer versi: $installer_version"

    local download_url="https://meta.fabricmc.net/v2/versions/loader/$MC_VERSION/$FABRIC_VERSION/$installer_version/server/jar"

    log "Mendownload Fabric Server Launcher..."
    curl -sSL -o server.jar "$download_url"
    success "Fabric $FABRIC_VERSION untuk MC $MC_VERSION berhasil didownload!"
}

# ============================================================
# INSTALLER: QUILT
# ============================================================
install_quilt() {
    step "Menginstal Quilt Loader..."
    resolve_mc_version

    # Ambil versi Quilt Loader terbaru
    if [ "$QUILT_VERSION" = "latest" ]; then
        QUILT_VERSION=$(curl -sSL "https://meta.quiltmc.org/v3/versions/loader" | jq -r '.[0].version')
        log "Quilt Loader versi terbaru: $QUILT_VERSION"
    fi

    # Ambil installer Quilt terbaru
    local installer_version
    installer_version=$(curl -sSL "https://meta.quiltmc.org/v3/versions/installer" | jq -r '.[0].version')
    log "Quilt Installer versi: $installer_version"

    local installer_url="https://quiltmc.org/api/v1/download-latest-installer/java-universal"
    log "Mendownload Quilt Installer..."
    curl -sSL -o quilt-installer.jar "$installer_url"

    log "Menginstal Quilt Server..."
    java -jar quilt-installer.jar install server "$MC_VERSION" "$QUILT_VERSION" --download-server --install-dir . > /dev/null 2>&1

    # Rename ke server.jar
    local quilt_jar
    quilt_jar=$(ls quilt-server-launch.jar 2>/dev/null || ls *launch*.jar 2>/dev/null | head -1)
    if [ -n "$quilt_jar" ]; then
        cp "$quilt_jar" server.jar 2>/dev/null || true
    fi

    rm -f quilt-installer.jar
    success "Quilt $QUILT_VERSION untuk MC $MC_VERSION berhasil diinstal!"
}

# ============================================================
# INSTALLER: BUNGEECORD
# ============================================================
install_bungeecord() {
    step "Menginstal BungeeCord..."

    log "Mendownload BungeeCord terbaru..."
    curl -sSL -o server.jar "https://ci.md-5.net/job/BungeeCord/lastSuccessfulBuild/artifact/bootstrap/target/BungeeCord.jar"

    # BungeeCord menggunakan config.yml, bukan server.properties
    if [ ! -f config.yml ]; then
        cat > config.yml << 'EOF'
player_limit: -1
permissions:
  default:
  - bungeecord.command.server
  - bungeecord.command.list
  admin:
  - bungeecord.command.alert
  - bungeecord.command.end
  - bungeecord.command.ip
  - bungeecord.command.reload
timeout: 30000
log_commands: false
online_mode: true
disabled_commands:
- disabledcommandhere
servers:
  lobby:
    motd: '&1Just another BungeeCord - Forced Host'
    address: localhost:25565
    restricted: false
listeners:
- query_port: 25577
  motd: '&1Another Bungee server'
  tab_list: GLOBAL_PING
  query_enabled: false
  proxy_protocol: false
  forced_hosts:
    pvp.md-5.net: pvp
  ping_passthrough: false
  priorities:
  - lobby
  bind_local_address: true
  host: 0.0.0.0:25577
  max_players: 1
  tab_size: 60
  force_default_server: false
ip_forward: false
remote_ping_cache: -1
log_pings: true
connection_throttle: 4000
connection_throttle_limit: 3
EOF
        success "config.yml BungeeCord dibuat"
    fi
    success "BungeeCord berhasil didownload!"
}

# ============================================================
# INSTALLER: WATERFALL
# ============================================================
install_waterfall() {
    step "Menginstal Waterfall..."

    # Waterfall pakai channel 'latest' karena tidak ada versi MC spesifik
    local builds_json
    builds_json=$(curl -sSL "https://api.papermc.io/v2/projects/waterfall/versions/1.20/builds" 2>/dev/null || echo "")

    if [ -z "$builds_json" ] || echo "$builds_json" | grep -q '"error"'; then
        # Fallback ke latest build
        warn "Menggunakan build latest Waterfall"
        local wf_version="1.20"
        BUILD_NUMBER=$(curl -sSL "https://api.papermc.io/v2/projects/waterfall/versions/$wf_version" | jq -r '.builds[-1]')
        local jar_name="waterfall-$wf_version-$BUILD_NUMBER.jar"
        local download_url="https://api.papermc.io/v2/projects/waterfall/versions/$wf_version/builds/$BUILD_NUMBER/downloads/$jar_name"
    else
        local wf_version="1.20"
        BUILD_NUMBER=$(echo "$builds_json" | jq -r '.builds[-1].build')
        local jar_name="waterfall-$wf_version-$BUILD_NUMBER.jar"
        local download_url="https://api.papermc.io/v2/projects/waterfall/versions/$wf_version/builds/$BUILD_NUMBER/downloads/$jar_name"
    fi

    log "Mendownload Waterfall build #$BUILD_NUMBER..."
    curl -sSL -o server.jar "$download_url"
    success "Waterfall berhasil didownload!"
}

# ============================================================
# INSTALLER: VELOCITY
# ============================================================
install_velocity() {
    step "Menginstal Velocity..."

    local velocity_version
    velocity_version=$(curl -sSL "https://api.papermc.io/v2/projects/velocity" | jq -r '.versions[-1]')

    if [ "$BUILD_NUMBER" = "latest" ]; then
        BUILD_NUMBER=$(curl -sSL "https://api.papermc.io/v2/projects/velocity/versions/$velocity_version" | jq -r '.builds[-1]')
    fi

    local jar_name="velocity-$velocity_version-$BUILD_NUMBER.jar"
    local download_url="https://api.papermc.io/v2/projects/velocity/versions/$velocity_version/builds/$BUILD_NUMBER/downloads/$jar_name"

    log "Mendownload Velocity $velocity_version build #$BUILD_NUMBER..."
    curl -sSL -o server.jar "$download_url"

    if [ ! -f velocity.toml ]; then
        cat > velocity.toml << 'EOF'
# Config Version. Do not change this
config-version = "2.7"

# What port should the proxy be bound to? By default, we'll bind to all addresses on port 25577.
bind = "0.0.0.0:25577"

# What should be the MOTD? This gets displayed when the client is just pinging the server.
motd = "<#09add3>A Velocity Server"

# What should we display for the maximum number of players? (Velocity does not support a cap on the number of players.)
show-max-players = 500

# Should we authenticate players with Mojang? By default, this is on.
online-mode = true

# If client's ISP/AS sent from this proxy before forwarding player information to backend servers,
# enable this setting to compress and forward that information to the backend server.
force-key-authentication = true

# Should the proxy enforce the new public key security standard? By default, this is on.
player-info-forwarding-mode = "NONE"

# If you are using modern or BungeeCord IP forwarding, configure an forwarding secret here.
forwarding-secret-file = "forwarding.secret"

# Announce whether you're a Velocity instance to Mojang-operated services
announce-forge = false

# If enabled, ping requests from clients will be answered immediately without
# waiting for a response from a server.
kick-existing-players = false

# Should Velocity pass server list ping requests to a backend server?
ping-passthrough = "DISABLED"

# If not enabled, the max players sent to clients will be set to
# online-players + 1, preventing full server messages.
enable-player-address-logging = true

[servers]
# Configure your servers here. Each key represents the server's name, and the value
# represents the IP address of the server to connect to.
lobby = "127.0.0.1:30066"
factions = "127.0.0.1:30067"
minigames = "127.0.0.1:30068"

# In what order we should try servers when a player logs in or is kicked from a server.
try = [
    "lobby"
]

[forced-hosts]

[advanced]
compression-threshold = 256
compression-level = -1
login-ratelimit = 3000
connection-timeout = 5000
read-timeout = 30000
haproxy-protocol = false
tcp-fast-open = false
bungee-plugin-message-channel = true
show-ping-requests = false
failover-on-unexpected-server-disconnect = true
announce-proxy-commands = true
log-command-executions = false
log-player-connections = true

[query]
# Whether to enable responding to GameSpy 4 query responses or not.
enabled = false
port = 25577
map = "Velocity"
show-plugins = false
EOF
        success "velocity.toml dibuat"
    fi

    success "Velocity berhasil didownload!"
}

# ============================================================
# MAIN - Jalankan installer sesuai SERVER_TYPE
# ============================================================
main() {
    install_dependencies
    check_java

    case "$SERVER_TYPE" in
        vanilla)          install_vanilla    ;;
        paper)            install_paper      ;;
        purpur)           install_purpur     ;;
        spigot)           install_spigot     ;;
        forge)            install_forge      ;;
        fabric)           install_fabric     ;;
        quilt)            install_quilt      ;;
        bungeecord|bungee) install_bungeecord ;;
        waterfall)        install_waterfall  ;;
        velocity)         install_velocity   ;;
        *)
            error "SERVER_TYPE tidak dikenal: '$SERVER_TYPE'. Pilihan: vanilla, paper, purpur, spigot, forge, fabric, quilt, bungeecord, waterfall, velocity"
            ;;
    esac

    # Tulis EULA dan server.properties (kecuali untuk proxy)
    case "$SERVER_TYPE" in
        bungeecord|bungee|waterfall|velocity)
            log "Server proxy tidak memerlukan eula.txt / server.properties"
            ;;
        *)
            write_eula
            write_server_properties
            ;;
    esac

    echo ""
    echo "============================================================"
    echo -e "  ${GREEN}Instalasi selesai!${NC}"
    echo "  Server Type : $SERVER_TYPE"
    echo "  MC Version  : $MC_VERSION"
    echo "  File JAR    : server.jar"
    echo "============================================================"
    echo ""
}

main
