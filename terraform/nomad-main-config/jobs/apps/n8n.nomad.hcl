variable "version" {
  type = string
}

variable "domain" {
  type = string
}

job "n8n" {
  namespace   = "apps"
  type        = "service"
  datacenters = ["dc1"]

  update {
    stagger = "30s"
  }

  group "app" {
    count = 1

    network {
      port "http" {
        to = 5678
      }

      port "redis" {
        to = 6379
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image      = "docker.io/library/redis:7.2-alpine"
        force_pull = true

        args = [
          "--save", "60", "1",
          "--appendonly", "yes"
        ]

        ports = ["redis"]

        volumes = [
          "/data/n8n-redis:/data",
        ]
      }

      resources {
        cpu        = 128
        memory     = 128
        memory_max = 256
      }
    }

    task "n8n" {
      driver = "docker"

      config {
        image      = "ghcr.io/pirogoeth/container-images/n8n:${var.version}"
        force_pull = true

        ports = ["http"]

        labels {
          appname                  = "n8n"
          vector_stdout_parse_mode = "plain"
        }

        volumes = [
          "/data/n8n-data:/home/node/.n8n",
          "/data/n8n-local-files:/local-files",
        ]
      }

      env {
        N8N_LOG_LEVEL = "warn"
        N8N_PROTOCOL  = "https"
        N8N_HOST      = "n8n.${var.domain}"
        N8N_PORT      = "5678"
        N8N_PATH      = "/"
        NODE_ENV      = "production"
        WEBHOOK_URL   = "https://webhooks.${var.domain}/"
        # N8N_EDITOR_BASE_URL          = "https://n8n.${var.domain}/"
        GENERIC_TIMEZONE             = "Etc/UTC"
        N8N_DEFAULT_BINARY_DATA_MODE = "filesystem"
        NODE_FUNCTION_ALLOW_BUILTIN  = "*"
        NODE_FUNCTION_ALLOW_EXTERNAL = "*"
        N8N_METRICS                  = "true"
        QUEUE_HEALTH_CHECK_ACTIVE    = "true"
        N8N_TEMPLATES_ENABLED        = "true"
        N8N_RUNNERS_ENABLED          = "true"
      }

      resources {
        cpu        = 512
        memory     = 1024
        memory_max = 4096
      }

      service {
        port     = "http"
        provider = "nomad"

        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
          "prometheus.io/scrape_interval=15s",

          "traefik.enable=true",
          "traefik.http.routers.n8n.rule=Host(`n8n.${var.domain}`) && !(Path(`/healthz`) || Path(`/metrics`))",
          "traefik.http.routers.n8n.entrypoints=web,web-secure",
          "traefik.http.routers.n8n.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.n8n.tls.certresolver=letsencrypt",
          "traefik.http.routers.n8n.middlewares=n8n-headers,n8n-https-redirect",
          "traefik.http.routers.n8n.service=n8n",

          # "traefik.http.routers.n8n-meta.rule=Host(`n8n.${var.domain}`) && Path(`/healthz`, `/metrics`, `/healthz/readiness`)",
          # "traefik.http.routers.n8n-meta.entrypoints=web,web-secure",
          # "traefik.http.routers.n8n-meta.tls=true",
          # "traefik.http.routers.n8n-meta.service=n8n",
          # "traefik.http.routers.n8n-meta.middlewares=n8n-internal-headers,n8n-https-redirect",
          # "traefik.http.middlewares.n8n-internal-headers.headers.Host=webhooks.${var.domain}",

          "traefik.http.routers.n8n-webhooks.rule=Host(`webhooks.${var.domain}`)",
          "traefik.http.routers.n8n-webhooks.entrypoints=web-secure",
          "traefik.http.routers.n8n-webhooks.tls=true",
          "traefik.http.routers.n8n-webhooks.middlewares=cloudflare-tunnelled@file",
          "traefik.http.routers.n8n-webhooks.service=n8n",

          "traefik.http.services.n8n.loadbalancer.passhostheader=true",

          "traefik.http.routers.n8n-meta.middlewares=n8n-headers,n8n-https-redirect",
          "traefik.http.middlewares.n8n-https-redirect.redirectscheme.scheme=https",

          "traefik.http.middlewares.n8n-headers.headers.STSSeconds=315360000",
          "traefik.http.middlewares.n8n-headers.headers.browserXSSFilter=true",
          "traefik.http.middlewares.n8n-headers.headers.contentTypeNosniff=true",
          "traefik.http.middlewares.n8n-headers.headers.forceSTSHeader=true",
          "traefik.http.middlewares.n8n-headers.headers.STSIncludeSubdomains=true",
          "traefik.http.middlewares.n8n-headers.headers.STSPreload=true",
        ]

        check {
          type     = "http"
          path     = "/healthz"
          interval = "10s"
          timeout  = "2s"

          header {
            host = ["webhooks.${var.domain}"]
          }
        }
      }
    }
  }
}
