#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

ARROW="➤"

clear_screen() {
    if command -v clear &> /dev/null; then
        clear
    else
        printf "\033[2J\033[H"
    fi
}

DOCKER_COMPOSE_VERSION="2.24.0"
LOG_FILE="/tmp/docker_install.log"

show_banner() {
    clear_screen
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                               ║"
    echo "║                         AUTOMATIC DOCKER INSTALLER                            ║"
    echo "║                                                                               ║"
    echo "║                          Docker + Docker Compose                              ║"
    echo "║                                Made-Entys                                     ║"
    echo "║                                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_step() {
    local step_num=$1
    local step_desc=$2
    echo -e "${BLUE}${BOLD}${ARROW} Step ${step_num}: ${step_desc}${NC}"
    echo ""
}

show_success() {
    echo -e "${GREEN}${BOLD} $1${NC}"
}

show_error() {
    echo -e "${RED}${BOLD} $1${NC}"
}

show_info() {
    echo -e "${YELLOW}${BOLD} $1${NC}"
}

show_progress() {
    local current=$1
    local total=$2
    local desc=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}[${NC}"
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "${CYAN}] ${percent}%% - ${desc}${NC}"
}

wait_with_animation() {
    local duration=$1
    local message=$2
    local i=0
    local spin='/-\|'
    
    while [ $i -lt $duration ]; do
        printf "\r${YELLOW}${spin:i%4:1} ${message}${NC}"
        sleep 0.1
        ((i++))
    done
    printf "\r"
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

detect_distro() {
    show_info "Detecting Linux distribution..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="centos"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    else
        show_error "Unsupported distribution!"
        exit 1
    fi
    
    show_success "Distribution detected: $DISTRO $VERSION"
    log "Distribution detected: $DISTRO $VERSION"
    sleep 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        show_error "This script must be run with root privileges (sudo)"
        exit 1
    fi
    show_success "Administrator privileges confirmed"
}

check_existing_docker() {
    local docker_installed=false
    local compose_installed=false
    local docker_running=false
    
    show_info "Checking for existing Docker installation..."
    
    if command -v docker &> /dev/null; then
        docker_installed=true
        show_success "Docker found: $(docker --version 2>/dev/null || echo 'version unavailable')"
    fi
    
    if docker compose version &> /dev/null || command -v docker-compose &> /dev/null; then
        compose_installed=true
        if docker compose version &> /dev/null; then
            show_success "Docker compose found: $(docker compose version --short 2>/dev/null)"
        else
            show_success "Docker Compose found: $(docker-compose --version 2>/dev/null)"
        fi
    fi
    
    if systemctl is-active --quiet docker 2>/dev/null; then
        docker_running=true
        show_success "Docker service is running"
    fi
    
    if $docker_installed && $compose_installed && $docker_running; then
        echo ""
        show_info "Docker appear to be fully installed and running"
        echo ""
        echo -e "${YELLOW}Options:${NC}"
        echo -e "${CYAN}  [1]${NC} Continue anyway (reinstall/update)"
        echo -e "${CYAN}  [2]${NC} Exit"
        echo ""
        
        while true; do
            read -p "Choose an option [1-2]: " choice
            case $choice in
                1)
                    show_info "Proceeding with installation..."
                    return 0
                    ;;
                2)
                    show_info "Exiting..."
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Nop. Please enter 1 or 2.${NC}"
                    ;;
            esac
        done
    else
        if $docker_installed || $compose_installed; then
            show_info "Partial Docker installation detected. Proceeding with full installation..."
        fi
        return 0
    fi
}

update_system() {
    show_info "Updating system..."
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update -y >> "$LOG_FILE" 2>&1
            apt-get upgrade -y >> "$LOG_FILE" 2>&1
            ;;
        centos|rhel)
            yum update -y >> "$LOG_FILE" 2>&1
            ;;
        fedora)
            dnf update -y >> "$LOG_FILE" 2>&1
            ;;
        arch)
            pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    show_success "System updated"
}

install_dependencies() {
    show_info "Installing dependencies..."
    
    case $DISTRO in
        ubuntu|debian)
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                software-properties-common >> "$LOG_FILE" 2>&1
            ;;
        centos|rhel)
            yum install -y \
                yum-utils \
                device-mapper-persistent-data \
                lvm2 \
                curl >> "$LOG_FILE" 2>&1
            ;;
        fedora)
            dnf install -y \
                dnf-plugins-core \
                curl >> "$LOG_FILE" 2>&1
            ;;
        arch)
            pacman -S --noconfirm \
                curl \
                ca-certificates >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    show_success "Dependencies installed"
}

add_docker_repo() {
    show_info "Adding official Docker repository..."
    
    case $DISTRO in
        ubuntu|debian)
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update >> "$LOG_FILE" 2>&1
            ;;
        centos|rhel)
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1
            ;;
        fedora)
            dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo >> "$LOG_FILE" 2>&1
            ;;
        arch)
            # TODO
            ;;
    esac
    
    show_success "Docker repository added"
}

install_docker() {
    show_info "Installing Docker Engine..."
    
    case $DISTRO in
        ubuntu|debian)
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin >> "$LOG_FILE" 2>&1
            ;;
        centos|rhel|fedora)
            if [[ $DISTRO == "fedora" ]]; then
                dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin >> "$LOG_FILE" 2>&1
            else
                yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin >> "$LOG_FILE" 2>&1
            fi
            ;;
        arch)
            pacman -S --noconfirm docker docker-compose >> "$LOG_FILE" 2>&1
            ;;
    esac
    
    show_success "Docker Engine installed"
}

install_docker_compose() {
    if [[ $DISTRO != "arch" ]]; then
        show_info "Installing Docker Compose..."
        
        case $DISTRO in
            ubuntu|debian)
                apt-get install -y docker-compose-plugin >> "$LOG_FILE" 2>&1
                ;;
            centos|rhel|fedora)
                if [[ $DISTRO == "fedora" ]]; then
                    dnf install -y docker-compose-plugin >> "$LOG_FILE" 2>&1
                else
                    yum install -y docker-compose-plugin >> "$LOG_FILE" 2>&1
                fi
                ;;
        esac
        
        if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
            show_info "Manual Docker Compose installation..."
            curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
            chmod +x /usr/local/bin/docker-compose
            ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
        
        show_success "Docker Compose installed"
    fi
}

configure_docker() {
    show_info "Configuring Docker..."
    
    systemctl enable docker >> "$LOG_FILE" 2>&1
    systemctl start docker >> "$LOG_FILE" 2>&1
    
    if [[ -n $SUDO_USER ]]; then
        usermod -aG docker $SUDO_USER >> "$LOG_FILE" 2>&1
        show_success "User $SUDO_USER added to docker group"
    fi
    
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    systemctl restart docker >> "$LOG_FILE" 2>&1
    show_success "Docker configured and started"
}

test_installation() {
    show_info "Testing installation..."
    
    if docker --version >> "$LOG_FILE" 2>&1; then
        show_success "Docker working: $(docker --version)"
    else
        show_error "Problem with Docker"
        return 1
    fi
    
    if docker compose version >> "$LOG_FILE" 2>&1; then
        show_success "Docker Compose (plugin) working: $(docker compose version --short)"
    elif docker-compose --version >> "$LOG_FILE" 2>&1; then
        show_success "Docker Compose working: $(docker-compose --version)"
    else
        show_error "Problem with Docker Compose"
        return 1
    fi
    
    show_info "Testing with hello-world container..."
    if docker run --rm hello-world >> "$LOG_FILE" 2>&1; then
        show_success "Hello-world test successful!"
    else
        show_error "Hello-world test failed"
        return 1
    fi
}

show_final_summary() {
    clear_screen
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                               ║"
    echo "║                           INSTALLATION COMPLETE!                              ║"
    echo "║                                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}INSTALLATION SUMMARY:${NC}"
    echo ""
    echo -e "${GREEN} Docker Engine installed and configured${NC}"
    echo -e "${GREEN} Docker Compose installed${NC}"
    echo -e "${GREEN} Docker services started and enabled${NC}"
    echo -e "${GREEN} Optimized configuration applied${NC}"
    echo -e "${GREEN} Functionality tests passed${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}USEFUL COMMANDS:${NC}"
    echo -e "${YELLOW}  docker --version${NC}                 # Check Docker version"
    echo -e "${YELLOW}  docker compose version${NC}           # Check Docker Compose"
    echo -e "${YELLOW}  docker run hello-world${NC}           # Test Docker"
    echo -e "${YELLOW}  docker ps${NC}                        # List containers"
    echo -e "${YELLOW}  systemctl status docker${NC}          # Docker service status"
    echo ""
    echo -e "${PURPLE}${BOLD}⚠️  IMPORTANT:${NC}"
    if [[ -n $SUDO_USER ]]; then
        echo -e "${YELLOW}  Log out and back in to use Docker without sudo${NC}"
        echo -e "${YELLOW}  Or run: newgrp docker${NC}"
    fi
    echo ""
    echo -e "${BLUE}Complete log: $LOG_FILE${NC}"
    echo -e "${GREEN}${BOLD} Docker is ready to use! ${NC}"
}

main() {
    show_banner
    log "Docker installation started"
    
    show_step "1" "Preliminary checks"
    check_root
    detect_distro
    check_existing_docker
    echo ""
    
    show_step "2" "System update"
    update_system
    show_progress 1 6 "Update completed"
    echo ""
    sleep 1
    
    show_step "3" "Dependencies installation"
    install_dependencies
    show_progress 2 6 "Dependencies installed"
    echo ""
    sleep 1
    
    show_step "4" "Docker repository configuration"
    add_docker_repo
    show_progress 3 6 "Repository configured"
    echo ""
    sleep 1
    
    show_step "5" "Docker installation"
    install_docker
    install_docker_compose
    show_progress 4 6 "Docker installed"
    echo ""
    sleep 1
    
    show_step "6" "Configuration and testing"
    configure_docker
    show_progress 5 6 "Configuration completed"
    echo ""
    sleep 1
    
    if test_installation; then
        show_progress 6 6 "Installation successful"
        echo ""
        sleep 2
        log "Installation completed successfully"
        show_final_summary
    else
        show_error "Installation failed. Check log: $LOG_FILE"
        log "Installation failed"
        exit 1
    fi
}

trap 'show_error "Installation interrupted by user"; exit 1' INT TERM

main "$@"