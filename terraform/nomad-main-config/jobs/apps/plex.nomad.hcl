variable "version" {
  type = string
}

variable "domain" {
  type = string
}

variable "volume_name_downloads" {
  type = string
}

variable "volume_name_plex_data" {
  type = string
}

job "plex" {
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
        static = 32400
        to     = 32400
      }

      port "metrics" {
        to = "9594"
      }
    }

    task "plex" {
      driver = "docker"

      env {
        VERSION                = "latest"
        PUID                   = "297536"
        PGID                   = "297536"
        TZ                     = "America/Chicago"
        NVIDIA_VISIBLE_DEVICES = "all"
      }

      config {
        image      = "ghcr.io/linuxserver/plex:${var.version}"
        runtime    = "nvidia"
        privileged = true

        group_add = ["video"]

        devices = [
          {
            host_path = "/dev/dri"
          }
        ]

        volumes = [
          "/data/plex-data:/config",
        ]

        labels = {
          appname                  = "plex"
          component                = "plex"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }
      }

      template {
        destination = "local/env"
        env         = true
        data        = <<EOF
{{with nomadVar "nomad/jobs/plex/app/plex"}}
PLEX_CLAIM={{.claim_token}}
{{end}}
EOF
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
        read_only   = false
      }

      service {
        provider = "nomad"
        port     = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.plex.rule=Host(`plex.${var.domain}`)",
          "traefik.http.routers.plex.entrypoints=web-secure",
          "traefik.http.routers.plex.tls=true",
          "traefik.http.routers.plex.tls.certresolver=letsencrypt-prod",
        ]

        check {
          type     = "http"
          port     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "2s"
        }
      }

      resources {
        cpu        = 4096
        memory     = 1024
        memory_max = 12288
      }
    }

    task "metrics-exporter" {
      driver = "docker"

      config {
        image      = "ghcr.io/pirogoeth/plex-media-server-exporter:master-0ba991a"
        force_pull = true

        ports = ["metrics"]

        labels = {
          appname                  = "plex"
          component                = "metrics-exporter"
          vector_stdout_parse_mode = "plain"
          vector_stderr_parse_mode = "plain"
        }
      }

      env {
        PORT                                      = "9594"
        PLEX_ADDR                                 = "https://plex.${var.domain}"
        PLEX_TIMEOUT                              = "10"
        PLEX_RETRIES_COUNT                        = "2"
        METRICS_PREFIX                            = "plex"
        METRICS_MEDIA_COLLECTING_INTERVAL_SECONDS = "300"
      }

      template {
        destination = "local/env"
        env         = true
        data        = <<EOF
{{with nomadVar "nomad/jobs/plex/app/metrics-exporter"}}
PLEX_TOKEN={{.plex_token}}
{{end}}
EOF
      }

      service {
        provider = "nomad"
        port     = "metrics"
        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
        ]
      }
    }
  }
}
