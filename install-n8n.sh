#!/bin/bash

#######################################################################
#                                                                     #
#   n8n Self-Hosted Installation Script                              #
#   Automated installer with progress bar and version validation     #
#                                                                     #
#   Supports: Ubuntu 20.04/22.04/24.04, Debian 11/12                 #
#   Components: Docker, PostgreSQL, Nginx/Caddy, Let's Encrypt       #
#   Copyright by Github.com/BangDen07                                #
#######################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

N8N_DIR="${N8N_DIR:-$HOME/n8n}"
N8N_PORT="${N8N_PORT:-5678}"
POSTGRES_VERSION="${POSTGRES_VERSION:-16}"
N8N_IMAGE="${N8N_IMAGE:-docker.io/n8nio/n8n:latest}"
LOG_FILE="/var/log/n8n-install.log"
TOTAL_STEPS=10
CURRENT_STEP=0

DOMAIN=""
EMAIL=""
USE_CADDY=false
POSTGRES_PASSWORD=""
N8N_ENCRYPTION_KEY=""
TIMEZONE="${TIMEZONE:-Asia/Jakarta}"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "    ███╗   ██╗ █████╗ ███╗   ██╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ "
    echo "    ████╗  ██║██╔══██╗████╗  ██║    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗"
    echo "    ██╔██╗ ██║╚█████╔╝██╔██╗ ██║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝"
    echo "    ██║╚██╗██║██╔══██╗██║╚██╗██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗"
    echo "    ██║ ╚████║╚█████╔╝██║ ╚████║    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║"
    echo "    ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝"
    echo " Copyright by Github.com/BangDen07                                                                        "
    echo -e "${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}n8n Self-Hosted Automated Installer${NC}"
    echo -e "  ${DIM}Docker + PostgreSQL + Nginx/Caddy + SSL (Let's Encrypt)${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# UTILITY FUNCTIONS
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "${BLUE}[ℹ]${NC} $message" ;;
        "success") echo -e "${GREEN}[✔]${NC} $message" ;;
        "warning") echo -e "${YELLOW}[⚠]${NC} $message" ;;
        "error") echo -e "${RED}[✖]${NC} $message" ;;
        "progress") echo -e "${CYAN}[→]${NC} $message" ;;
    esac
    log "$status: $message"
}

progress_bar() {
    local current=$1
    local total=$2
    local title=$3
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    printf "\r${CYAN}[${NC}${GREEN}%s${NC}${CYAN}]${NC} ${WHITE}%3d%%${NC} ${DIM}%s${NC}" "$bar" "$percentage" "$title"
    
    if [ "$current" -eq "$total" ]; then echo ""; fi
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

check_version() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version
        case $cmd in
            "docker") version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
            "node") version=$(node --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') ;;
            "nginx") version=$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') ;;
            *) version=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) ;;
        esac
        
        if [ -n "$version" ]; then
            echo -e "${GREEN}✔${NC} $name: ${BOLD}v$version${NC}"
        else
            echo -e "${YELLOW}?${NC} $name: version unknown"
        fi
    else
        echo -e "${RED}✖${NC} $name: not installed"
    fi

    return 0
}

generate_password() {
    local length=${1:-32}
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

generate_encryption_key() {
    tr -dc 'a-f0-9' < /dev/urandom | head -c 64
}

validate_domain() {
    local domain=$1
    [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

validate_email() {
    local email=$1
    [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    progress_bar $CURRENT_STEP $TOTAL_STEPS "$1"
    echo ""
}

# PRE-INSTALLATION CHECKS
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_status "error" "This script must be run as root or with sudo"
        echo -e "   ${DIM}Please run: sudo $0${NC}"
        exit 1
    fi
}

check_os() {
    print_status "progress" "Checking operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        
        case $OS in
            ubuntu|debian)
                print_status "success" "Detected: $PRETTY_NAME"
                ;;
            *)
                print_status "error" "Unsupported OS: $OS"
                echo -e "   ${DIM}This script supports Ubuntu and Debian${NC}"
                exit 1
                ;;
        esac
    else
        print_status "error" "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

check_resources() {
    print_status "progress" "Checking system resources..."
    
    local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))
    
    if [ "$total_ram_mb" -lt 1024 ]; then
        print_status "error" "Insufficient RAM: ${total_ram_mb}MB (minimum 1GB required)"
        exit 1
    else
        print_status "success" "RAM: ${total_ram_mb}MB"
    fi
    
    local available_disk=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$available_disk" -lt 10240 ]; then
        print_status "warning" "Low disk space: ${available_disk}MB available"
    else
        print_status "success" "Disk space: ${available_disk}MB available"
    fi

    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    print_status "info" "CPU cores: $cpu_cores"
}

check_existing_installations() {
    print_status "progress" "Checking existing installations..."
    
    echo ""
    echo -e "${BOLD}Current Installation Status:${NC}"
    echo -e "${DIM}────────────────────────────────────────${NC}"
    
    check_version "docker" "Docker"
    check_version "nginx" "Nginx"
    check_version "node" "Node.js"
    
    if command -v certbot &> /dev/null; then
        echo -e "${GREEN}✔${NC} Certbot: installed"
    else
        echo -e "${YELLOW}○${NC} Certbot: not installed"
    fi
    
    if docker ps 2>/dev/null | grep -q n8n; then
        echo -e "${YELLOW}⚠${NC} n8n container: already running"
    fi
    
    echo -e "${DIM}────────────────────────────────────────${NC}"
    echo ""
}

get_user_input() {
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}              Configuration Settings                          ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    while true; do
        echo -ne "${WHITE}Enter your domain name (e.g., n8n.example.com): ${NC}"
        read -r DOMAIN
        if [ -z "$DOMAIN" ]; then
            print_status "error" "Domain cannot be empty"
        elif validate_domain "$DOMAIN"; then
            print_status "success" "Domain: $DOMAIN"
            break
        else
            print_status "error" "Invalid domain format"
        fi
    done

    while true; do
        echo -ne "${WHITE}Enter your email for SSL certificates: ${NC}"
        read -r EMAIL
        if [ -z "$EMAIL" ]; then
            print_status "error" "Email cannot be empty"
        elif validate_email "$EMAIL"; then
            print_status "success" "Email: $EMAIL"
            break
        else
            print_status "error" "Invalid email format"
        fi
    done
    
    echo ""
    echo -e "${WHITE}Choose your reverse proxy:${NC}"
    echo -e "  ${CYAN}1)${NC} Nginx + Certbot (Traditional)"
    echo -e "  ${CYAN}2)${NC} Caddy (Automatic HTTPS)"
    echo -ne "${WHITE}Enter choice [1-2] (default: 1): ${NC}"
    read -r proxy_choice
    
    case $proxy_choice in
        2)
            USE_CADDY=true
            print_status "success" "Reverse proxy: Caddy"
            ;;
        *)
            USE_CADDY=false
            print_status "success" "Reverse proxy: Nginx + Certbot"
            ;;
    esac
    
    echo -ne "${WHITE}Enter timezone (default: $TIMEZONE): ${NC}"
    read -r tz_input
    if [ -n "$tz_input" ]; then
        TIMEZONE=$tz_input
    fi
    print_status "success" "Timezone: $TIMEZONE"
    
    POSTGRES_PASSWORD=$(generate_password 24)
    N8N_ENCRYPTION_KEY=$(generate_encryption_key)
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Installation Settings:${NC}"
    echo -e "  Domain:        ${BOLD}$DOMAIN${NC}"
    echo -e "  Email:         ${BOLD}$EMAIL${NC}"
    echo -e "  Reverse Proxy: ${BOLD}$([ "$USE_CADDY" = true ] && echo 'Caddy' || echo 'Nginx')${NC}"
    echo -e "  Timezone:      ${BOLD}$TIMEZONE${NC}"
    echo -e "  n8n Directory: ${BOLD}$N8N_DIR${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo -ne "${WHITE}Proceed with installation? [Y/n]: ${NC}"
    read -r confirm
    if [[ ! $confirm =~ ^[Yy]?$ ]]; then
        print_status "info" "Installation cancelled by user"
        exit 0
    fi
}

# INSTALLATION FUNCTIONS

system_update() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 1: System Update                                      │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    print_status "progress" "Updating package lists..."
    apt-get update -qq >> "$LOG_FILE" 2>&1
    print_status "success" "Package lists updated"
    
    print_status "progress" "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1
    print_status "success" "Packages upgraded"
    
    print_status "progress" "Installing essential dependencies..."
    apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        openssl \
        >> "$LOG_FILE" 2>&1
    print_status "success" "Essential dependencies installed"
    
    update_progress "System Update"
}

install_docker() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 2: Docker Installation                                │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    if command -v docker &> /dev/null; then
        print_status "info" "Docker is already installed"
        check_version "docker" "Docker"
    else
        print_status "progress" "Setting up Docker repository..."

        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/${OS}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS} $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        print_status "success" "Docker repository configured"
        
        print_status "progress" "Installing Docker Engine..."
        apt-get update -qq >> "$LOG_FILE" 2>&1
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$LOG_FILE" 2>&1
        print_status "success" "Docker Engine installed"
    fi

    print_status "progress" "Verifying Docker installation..."
    if docker run --rm hello-world >> "$LOG_FILE" 2>&1; then
        print_status "success" "Docker is working correctly"
    else
        print_status "error" "Docker verification failed"
        exit 1
    fi
    
    check_version "docker" "Docker"
    
    update_progress "Docker Installation"
}

configure_firewall() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 3: Firewall Configuration                             │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    print_status "progress" "Installing UFW firewall..."
    apt-get install -y -qq ufw >> "$LOG_FILE" 2>&1
    
    print_status "progress" "Configuring firewall rules..."
    
    ufw allow 22/tcp >> "$LOG_FILE" 2>&1
    print_status "success" "SSH (port 22) allowed"
    
    ufw allow 80/tcp >> "$LOG_FILE" 2>&1
    print_status "success" "HTTP (port 80) allowed"
    
    ufw allow 443/tcp >> "$LOG_FILE" 2>&1
    print_status "success" "HTTPS (port 443) allowed"
    
    echo "y" | ufw enable >> "$LOG_FILE" 2>&1
    print_status "success" "Firewall enabled"
    
    update_progress "Firewall Configuration"
}

install_reverse_proxy() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 4: Reverse Proxy Installation                         │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    if [ "$USE_CADDY" = true ]; then
        install_caddy
    else
        install_nginx
    fi
    
    update_progress "Reverse Proxy Installation"
}

install_nginx() {
    print_status "progress" "Installing Nginx..."
    apt-get install -y -qq nginx >> "$LOG_FILE" 2>&1
    print_status "success" "Nginx installed"
    
    print_status "progress" "Installing Certbot for SSL..."
    apt-get install -y -qq certbot python3-certbot-nginx >> "$LOG_FILE" 2>&1
    print_status "success" "Certbot installed"
    
    print_status "progress" "Configuring Nginx for n8n..."

    cat > /etc/nginx/sites-available/n8n << NGINX_EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:${N8N_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_buffering off;
        client_max_body_size 0;
    }
}
NGINX_EOF

    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    if nginx -t >> "$LOG_FILE" 2>&1; then
        print_status "success" "Nginx configuration valid"
    else
        print_status "error" "Nginx configuration error"
        exit 1
    fi
    
    systemctl restart nginx
    systemctl enable nginx
    print_status "success" "Nginx started and enabled"
}

install_caddy() {
    print_status "progress" "Installing Caddy..."
    
    apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl >> "$LOG_FILE" 2>&1
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
    apt-get update -qq >> "$LOG_FILE" 2>&1
    apt-get install -y -qq caddy >> "$LOG_FILE" 2>&1
    print_status "success" "Caddy installed"
    
    print_status "progress" "Configuring Caddy for n8n..."
    
    cat > /etc/caddy/Caddyfile << CADDY_EOF
${DOMAIN} {
    reverse_proxy localhost:${N8N_PORT}
    encode gzip
}
CADDY_EOF

    mkdir -p /var/log/caddy
    
    systemctl restart caddy
    systemctl enable caddy
    print_status "success" "Caddy started and enabled"
}

obtain_ssl_certificate() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 5: SSL Certificate                                    │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    if [ "$USE_CADDY" = true ]; then
        print_status "info" "Caddy will automatically obtain SSL certificates"
        print_status "success" "SSL configuration complete (automatic)"
    else
        print_status "progress" "Obtaining SSL certificate from Let's Encrypt..."
        
        if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect >> "$LOG_FILE" 2>&1; then
            print_status "success" "SSL certificate obtained successfully"
        else
            print_status "warning" "SSL certificate failed - you can try later with: certbot --nginx -d $DOMAIN"
        fi

        (crontab -l 2>/dev/null | grep -v certbot; echo "0 3 * * * certbot renew --quiet") | crontab - 2>/dev/null
        print_status "success" "Auto-renewal configured"
    fi
    
    update_progress "SSL Certificate"
}

create_n8n_directory() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 6: Create n8n Directory Structure                     │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    print_status "progress" "Creating n8n directory..."
    mkdir -p "$N8N_DIR"
    mkdir -p "$N8N_DIR/data"
    mkdir -p "$N8N_DIR/postgres-data"
    mkdir -p "$N8N_DIR/backup"
    print_status "success" "Directory created: $N8N_DIR"
    
    update_progress "Directory Structure"
}

create_docker_compose() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 7: Create Docker Compose Configuration                │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    print_status "progress" "Creating docker-compose.yml..."
    
    cat > "$N8N_DIR/docker-compose.yml" << COMPOSE_EOF
# n8n Docker Compose Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

services:
  postgres:
    image: postgres:${POSTGRES_VERSION}
    container_name: n8n-postgres
    restart: always
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h localhost -U n8n -d n8n"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - n8n-network

  n8n:
    image: ${N8N_IMAGE}
    container_name: n8n
    restart: always
    ports:
      - "${N8N_PORT}:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${DOMAIN}/
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - GENERIC_TIMEZONE=${TIMEZONE}
      - TZ=${TIMEZONE}
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_MAX_AGE=168
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - n8n-network

volumes:
  postgres_data:
  n8n_data:

networks:
  n8n-network:
    driver: bridge
COMPOSE_EOF

    print_status "success" "docker-compose.yml created"

    print_status "progress" "Creating .env file..."
    cat > "$N8N_DIR/.env" << ENV_EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
DOMAIN=${DOMAIN}
ENV_EOF
    
    chmod 600 "$N8N_DIR/.env"
    print_status "success" ".env file created"
    
    update_progress "Docker Compose"
}

start_n8n() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 8: Start n8n Containers                               │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    cd "$N8N_DIR"
    
    print_status "progress" "Pulling Docker images..."
    docker compose pull >> "$LOG_FILE" 2>&1
    print_status "success" "Docker images pulled"
    
    print_status "progress" "Starting n8n containers..."
    docker compose up -d >> "$LOG_FILE" 2>&1
    print_status "success" "Containers started"

    print_status "progress" "Waiting for services to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$N8N_PORT" 2>/dev/null | grep -qE "200|301|302"; then
            break
        fi
        sleep 2
        attempt=$((attempt + 1))
        echo -ne "\r  Waiting... (${attempt}/${max_attempts})  "
    done
    echo ""
    
    if [ $attempt -eq $max_attempts ]; then
        print_status "warning" "Services may still be starting up"
    else
        print_status "success" "Services are ready"
    fi
    
    echo ""
    docker compose ps
    echo ""
    
    update_progress "Start Containers"
}

verify_installation() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 9: Verify Installation                                │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"

    print_status "progress" "Checking Docker containers..."
    if docker ps | grep -q "n8n"; then
        print_status "success" "n8n container is running"
    else
        print_status "error" "n8n container is not running"
    fi
    
    if docker ps | grep -q "postgres"; then
        print_status "success" "PostgreSQL container is running"
    else
        print_status "error" "PostgreSQL container is not running"
    fi

    if [ "$USE_CADDY" = true ]; then
        if systemctl is-active --quiet caddy; then
            print_status "success" "Caddy is running"
        else
            print_status "error" "Caddy is not running"
        fi
    else
        if systemctl is-active --quiet nginx; then
            print_status "success" "Nginx is running"
        else
            print_status "error" "Nginx is not running"
        fi
    fi

    print_status "progress" "Checking HTTPS connectivity..."
    sleep 3
    local https_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" 2>/dev/null)
    if [ "$https_code" = "200" ] || [ "$https_code" = "301" ] || [ "$https_code" = "302" ]; then
        print_status "success" "HTTPS is working"
    else
        print_status "warning" "HTTPS check returned $https_code (may need DNS propagation)"
    fi
    
    update_progress "Verification"
}

display_summary() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│  Step 10: Installation Complete!                            │${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────────────┘${NC}"
    
    update_progress "Complete"
    
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}${WHITE}🎉 n8n Installation Completed Successfully! 🎉${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BOLD}Access Information:${NC}"
    echo -e "  URL:        ${BOLD}${CYAN}https://$DOMAIN${NC}"
    echo -e "  Local URL:  http://localhost:$N8N_PORT"
    echo ""
    
    echo -e "${BOLD}Credentials (SAVE THESE!):${NC}"
    echo -e "  PostgreSQL Password: ${DIM}$POSTGRES_PASSWORD${NC}"
    echo -e "  Encryption Key:      ${DIM}$N8N_ENCRYPTION_KEY${NC}"
    echo ""
    
    echo -e "${BOLD}File Locations:${NC}"
    echo -e "  n8n Directory:   $N8N_DIR"
    echo -e "  Docker Compose:  $N8N_DIR/docker-compose.yml"
    echo -e "  Log file:        $LOG_FILE"
    echo ""
    
    echo -e "${BOLD}Useful Commands:${NC}"
    echo -e "  ${CYAN}# View logs${NC}"
    echo -e "  docker logs -f n8n"
    echo ""
    echo -e "  ${CYAN}# Restart n8n${NC}"
    echo -e "  cd $N8N_DIR && docker compose restart"
    echo ""
    echo -e "  ${CYAN}# Update n8n${NC}"
    echo -e "  cd $N8N_DIR && docker compose pull && docker compose up -d"
    echo ""

    cat > "$N8N_DIR/credentials.txt" << CREDS_EOF
# n8n Installation Credentials
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

URL: https://$DOMAIN
PostgreSQL Password: $POSTGRES_PASSWORD
Encryption Key: $N8N_ENCRYPTION_KEY
CREDS_EOF
    chmod 600 "$N8N_DIR/credentials.txt"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}Next Steps:${NC}"
    echo -e "  1. Open ${CYAN}https://$DOMAIN${NC} in your browser"
    echo -e "  2. Create your admin account"
    echo -e "  3. Start automating!"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# MAIN FUNCTION
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== n8n Installation Log ===" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    
    print_banner

    check_root
    check_os
    check_resources
    check_existing_installations

    get_user_input
    
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}              Starting Installation                           ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    system_update
    install_docker
    configure_firewall
    install_reverse_proxy
    obtain_ssl_certificate
    create_n8n_directory
    create_docker_compose
    start_n8n
    verify_installation
    display_summary
    
    echo "Installation completed: $(date)" >> "$LOG_FILE"
}

trap 'echo ""; print_status "warning" "Installation interrupted"; exit 1' INT

main "$@"
