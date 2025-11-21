variable "version" {
  type = string
}

variable "domain" {
  type = string
}

variable "volume_name_downloads" {
  type = string
}

job "handbrake" {
  type        = "service"
  namespace   = "apps"
  datacenters = ["dc1"]

  node_pool = "gpu"

  group "app" {
    count = 1

    update {
      progress_deadline = "20m"
      healthy_deadline  = "15m"
      min_healthy_time  = "30s"
    }

    volume "downloads" {
      type            = "csi"
      read_only       = false
      source          = var.volume_name_downloads
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      mode = "bridge"
      port "http" {
        to = 5800
      }
    }

    task "handbrake" {
      driver = "docker"

      env {
        PUID                   = "297536"
        PGID                   = "297536"
        TZ                     = "America/Chicago"
        NVIDIA_VISIBLE_DEVICES = "all"
      }

      config {
        image   = "jlesage/handbrake:${var.version}"
        runtime = "nvidia"

        group_add = ["video"]

        ports = ["http"]

        devices = [
          {
            host_path = "/dev/dri"
          }
        ]

        volumes = [
          "/opt/handbrake-config:/config",
          "/opt/handbrake-storage:/storage",
        ]

        labels = {
          appname                  = "handbrake"
          component                = "handbrake"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }
      }

      volume_mount {
        volume      = "downloads"
        destination = "${NOMAD_ALLOC_DIR}/downloads"
        read_only   = false
      }

      service {
        provider = "nomad"
        port     = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.handbrake.rule=Host(`handbrake.${var.domain}`)",
          "traefik.http.routers.handbrake.entrypoints=web-secure",
          "traefik.http.routers.handbrake.tls=true",
        ]
      }

      resources {
        cpu        = 4096
        memory     = 1024
        memory_max = 12288
      }
    }
  }
}
