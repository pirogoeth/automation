variable "namespace" {
  type = string
}

variable "version" {
  type = string
}

variable "domain" {
  type = string
}

job "changedetection" {
  namespace   = var.namespace
  datacenters = ["dc1"]
  type        = "service"

  group "app" {
    count = 1

    network {
      port "http" {
        to = 3000
      }
    }

    task "changedetection" {
      driver = "docker"

      config {
        image      = "ghcr.io/dgtlmoon/changedetection.io:${var.version}"
        force_pull = true

        ports = ["http"]

        labels {
          appname = "changedetection"
        }

        volumes = [
          "/data/changedetection-data:/datastore",
        ]
      }

      env {
        PORT          = NOMAD_PORT_http
        BASE_URL      = "https://changedet.${var.domain}"
        HIDE_REFERER  = "true"
        FETCH_WORKERS = 10
      }

      template {
        destination = "local/env"
        change_mode = "restart"
        env         = true

        data = <<EOF
{{$allocID := env "NOMAD_ALLOC_ID" -}}
{{range nomadService 1 $allocID "changedetection-browser-sockpuppet"}}
PLAYWRIGHT_DRIVER_URL=ws://{{.Address}}:{{.Port}}
{{end}}
EOF
      }

      resources {
        cpu    = 256
        memory = 256
      }

      service {
        port     = "http"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.changedetection.rule=Host(`changedet.${var.domain}`)",
          "traefik.http.routers.changedetection.entrypoints=web-secure",
          "traefik.http.routers.changedetection.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.changedetection-secure.tls.certresolver=letsencrypt",
        ]
      }
    }
  }

  group "browser" {
    count = 1

    network {
      port "playwright" {
        to = 3000
      }

      port "sockpuppet" {
        to = 3000
      }
    }

    task "sockpuppet" {
      driver = "docker"

      env {
        SCREEN_WIDTH                    = 1920
        SCREEN_HEIGHT                   = 1024
        SCREEN_DEPTH                    = 16
        MAX_CONCURRENT_CHROME_PROCESSES = 10
      }

      config {
        image = "dgtlmoon/sockpuppetbrowser:latest"
        ports = ["sockpuppet"]
        # cap_add = ["SYS_ADMIN"]
      }

      resources {
        cpu        = 512
        memory     = 1024
        memory_max = 4096
      }

      service {
        port     = "sockpuppet"
        provider = "nomad"
      }
    }
  }
}
