# Swarm Traefik Ingress Role

A comprehensive Ansible role for deploying Traefik with traefik-kop service discovery on Docker Swarm.

## Architecture

- **Redis**: Centralized configuration store (manager node)
- **Traefik**: Load balancer with Redis provider (manager node)  
- **Traefik-kop**: Service discovery agent (global - all nodes)

## Features

- 🔄 **Dynamic service discovery** via traefik-kop
- 🛡️ **Let's Encrypt certificates** with Cloudflare DNS challenge
- 🌐 **Dynamic Cloudflare CIDR fetching** (no hardcoded IPs!)
- 📊 **Prometheus metrics** endpoint
- 🎛️ **Traefik dashboard** with self-service configuration
- 🔧 **Templated middlewares** for security policies

## Requirements

- Docker Swarm cluster
- Ansible collections:
  - `community.docker >= 3.0.0`
  - `ansible.posix >= 1.0.0`

## Role Variables

### Required Variables

```yaml
traefik_domain: "your-domain.com"
traefik_acme_email: "admin@your-domain.com"
traefik_acme_cloudflare_email: "your-email@cloudflare.com"
traefik_acme_cloudflare_apikey: "your-global-api-key"
```

### Optional Variables

```yaml
# Stack configuration
swarm_traefik_ingress_stack_name: "swarm-traefik-ingress"

# Cloudflare CIDR fetching
cloudflare_fetch_cidrs: true  # Fetch live CIDRs from Cloudflare
cloudflare_trusted_cidrs: []  # Fallback static list

# Middleware toggles
traefik_enable_fail2ban_middleware: true
traefik_enable_cloudflare_middleware: true

# Resource limits
redis_memory_limit: "512M"
traefik_memory_limit: "512M"
traefik_kop_memory_limit: "128M"
```

## Usage

### Basic Playbook

```yaml
---
- hosts: swarm_managers
  become: true
  roles:
    - swarm-traefik-ingress
  vars:
    traefik_domain: "example.com"
    traefik_acme_email: "admin@example.com"
    traefik_acme_cloudflare_email: "cf@example.com"
    traefik_acme_cloudflare_apikey: "{{ vault_cloudflare_api_key }}"
```

### Service Configuration

Services can be exposed through traefik-kop using standard Traefik labels:

```yaml
services:
  my-app:
    image: nginx:alpine
    deploy:
      labels:
        - traefik.enable=true
        - traefik.http.routers.my-app.rule=Host(`app.example.com`)
        - traefik.http.routers.my-app.entrypoints=web-secure
        - traefik.http.routers.my-app.tls=true
        - traefik.http.routers.my-app.tls.certresolver=letsencrypt-prod
        - traefik.http.services.my-app.loadbalancer.server.port=80
    networks:
      - ingress_ingress
```

## Troubleshooting

### Common Issues

1. **Cloudflare API rate limits**: Set `cloudflare_fetch_cidrs: false` and provide static CIDRs
2. **Let's Encrypt staging**: The role uses staging by default for the `letsencrypt` resolver
3. **Network connectivity**: Ensure overlay networks are properly configured

### Debugging

```bash
# Check stack status
docker stack ps swarm-traefik-ingress

# View traefik logs
docker service logs swarm-traefik-ingress_traefik

# Check Redis keys
docker exec $(docker ps -q -f name=redis) redis-cli --scan

# Traefik dashboard
curl -H "Host: traefik.your-domain.com" http://localhost:8889/dashboard/
```

## License

MIT