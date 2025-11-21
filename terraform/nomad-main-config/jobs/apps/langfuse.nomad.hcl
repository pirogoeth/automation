variable "version" {
  type = string
}

variable "domain" {
  type = string
}

variable "mailgun_smtp_username" {
  type = string
}

variable "mailgun_smtp_password" {
  type = string
}

job "langfuse" {
  type        = "service"
  namespace   = "apps"
  datacenters = ["dc1"]

  node_pool = "default"

  update {
    max_parallel      = 1
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    canary            = 0
  }

  group "app" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 3000
      }
    }

    task "langfuse" {
      driver = "docker"

      config {
        image      = "docker.io/langfuse/langfuse:${var.version}"
        force_pull = true

        ports = ["http"]

        labels {
          appname                  = "langfuse"
          component                = "server"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }
      }

      env {
        DATABASE_URL                          = "postgresql://langfuse:langfuse@localhost:5432/langfuse"
        NEXTAUTH_SECRET                       = "mysecret"
        SALT                                  = "mysalt"
        NEXTAUTH_URL                          = "https://langfuse.${var.domain}"
        TELEMETRY_ENABLED                     = "true"
        LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES = "true"
        SMTP_CONNECTION_URL                   = "smtps://${var.mailgun_smtp_username}:${var.mailgun_smtp_password}@smtp.mailgun.org:465"
        EMAIL_FROM_ADDRESS                    = var.mailgun_smtp_username
        AUTH_DISABLE_SIGNUP                   = "false"
      }

      service {
        name     = "langfuse-http"
        port     = "http"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.langfuse.rule=Host(`langfuse.${var.domain}`)",
          "traefik.http.routers.langfuse.entrypoints=web-secure",
          "traefik.http.routers.langfuse.tls=true",
          "traefik.http.services.langfuse.loadbalancer.passhostheader=true",
        ]

        check {
          type     = "http"
          path     = "/api/public/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu        = 256
        memory     = 512
        memory_max = 2048
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image      = "postgres:15-alpine"
        force_pull = true

        volumes = [
          "/data/langfuse-db-postgres:/var/lib/postgresql/data"
        ]
      }

      env {
        POSTGRES_USER     = "langfuse"
        POSTGRES_PASSWORD = "langfuse"
        POSTGRES_DB       = "langfuse"
      }

      resources {
        cpu    = 256
        memory = 256
      }
    }
  }
}

