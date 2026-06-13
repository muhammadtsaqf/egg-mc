# 🎮 Pterodactyl Egg - Minecraft Universal

<div align="center">

![Minecraft Universal Egg](https://img.shields.io/badge/Pterodactyl-Egg-blue?style=for-the-badge&logo=minecraft)
![Minecraft Versions](https://img.shields.io/badge/Minecraft-1.8%20→%20Latest-green?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-Multi--Platform-2496ED?style=for-the-badge&logo=docker)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

**Satu egg untuk semua versi dan semua jenis server Minecraft**

[📥 Download Egg](#-cara-install) • [🐳 Docker Hub](#-docker-images) • [📖 Dokumentasi](#-konfigurasi-variabel)

</div>

---

## ✨ Fitur

- **🎮 10 Server Types** - Vanilla, Paper, Purpur, Spigot, Forge, Fabric, Quilt, BungeeCord, Waterfall, Velocity
- **📦 Semua Versi MC** - Mendukung Minecraft dari versi 1.8 hingga terbaru
- **☕ Multi-Java** - Java 8, 11, 17, dan 21 tersedia dalam image terpisah
- **⚡ Aikar's Flags** - JVM flags teroptimasi otomatis untuk performa terbaik
- **🔄 Auto-Update** - Selalu download build terbaru secara otomatis
- **🐳 Multi-Platform** - Docker image untuk `linux/amd64` dan `linux/arm64`
- **🔒 Secure** - Berjalan sebagai user non-root (container:1000)

---

## 🎯 Server Types yang Didukung

| Server Type | Deskripsi | Versi MC | Penggunaan |
|------------|-----------|----------|------------|
| `vanilla` | Server resmi Mojang | 1.0 - Latest | Server murni tanpa mod/plugin |
| `paper` ⭐ | Fork Spigot teroptimasi | 1.8 - Latest | **RECOMMENDED** untuk server plugin |
| `purpur` | Fork Paper dengan fitur ekstra | 1.14 - Latest | Server plugin dengan kustomisasi lebih |
| `spigot` | Bukkit fork original | 1.8 - Latest | Server plugin klasik |
| `forge` | Platform mod Forge | 1.5 - Latest | Server mod Forge |
| `fabric` | Platform mod modern | 1.14 - Latest | Server mod Fabric |
| `quilt` | Fork Fabric | 1.14 - Latest | Server mod Quilt |
| `bungeecord` | Proxy klasik | - | Network/BungeeCord proxy |
| `waterfall` ⭐ | Fork BungeeCord teroptimasi | - | **RECOMMENDED** untuk proxy jaringan |
| `velocity` ⭐⭐ | Proxy modern | - | **BEST** untuk proxy performa tinggi |

---

## 📥 Cara Install

### 1. Import Egg ke Pterodactyl

1. Download file `egg-minecraft-universal.json` dari [Releases](../../releases)
2. Buka **Pterodactyl Panel** → **Admin** → **Nests**
3. Buat Nest baru atau pilih yang sudah ada
4. Klik **Import Egg** dan upload file JSON
5. Konfigurasi sesuai kebutuhan

### 2. Buat Server Baru

1. Buka **Pterodactyl Panel** → **Servers** → **Create New**
2. Pilih egg **"Minecraft Universal"**
3. Isi variabel yang diperlukan (lihat [Konfigurasi](#-konfigurasi-variabel))
4. Pilih Docker image sesuai versi Java yang dibutuhkan
5. Klik **Create Server** dan tunggu instalasi selesai

---

## 🐳 Docker Images

Images tersedia di Docker Hub dengan berbagai tag:

```bash
# Java 21 - Untuk Minecraft 1.20.5+ (RECOMMENDED)
docker pull azzamdev17/minecraft-egg:latest
docker pull azzamdev17/minecraft-egg:java21

# Java 17 - Untuk Minecraft 1.17 - 1.20.4
docker pull azzamdev17/minecraft-egg:java17

# Java 11 - Untuk Minecraft 1.12 - 1.16.5
docker pull azzamdev17/minecraft-egg:java11

# Java 8 - Untuk Minecraft 1.8 - 1.12.2
docker pull azzamdev17/minecraft-egg:java8
```

### Pilih Java yang Tepat

| Versi Minecraft | Java yang Direkomendasikan | Docker Tag |
|-----------------|---------------------------|------------|
| 1.20.5 - Latest | Java 21 | `java21` / `latest` |
| 1.17 - 1.20.4 | Java 17 | `java17` |
| 1.12 - 1.16.5 | Java 11 | `java11` |
| 1.8 - 1.12.2 | Java 8 | `java8` |

---

## ⚙️ Konfigurasi Variabel

| Variabel | Default | Deskripsi |
|---------|---------|-----------|
| `SERVER_TYPE` | `paper` | Jenis server (`vanilla`, `paper`, `purpur`, `spigot`, `forge`, `fabric`, `quilt`, `bungeecord`, `waterfall`, `velocity`) |
| `MC_VERSION` | `latest` | Versi Minecraft (contoh: `1.21.4`, `1.20.1`, `latest`) |
| `BUILD_NUMBER` | `latest` | Build number untuk Paper/Purpur/dll |
| `FORGE_VERSION` | `latest` | Versi Forge (khusus `SERVER_TYPE=forge`) |
| `FABRIC_VERSION` | `latest` | Versi Fabric Loader (khusus `SERVER_TYPE=fabric`) |
| `QUILT_VERSION` | `latest` | Versi Quilt Loader (khusus `SERVER_TYPE=quilt`) |
| `MAX_MEMORY` | `1024` | RAM maksimum dalam MB |
| `MIN_MEMORY` | `512` | RAM minimum dalam MB |
| `JAVA_FLAGS` | (kosong) | Custom JVM flags (kosong = pakai Aikar's flags otomatis) |
| `SERVER_PORT` | `25565` | Port server Minecraft |
| `STARTUP_TIMEOUT` | `120` | Timeout startup dalam detik |

---

## 🚀 Contoh Konfigurasi

### Server Paper Terbaru (Paling Umum)
```
SERVER_TYPE=paper
MC_VERSION=latest
MAX_MEMORY=2048
MIN_MEMORY=1024
```

### Server Forge 1.20.1
```
SERVER_TYPE=forge
MC_VERSION=1.20.1
FORGE_VERSION=latest
MAX_MEMORY=4096
MIN_MEMORY=2048
```

### Server Fabric 1.21.4
```
SERVER_TYPE=fabric
MC_VERSION=1.21.4
FABRIC_VERSION=latest
MAX_MEMORY=2048
MIN_MEMORY=1024
```

### Server Vanilla 1.8.9 (Java 8)
```
SERVER_TYPE=vanilla
MC_VERSION=1.8.9
MAX_MEMORY=1024
MIN_MEMORY=512
# Gunakan Docker image: java8
```

### Proxy Velocity
```
SERVER_TYPE=velocity
MAX_MEMORY=512
MIN_MEMORY=256
SERVER_PORT=25577
```

---

## 🔧 Setup GitHub Actions

Untuk mengaktifkan push otomatis ke Docker Hub, tambahkan **Secrets** di repository GitHub:

1. Buka **Repository GitHub** → **Settings** → **Secrets and variables** → **Actions**
2. Tambahkan secrets berikut:

| Secret | Nilai |
|--------|-------|
| `DOCKER_USERNAME` | Username Docker Hub kamu |
| `DOCKER_PASSWORD` | Password atau Access Token Docker Hub |

### Cara mendapatkan Docker Hub Access Token:
1. Login ke [hub.docker.com](https://hub.docker.com)
2. Klik profil → **Account Settings** → **Security**
3. Klik **New Access Token**
4. Beri nama token dan copy nilainya
5. Paste sebagai nilai `DOCKER_PASSWORD` di GitHub Secrets

---

## 📁 Struktur File

```
projek-egg-MC/
├── 📄 egg-minecraft-universal.json   # File egg untuk diimport ke Pterodactyl
├── 🐳 Dockerfile                     # Docker image definition
├── 🔧 entrypoint.sh                  # Script startup server
├── 📦 install.sh                     # Script instalasi (dijalankan saat install)
├── 📖 README.md                      # Dokumentasi ini
└── .github/
    └── workflows/
        └── 🚀 docker-publish.yml     # GitHub Actions CI/CD
```

---

## 🔑 Aikar's Flags (JVM Optimization)

Egg ini secara otomatis menggunakan **Aikar's Flags** yang telah terbukti meningkatkan performa server Minecraft secara signifikan:

```
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=40
... dan lainnya
```

> 💡 **Tips**: Biarkan `JAVA_FLAGS` kosong untuk menggunakan Aikar's Flags secara otomatis. Hanya isi jika kamu memiliki alasan khusus.

---

## 🤝 Kontribusi

Pull request sangat disambut! Untuk perubahan besar, buka issue terlebih dahulu untuk mendiskusikan apa yang ingin kamu ubah.

---

## 📜 Lisensi

[MIT License](LICENSE) - Bebas digunakan, dimodifikasi, dan didistribusikan.

---

<div align="center">

**Dibuat dengan ❤️ oleh [Muhammad Tsaqif Noor Az Zamil](mailto:azzamganteng921@gmail.com)**

</div>
