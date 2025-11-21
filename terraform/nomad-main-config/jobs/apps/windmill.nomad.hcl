variable "domain" {
  type = string
}

variable "postgres_version" {
  type    = string
  default = "16"
}

job "windmill" {
  type        = "service"
  region      = "global"
  datacenters = ["dc1"]
  priority    = 60
  namespace   = "apps"

  node_pool = "default"

  group "db" {
    count = 1

    network {
      mode = "bridge"

      port "postgres" {
        to = 5432
      }
    }

    task "postgres" {
      driver = "docker"

      config {
        image      = "postgres:${var.postgres_version}"
        force_pull = true

        ports = ["postgres"]

        volumes = [
          "/data/windmill-db-postgres:/var/lib/postgresql/data",
        ]
      }

      env {
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "postgres"
        POSTGRES_DB       = "data"
      }

      resources {
        cpu    = 256
        memory = 256
      }

      service {
        name     = "windmill-postgres"
        port     = "postgres"
        provider = "nomad"
      }
    }
  }

  group "app" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 8000
      }
    }

    task "windmill-server" {
      driver = "docker"

      config {
        image              = "ghcr.io/windmill-labs/windmill:main"
        image_pull_timeout = "15m"
        force_pull         = true

        ports = ["http"]
      }

      env {
        MODE = "server"
      }

      template {
        destination = "local/env"
        change_mode = "restart"
        env         = true

        data = <<EOH
{{range nomadService "windmill-postgres"}}
DATABASE_URL=postgres://postgres:postgres@{{.Address}}:{{.Port}}/data?sslmode=disable
{{end}}
EOH
      }

      resources {
        cpu    = 512
        memory = 2048
      }

      service {
        port     = "http"
        provider = "nomad"
        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",

          "traefik.enable=true",
          "traefik.http.routers.windmill.rule=Host(`wm.${var.domain}`)",
          "traefik.http.routers.windmill.entrypoints=web-secure",
          "traefik.http.routers.windmill.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.windmill.tls.certresolver=letsencrypt",
        ]
      }
    }
  }

  group "worker-default" {
    count = 1

    task "worker" {
      driver = "docker"

      config {
        image              = "ghcr.io/windmill-labs/windmill:main"
        image_pull_timeout = "15m"
        force_pull         = true

        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "/data/windmill-worker-cache:/tmp/windmill/cache",
        ]
      }

      env {
        MODE         = "worker"
        WORKER_GROUP = "default"
      }

      template {
        destination = "local/env"
        change_mode = "restart"
        env         = true

        data = <<EOH
{{range nomadService "windmill-postgres"}}
DATABASE_URL=postgres://postgres:postgres@{{.Address}}:{{.Port}}/data?sslmode=disable
{{end}}
EOH
      }

      resources {
        cpu    = 512
        memory = 2048
      }
    }
  }

  group "worker-native" {
    count = 2

    task "worker" {
      driver = "docker"

      config {
        image              = "ghcr.io/windmill-labs/windmill:main"
        image_pull_timeout = "15m"
        force_pull         = true
      }

      env {
        MODE         = "worker"
        WORKER_GROUP = "native"
      }

      template {
        destination = "local/env"
        change_mode = "restart"
        env         = true

        data = <<EOH
{{range nomadService "windmill-postgres"}}
DATABASE_URL=postgres://postgres:postgres@{{.Address}}:{{.Port}}/data?sslmode=disable
{{end}}
EOH
      }

      resources {
        cpu    = 128
        memory = 256
      }
    }
  }

  group "worker-reports" {
    count = 1

    task "worker" {
      driver = "docker"

      config {
        image              = "ghcr.io/windmill-labs/windmill:main"
        image_pull_timeout = "15m"
        force_pull         = true

        volumes = [
          "/data/windmill-worker-cache:/tmp/windmill/cache",
        ]
      }

      env {
        MODE         = "worker"
        WORKER_GROUP = "reports"
      }

      template {
        destination = "local/env"
        change_mode = "restart"
        env         = true

        data = <<EOH
{{range nomadService "windmill-postgres"}}
DATABASE_URL=postgres://postgres:postgres@{{.Address}}:{{.Port}}/data?sslmode=disable
{{end}}
EOH
      }

      resources {
        cpu    = 256
        memory = 2048
      }
    }
  }

  group "lsp" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 3001
      }
    }

    task "lsp" {
      driver = "docker"

      config {
        image              = "ghcr.io/windmill-labs/windmill-lsp:main"
        image_pull_timeout = "15m"
        force_pull         = true

        ports = ["http"]

        volumes = [
          "/data/windmill-lsp-cache:/root/.cache",
        ]
      }

      resources {
        cpu    = 128
        memory = 1024
      }

      service {
        port     = "http"
        provider = "nomad"
        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",

          "traefik.enable=true",
          "traefik.http.routers.windmill-lsp.rule=Host(`wm.${var.domain}`) && PathPrefix(`/ws/`)",
          "traefik.http.routers.windmill-lsp.entrypoints=web-secure",
          "traefik.http.routers.windmill-lsp.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.windmill-lsp-secure.tls.certresolver=letsencrypt",
        ]
      }
    }
  }
}
