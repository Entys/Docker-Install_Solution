# Docker Tools and Solutions

Tools and solutions to extend and manage your Docker infrastructure.

---

## Table of Contents

### Management Tools
- [Portainer](#portainer) - Web interface to manage Docker

### Databases
- [PostgreSQL + pgAdmin](#postgresql--pgadmin) - RDBMS with admin panel (coming soon)
- [MySQL + PhpMyAdmin](#mysql--phpmyadmin) - MySQL with admin (coming soon)

### Complete Stacks
- [NPG Stack](#lamp-stack) - NodeExporter + Prometheus + Grafana (coming soon)

---

## Management Tools

### Portainer

Web interface for managing Docker and containers

Portainer CE is ideal for:
- Managing containers (create, run, stop, delete)
- View and manage Docker images
- Manage volumes and persistent data
- Configure Docker networks
- Monitor logs and resources
- Manage users and permissions
- Deploy Docker Compose stacks

Access: http://address_ip:9000

HTTPS Configuration:
```bash
# Option 1: Reverse proxy (Traefik/Nginx)
# Option 2: Self-signed certificate for testing
# Option 3: Let's Encrypt with certbot
```

Resources:
- Documentation: https://docs.portainer.io/
- GitHub Issues: https://github.com/portainer/portainer
- Community: https://github.com/portainer/portainer/discussions

---

## Databases

---

## Complete Stacks

---

## HTTPS and Certificates

By default, solutions run on HTTP.

### Option 1: Reverse proxy (Recommended)

Use a reverse proxy like Traefik or Nginx:
```bash
# Traefik handles HTTPS/Let's Encrypt automatically
# For all your services
```

### Option 2: Self-signed certificate

For local testing:
```bash
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout portainer.key \
  -out portainer.crt
```

### Option 3: Let's Encrypt manual

With certbot or other ACME client
