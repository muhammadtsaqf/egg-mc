# ============================================================
#  Pterodactyl Egg - Minecraft Universal Docker Image
#  Support: Java 8, 11, 17, 21 (multi-version via runtime)
#  Base: Ubuntu 22.04 LTS
# ============================================================

FROM ubuntu:22.04

LABEL maintainer="Muhammad Tsaqif Noor Az Zamil <azzamganteng921@gmail.com>"
LABEL description="Pterodactyl Minecraft Universal Egg - Support semua versi & semua server type"
LABEL version="1.0.0"

# ============================================================
# ENVIRONMENT DEFAULTS
# ============================================================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Jakarta \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}" \
    SERVER_TYPE=paper \
    MC_VERSION=latest \
    BUILD_NUMBER=latest \
    FORGE_VERSION=latest \
    FABRIC_VERSION=latest \
    QUILT_VERSION=latest \
    MAX_MEMORY=1024 \
    MIN_MEMORY=512 \
    JAVA_FLAGS="" \
    SERVER_PORT=25565 \
    STARTUP_TIMEOUT=120

# ============================================================
# INSTALL SISTEM DASAR + SEMUA VERSI JAVA
# ============================================================
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        # Utilitas dasar
        curl \
        wget \
        jq \
        unzip \
        zip \
        git \
        tar \
        bash \
        coreutils \
        findutils \
        iproute2 \
        ca-certificates \
        gnupg \
        lsb-release \
        tzdata \
        tini \
        # Font & locale
        locales \
        # Dependencies untuk Spigot BuildTools
        git \
        # Python untuk beberapa tools
        python3 \
        python3-pip \
    && \
    # Setup locale Indonesia
    locale-gen id_ID.UTF-8 && \
    update-locale LANG=id_ID.UTF-8 && \
    \
    # =============================================
    # Install Java 8 (untuk MC 1.8 - 1.16.5)
    # =============================================
    apt-get install -y --no-install-recommends openjdk-8-jre-headless && \
    \
    # =============================================
    # Install Java 11 (untuk MC 1.12 - 1.16.5)
    # =============================================
    apt-get install -y --no-install-recommends openjdk-11-jre-headless && \
    \
    # =============================================
    # Install Java 17 (untuk MC 1.17 - 1.20.4)
    # =============================================
    apt-get install -y --no-install-recommends openjdk-17-jre-headless && \
    \
    # =============================================
    # Install Java 21 (untuk MC 1.20.5+, default)
    # =============================================
    apt-get install -y --no-install-recommends openjdk-21-jre-headless && \
    \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================
# BUAT USER & DIREKTORI (Pterodactyl standard)
# ============================================================
RUN useradd -d /home/container -m container --uid 1000 --shell /bin/bash

# ============================================================
# COPY SCRIPTS
# ============================================================
COPY --chown=container:container entrypoint.sh /entrypoint.sh
COPY --chown=container:container install.sh /install.sh

RUN chmod +x /entrypoint.sh /install.sh

# ============================================================
# WORKING DIRECTORY
# ============================================================
WORKDIR /home/container

# ============================================================
# PORT
# ============================================================
# Minecraft standard
EXPOSE 25565/tcp
EXPOSE 25565/udp
# BungeeCord/Waterfall/Velocity proxy port
EXPOSE 25577/tcp
# RCON
EXPOSE 25575/tcp
# Query
EXPOSE 25565/udp

# ============================================================
# HEALTHCHECK
# ============================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD bash -c 'java -version &>/dev/null && echo "Java OK" || exit 1'

# ============================================================
# ENTRYPOINT
# ============================================================
USER container
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/bin/bash", "/entrypoint.sh"]
