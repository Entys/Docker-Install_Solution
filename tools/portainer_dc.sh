#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

PORTAINER_DIR="/opt/portainer"
PORTAINER_HTTP_PORT=9000
PORTAINER_HTTPS_PORT=9443
LOG_FILE="/tmp/portainer_install.log"

show_success() {
    echo -e "${GREEN}${BOLD} $1${NC}"
}

show_error() {
    echo -e "${RED}${BOLD} $1${NC}"
}

show_info() {
    echo -e "${YELLOW}${BOLD} $1${NC}"
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        show_error "This script must be run with root privileges (sudo)"
        exit 1
    fi
}

check_portainer_installed() {
    show_info "Checking for existing Portainer installation..."
    
    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        show_error "Portainer container already exists"
        echo -e "${YELLOW}Would you like to remove it and reinstall? [y/N]${NC}"
        read -p "> " choice < /dev/tty
        
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            show_info "Removing existing Portainer..."
            docker stop portainer >> "$LOG_FILE" 2>&1
            docker rm portainer >> "$LOG_FILE" 2>&1
            show_success "Existing Portainer removed"
        else
            show_info "Installation cancelled"
            exit 0
        fi
    fi
    
    show_success "No existing Portainer found"
    log "Portainer check completed"
}

check_port_available() {
    local port=$1
    if ss -tuln | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

prompt_custom_port() {
    local port_name=$1
    local default_port=$2
    local custom_port
    
    while true; do
        echo -e "${YELLOW}Port ${default_port} is in use. Enter a custom port for ${port_name}:${NC}"
        read -p "> " custom_port < /dev/tty
        
        if [[ ! "$custom_port" =~ ^[0-9]+$ ]] || [ "$custom_port" -lt 1024 ] || [ "$custom_port" -gt 65535 ]; then
            show_error "Invalid port. Please enter a number between 1024 and 65535"
            continue
        fi
        
        if check_port_available "$custom_port"; then
            echo "$custom_port"
            return 0
        else
            show_error "Port ${custom_port} is also in use. Try another port"
        fi
    done
}

check_ports() {
    show_info "Checking port availability..."
    
    if ! check_port_available "$PORTAINER_HTTP_PORT"; then
        show_info "Port ${PORTAINER_HTTP_PORT} (HTTP) is in use"
        PORTAINER_HTTP_PORT=$(prompt_custom_port "HTTP" "$PORTAINER_HTTP_PORT")
        log "Custom HTTP port selected: $PORTAINER_HTTP_PORT"
    fi
    
    if ! check_port_available "$PORTAINER_HTTPS_PORT"; then
        show_info "Port ${PORTAINER_HTTPS_PORT} (HTTPS) is in use"
        PORTAINER_HTTPS_PORT=$(prompt_custom_port "HTTPS" "$PORTAINER_HTTPS_PORT")
        log "Custom HTTPS port selected: $PORTAINER_HTTPS_PORT"
    fi
    
    show_success "Ports available: HTTP=${PORTAINER_HTTP_PORT}, HTTPS=${PORTAINER_HTTPS_PORT}"
}

create_docker_compose() {
    show_info "Creating Portainer configuration..."
    
    mkdir -p "$PORTAINER_DIR"
    
    cat > "${PORTAINER_DIR}/docker-compose.yml" << EOF
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    ports:
      - "${PORTAINER_HTTP_PORT}:9000"
      - "${PORTAINER_HTTPS_PORT}:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    environment:
      - TZ=Europe/Paris

volumes:
  portainer_data:
    name: portainer_data
EOF
    
    if [ $? -eq 0 ]; then
        show_success "Docker Compose configuration created"
        log "Docker Compose file created at ${PORTAINER_DIR}/docker-compose.yml"
    else
        show_error "Failed to create Docker Compose configuration"
        log "Failed to create docker-compose.yml"
        exit 1
    fi
}

install_portainer() {
    show_info "Installing Portainer..."
    
    cd "$PORTAINER_DIR" || exit 1
    
    docker compose pull >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        show_error "Failed to pull Portainer image"
        log "Docker image pull failed"
        exit 1
    fi
    
    docker compose up -d >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        show_success "Portainer started successfully"
        log "Portainer container started"
    else
        show_error "Failed to start Portainer"
        log "Docker compose up failed"
        exit 1
    fi
}

verify_installation() {
    show_info "Verifying Portainer installation..."
    
    sleep 3
    
    if docker ps | grep -q "portainer"; then
        show_success "Portainer is running"
        log "Portainer verification successful"
        return 0
    else
        show_error "Portainer container is not running"
        log "Portainer verification failed"
        return 1
    fi
}

get_server_ip() {
    local ip
    ip=$(hostname -I | awk '{print $1}')
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    echo "$ip"
}

show_summary() {
    local server_ip=$(get_server_ip)
    
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}║           PORTAINER INSTALLATION COMPLETE!                    ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Access Information:${NC}"
    echo -e "${CYAN}  HTTP:  ${WHITE}http://${server_ip}:${PORTAINER_HTTP_PORT}${NC}"
    echo -e "${CYAN}  HTTPS: ${WHITE}https://${server_ip}:${PORTAINER_HTTPS_PORT}${NC}"
    echo ""
    echo -e "${YELLOW}${BOLD}Important:${NC}"
    echo -e "${YELLOW}  - First user to login will create the admin account${NC}"
    echo -e "${YELLOW}  - Choose a strong password (min 12 characters)${NC}"
    echo -e "${YELLOW}  - Access expires after 5 minutes if not configured${NC}"
    echo ""
    echo -e "${BLUE}Configuration file: ${PORTAINER_DIR}/docker-compose.yml${NC}"
    echo -e "${BLUE}Log file: ${LOG_FILE}${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Useful commands:${NC}"
    echo -e "${CYAN}  docker logs portainer${NC}           # View logs"
    echo -e "${CYAN}  cd ${PORTAINER_DIR} && docker compose restart${NC}  # Restart"
    echo -e "${CYAN}  cd ${PORTAINER_DIR} && docker compose down${NC}     # Stop"
    echo ""
}

main() {
    log "Portainer installation started"
    
    check_root
    check_portainer_installed
    check_ports
    create_docker_compose
    install_portainer
    
    if verify_installation; then
        show_summary
        log "Portainer installation completed successfully"
    else
        show_error "Installation verification failed. Check logs: ${LOG_FILE}"
        log "Installation failed"
        exit 1
    fi
}

trap 'show_error "Installation interrupted by user"; exit 1' INT TERM

main "$@"