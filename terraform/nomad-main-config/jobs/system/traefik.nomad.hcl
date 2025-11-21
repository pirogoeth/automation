variable "version" {
  type    = string
  default = "v2.10.7"
}

variable "domain" {
  type = string
}

variable "letsencrypt_email" {
  type = string
}

job "traefik" {
  namespace   = "nomad-system"
  type        = "system"
  priority    = 100
  datacenters = ["dc1"]
  node_pool   = "all"

  update {
    max_parallel     = 1
    min_healthy_time = "20s"
    healthy_deadline = "3m"
    canary           = 0
  }

  group "traefik" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }

    ephemeral_disk {
      sticky  = true
      migrate = true
      size    = 512
    }

    task "traefik" {
      driver = "docker"

      config {
        image      = "traefik:${var.version}"
        force_pull = true

        args = [
          "--configfile=${NOMAD_TASK_DIR}/traefik.yml",
        ]

        labels {
          appname = "traefik"
        }

        volumes = [
          "/opt/nomad/data/traefik/acme:/acme",
        ]
      }

      resources {
        network {
          port "http" {
            static = 80
          }

          port "https" {
            static = 443
          }

          port "traefik-api" {
            static = 8889
          }

          port "traefik-metrics" {
            static = 8891
          }
        }
      }

      service {
        name     = "traefik-api"
        port     = "traefik-api"
        provider = "nomad"

        tags = [
          # "traefik.enable=false",
          # "traefik.http.routers.traefik-api.rule=Host(`traefik.${var.domain}`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))",
          # "traefik.http.routers.traefik-api.entrypoints=traefik-api",
          # "traefik.http.routers.traefik-api.service=api@internal",
          # "traefik.http.routers.traefik-api.tls=true",
          # "traefik.http.routers.traefik-api.tls.certResolver=letsencrypt",
          # "traefik.http.routers.traefik-ping.rule=PathPrefix(`/ping`)",
          # "traefik.http.routers.traefik-ping.entrypoints=traefik-api",
          # "traefik.http.routers.traefik-ping.service=ping@internal",
        ]

        check {
          name     = "Traefik API Check"
          type     = "http"
          protocol = "http"
          interval = "10s"
          timeout  = "2s"
          path     = "/health"
          method   = "GET"
        }
      }

      service {
        name     = "traefik-metrics"
        port     = "traefik-metrics"
        provider = "nomad"

        tags = [
          "prometheus.io/scrape=true",
          "prometheus.io/path=/metrics",
          "prometheus.io/scrape_interval=15s",
        ]
      }

      template {
        destination = "local/env"
        change_mode = "restart"
        env         = true

        data = <<EOH
{{- with nomadVar "nomad/jobs/traefik" -}}
CF_API_EMAIL="{{ .cloudflareEmail }}"
CF_API_KEY="{{ .cloudflareApiKey }}"
{{- end -}}
EOH
      }

      template {
        destination = "local/nomad-ca-cert.pem"
        change_mode = "signal"

        data = <<EOH
{{ with nomadVar "tls/ca-cert" }}{{ .text }}{{ end }}
EOH
      }

      template {
        destination = "local/nomad-cli-cert.pem"
        change_mode = "signal"

        data = <<EOH
{{ with nomadVar "tls/cli-cert" }}{{ .text }}{{ end }}
EOH
      }

      template {
        destination = "local/nomad-cli-key.pem"
        change_mode = "signal"

        data = <<EOH
{{ with nomadVar "tls/cli-key" }}{{ .text }}{{ end }}
EOH
      }

      template {
        destination = "local/traefik.yml"
        change_mode = "signal"

        data = <<EOH
log:
  level: "INFO"
  format: "json"

accessLog:
  format: "json"

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: "web-secure"
          scheme: "https"
  web-secure:
    address: ":443"
    http:
      tls: {}
  traefik-api:
    address: ":8889"
  traefik-metrics:
    address: ":8891"

certificatesResolvers:
  letsencrypt:
    acme:
      email: "${var.letsencrypt_email}"
      caServer: "https://acme-staging-v02.api.letsencrypt.org/directory"
      storage: "/acme/staging.json"
      dnsChallenge:
        provider: "cloudflare"
        delayBeforeCheck: 15
        resolvers: ["1.1.1.1:53", "8.8.8.8:53"]
  letsencrypt-prod:
    acme:
      email: "${var.letsencrypt_email}"
      caServer: "https://acme-v02.api.letsencrypt.org/directory"
      storage: "/acme/production.json"
      dnsChallenge:
        provider: "cloudflare"
        delayBeforeCheck: 15
        resolvers: ["1.1.1.1:53", "8.8.8.8:53"]

api:
  dashboard: true
  disabledashboardad: true

ping:
  entryPoint: "traefik-api"
  manualRouting: true

metrics:
  prometheus:
    buckets:
      - 0.1
      - 0.3
      - 1.2
      - 5.0
    addEntryPointsLabels: true
    addServicesLabels: true
    addRoutersLabels: true
    entryPoint: "traefik-metrics"

{{- with nomadVar "managed-namespaces" -}}
{{$namespaces := .json.Value|parseJSON}}
providers:
  file:
    directory: local/conf.d
    watch: true
  nomad:
    refreshInterval: "15s"
    endpoint:
      address: "https://{{ env "attr.nomad.advertise.address" }}"
      tls:
        ca: "local/nomad-ca-cert.pem"
        cert: "local/nomad-cli-cert.pem"
        key: "local/nomad-cli-key.pem"
        insecureSkipVerify: true
    exposedByDefault: false
    namespaces: {{toJSON $namespaces}}
{{end}}

tracing:
  serviceName: traefik
  sampleRate: 0.8
  otlp:
    grpc:
      endpoint: "tempo-ingest.${var.domain}:443"

experimental:
  plugins:
    cloudflarewarp:
      moduleName: "github.com/BetterCorp/cloudflarewarp"
      version: "v1.3.3"
EOH
      }

      template {
        destination = "local/conf.d/tls.yml"
        change_mode = "noop"

        data = <<EOH
tls:
  stores:
    default:
      defaultGeneratedCert:
        resolver: letsencrypt-prod
        domain:
          main: "${var.domain}"
          sans:
            - "*.${var.domain}"
EOH
      }

      template {
        destination = "local/conf.d/middlewares.yml"
        change_mode = "noop"

        data = <<EOH
http:
  middlewares:
    cloudflare-tunnelled:
      plugin:
        cloudflarewarp:
          disableDefault: false
EOH
      }
    }
  }
}
