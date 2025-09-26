# Docker Automatic Installer

A sleek, zero-interaction bash script that installs Docker and Docker Compose on any Linux distribution with a beautiful interface.

## Installation

Get the latest release: https://github.com/Entys/Docker-Install_Solution/releases

```bash
curl -sSL https://github.com/Entys/Docker-Install_Solution/releases/download/v1.1/docker_install.sh | sudo bash
```

Or manually:

```bash
wget https://github.com/Entys/Docker-Install_Solution/releases/download/v1.1/docker_install.sh
chmod +x docker_install.sh
sudo ./docker_install.sh
```

## Supported Systems

Ubuntu, Debian, CentOS, RHEL, Fedora

Arch Linux - comming soon!

## What it does

- Detects your Linux distribution automatically
- Installs Docker Engine and Docker Compose
- Configures services and user permissions
- Tests the installation with hello-world
- Provides a complete installation summary

## Post-installation

Log out and back in to use Docker without sudo, or run:
```bash
newgrp docker
```

Test your installation:
```bash
docker run hello-world
```

## Logs

Installation logs are saved to `/tmp/docker_install.log`

## Coming Soon

**Version 2.0** will include an interactive menu to install popular development stacks:

- **Web Stacks**: LAMP, LEMP, MEAN, MERN
- **Databases**: PostgreSQL, MySQL, MongoDB with admin panels  
- **Tools**: Portainer, Traefik, GitLab, Jenkins
- **Monitoring**: Prometheus+Grafana, ELK Stack

```bash
./docker_install.sh --menu
```
