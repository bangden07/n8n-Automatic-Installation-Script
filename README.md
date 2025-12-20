# 🚀 n8n Self-Hosted Installation Script

Automated installation script untuk deploy n8n self-hosted di Ubuntu/Debian dengan satu command.

![n8n](https://img.shields.io/badge/n8n-Automation-orange)
![Docker](https://img.shields.io/badge/Docker-Containerized-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Fitur Utama

| Fitur | Deskripsi |
|-------|-----------|
| 🔍 **Version Check** | Validasi versi software yang terinstall |
| 🖥️ **OS Detection** | Auto-detect Ubuntu/Debian |
| 💾 **Resource Check** | Cek RAM & disk sebelum install |
| 🐳 **Docker** | Install Docker Engine + Compose |
| 🐘 **PostgreSQL** | Database production-ready |
| 🌐 **Nginx/Caddy** | Pilihan reverse proxy |
| 🔒 **SSL/HTTPS** | Let's Encrypt otomatis |
| 🛡️ **Firewall** | UFW auto-configured |
| 🔐 **Auto Credentials** | Generate password & encryption key |

---

## 🎯 Keunggulan

- **One-Click Install** - Seluruh stack terinstall otomatis
- **Production Ready** - PostgreSQL, SSL, Firewall sudah dikonfigurasi
- **Dual Proxy Option** - Pilih Nginx (traditional) atau Caddy (modern)
- **Auto SSL Renewal** - Sertifikat Let's Encrypt auto-renew
- **Secure by Default** - Password random, encryption key, firewall enabled
- **Docker-based** - Easy update, backup, dan maintenance
- **Colored Output** - Status jelas dengan warna (hijau/kuning/merah)
- **Error Handling** - Validasi input dan pengecekan error

---

## 📋 Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 20.04 / Debian 11 | Ubuntu 24.04 / Debian 12 |
| RAM | 1 GB | 2 GB+ |
| Disk | 10 GB | 20 GB+ |
| CPU | 1 Core | 2 Cores+ |
| Domain | ✅ Required | Pointed to server IP |
| Access | Root/Sudo | - |

---

## 🚀 Instalasi

### Quick Install

```bash
# Download script
curl -O https://raw.githubusercontent.com/your-repo/install-n8n.sh

# Beri permission
chmod +x install-n8n.sh

# Jalankan
sudo ./install-n8n.sh
```

### Manual Upload

```bash
# Dari Windows ke Server
scp install-n8n.sh user@server:/tmp/

# Di server
chmod +x /tmp/install-n8n.sh
sudo /tmp/install-n8n.sh
```

---

## 📖 Cara Penggunaan

### 1. Jalankan Script

```bash
sudo ./install-n8n.sh
```

### 2. Ikuti Prompt

Script akan meminta:

| Input | Contoh | Keterangan |
|-------|--------|------------|
| Domain | `n8n.example.com` | Harus sudah pointing ke IP server |
| Email | `admin@example.com` | Untuk sertifikat SSL |
| Proxy | `1` atau `2` | 1=Nginx, 2=Caddy |
| Timezone | `Asia/Jakarta` | Default: Asia/Jakarta |

### 3. Tunggu Instalasi

Script akan menjalankan 10 langkah:
1. System Update
2. Docker Installation
3. Firewall Configuration
4. Reverse Proxy Installation
5. SSL Certificate
6. Directory Structure
7. Docker Compose Configuration
8. Start Containers
9. Verification
10. Complete!

### 4. Akses n8n

Setelah selesai, buka browser:
```
https://your-domain.com
```

---

## 🔧 Detail Fungsi

### Pre-Installation

| Fungsi | Deskripsi |
|--------|-----------|
| `print_banner()` | Tampilkan ASCII art banner |
| `check_root()` | Validasi running as root |
| `check_os()` | Detect Ubuntu/Debian |
| `check_resources()` | Cek RAM, disk, CPU |
| `check_existing_installations()` | Cek Docker, Nginx, Node.js |

### Utility Functions

| Fungsi | Deskripsi |
|--------|-----------|
| `print_status()` | Print colored status messages |
| `progress_bar()` | Tampilkan progress bar visual |
| `check_version()` | Cek dan tampilkan versi software |
| `generate_password()` | Generate random password |
| `generate_encryption_key()` | Generate 64-char hex key |
| `validate_domain()` | Validasi format domain |
| `validate_email()` | Validasi format email |

### Installation Functions

| Fungsi | Deskripsi |
|--------|-----------|
| `system_update()` | apt update && upgrade |
| `install_docker()` | Install Docker dari official repo |
| `configure_firewall()` | Setup UFW (22, 80, 443) |
| `install_nginx()` | Install Nginx + Certbot |
| `install_caddy()` | Install Caddy (auto-SSL) |
| `obtain_ssl_certificate()` | Request cert dari Let's Encrypt |
| `create_n8n_directory()` | Buat ~/n8n dan subdirectories |
| `create_docker_compose()` | Generate docker-compose.yml |
| `start_n8n()` | Pull images & start containers |
| `verify_installation()` | Cek semua services running |
| `display_summary()` | Tampilkan credentials & info |

---

## 📂 Struktur File

Setelah instalasi:

```
~/n8n/
├── docker-compose.yml    # Docker configuration
├── .env                  # Environment variables (chmod 600)
├── credentials.txt       # Saved credentials (chmod 600)
├── data/                 # n8n data directory
├── postgres-data/        # PostgreSQL data
└── backup/               # Backup directory
```

---

## 🛠️ Commands Berguna

```bash
# Lihat logs
docker logs -f n8n

# Restart n8n
cd ~/n8n && docker compose restart

# Stop n8n
cd ~/n8n && docker compose down

# Start n8n
cd ~/n8n && docker compose up -d

# Update n8n
cd ~/n8n && docker compose pull && docker compose up -d

# Backup data
cp -r ~/n8n/data ~/n8n/backup/$(date +%Y%m%d)

# Lihat status container
docker compose ps
```

---

## 🔒 Security Notes

- ✅ Passwords di-generate random (24 karakter)
- ✅ Encryption key 64-karakter hex
- ✅ File credentials chmod 600
- ✅ Firewall hanya buka port 22, 80, 443
- ✅ SSL/HTTPS enforced
- ✅ PostgreSQL tidak exposed ke public

---

## ❓ Troubleshooting

### Script exit setelah checking

**Problem:** Script berhenti setelah "Checking existing installations"

**Solution:** Pastikan menggunakan versi script terbaru yang sudah remove `set -e`

### SSL Certificate gagal

**Problem:** Certbot gagal mendapatkan certificate

**Solution:**
1. Pastikan domain sudah pointing ke IP server
2. Tunggu DNS propagation (bisa sampai 24 jam)
3. Jalankan manual: `sudo certbot --nginx -d your-domain.com`

### n8n tidak bisa diakses

**Problem:** Browser tidak bisa buka https://domain.com

**Solution:**
```bash
# Cek container running
docker ps

# Cek logs
docker logs n8n

# Cek nginx/caddy
systemctl status nginx
# atau
systemctl status caddy
```

---

## 📝 License

MIT License - Free to use, modify, and distribute.

---

## 🙏 Credits

Script ini dibuat berdasarkan referensi:
- [n8n Official Docs](https://docs.n8n.io/hosting/)
- [DigitalOcean Tutorial](https://www.digitalocean.com/community/tutorials/how-to-setup-n8n)
- [Hostinger Guide](https://www.hostinger.com/tutorials/how-to-self-host-n8n)
- [Sliplane Blog](https://sliplane.io/blog/self-hosting-n8n-on-ubuntu-server)
