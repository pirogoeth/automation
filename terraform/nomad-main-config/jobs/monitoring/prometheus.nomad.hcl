variable "version" {
  type = string
}

variable "domain" {
  type = string
}

job "prometheus" {
  namespace   = "monitoring"
  type        = "service"
  datacenters = ["dc1"]

  update {
    stagger = "30s"

  }

  group "app" {
    count = 1

    network {
      mode = "bridge"

      port "http" {
        to = 9090
      }
    }

    task "prometheus" {
      driver       = "docker"
      kill_timeout = "120s"
      kill_signal  = "SIGTERM"

      action "reload-configuration" {
        command = "/usr/bin/env"
        args = [
          "curl", "-v", "-X", "POST", "http://localhost:9090/-/reload"
        ]
      }

      config {
        image      = "docker.io/prom/prometheus:v${var.version}"
        force_pull = true

        args = [
          "--config.file=${NOMAD_ALLOC_DIR}/prometheus.yml",
          "--log.format=json",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=30d",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles",
          "--web.enable-lifecycle",
          "--web.enable-remote-write-receiver",
          "--enable-feature=exemplar-storage",
          "--enable-feature=native-histograms",
        ]

        ports = ["http"]

        volumes = [
          "/data/prometheus-data:/prometheus",
          "/opt/nomad/tls:/opt/nomad/tls:ro",
        ]

        labels {
          appname = "prometheus"
        }
      }

      template {
        destination   = "${NOMAD_ALLOC_DIR}/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"

        data = <<EOH
global:
  scrape_interval: 30s
  scrape_timeout: 10s
  evaluation_interval: 30s
scrape_configs:
- job_name: prometheus
  static_configs:
  - targets:
    - localhost:9090

- job_name: nomad
  static_configs:
  - targets:
    # TODO(seanj): Slick way to template out all active nomad clients?
    - 10.100.10.32:4646  # client-0
    - 10.100.10.48:4646  # gpu-0
    - 10.100.10.64:4646  # server-0
    - 10.100.10.65:4646  # server-1
    - 10.100.10.66:4646  # server-2
  scheme: https
  metrics_path: /v1/metrics
  params:
    format: [prometheus]
  tls_config:
    insecure_skip_verify: true

{{ with nomadVar "prometheus/scrape-configs" -}}
{{- range $configKey, $configItem := .}}
- job_name: "{{ $configKey }}"
  <<: {{ $configItem }}
{{end}}{{end}}

{{- with nomadVar "managed-namespaces" -}}
{{$namespaces := .json.Value|parseJSON}}
- job_name: nomad-services
  nomad_sd_configs:
{{range $namespaces}}
  - server: "https://traefik.${var.domain}:4646"
    namespace: "{{.}}"
    tls_config:
      insecure_skip_verify: true
{{end}}{{end}}
  #
  # !!!!! NOTE !!!!!
  # Need to work with relabelling rules? Check out https://relabeler.promlabs.com.
  #
  relabel_configs:
  - source_labels:
    - "__address__"
    action: "replace"
    regex: "(.+):(?:\\d+)"
    replacement: "$${1}"
    target_label: "instance_address"

  - source_labels:
    - "__meta_nomad_tags"
    regex: ".*,prometheus.io/scrape=([^,]+),.*"
    action: "replace"
    target_label: "__scrape__"
    replacement: "true"

  - source_labels:
    - "__scrape__"
    action: "keep"
    regex: "true"

  - source_labels:
    - "__meta_nomad_tags"
    regex: ".*,prometheus.io/(path|port)=([^,]+),.*"
    action: replace
    target_label: "__metrics_$${1}__"
    replacement: "$${2}"

  - source_labels:
    - "__meta_nomad_tags"
    regex: ".*,prometheus.io/param/([^=]+)=([^,]+),.*"
    action: "replace"
    target_label: "__param_$${1}"
    replacement: "$${2}"

  - source_labels:
    - "__meta_nomad_tags"
    regex: ".*,prometheus.io/(scrape_(interval|timeout)|scheme)=([^,]+),.*"
    action: "replace"
    target_label: "__$${1}__"
    replacement: "$${3}"

  - source_labels:
    - "__meta_nomad_tags"
    regex: ".*,prometheus.io/label/([^=]+)=([^,]+),.*"
    action: "replace"
    target_label: "__label_$${1}__"
    replacement: "$${2}"

  - source_labels:
    - "__address__"
    - "__metrics_port__"
    action: "replace"
    regex: "(.+):(?:\\d+);(\\d+)"
    replacement: "$${1}:$${2}"
    target_label: "__address__"

  - action: "labelmap"
    regex: "__meta_(nomad_(dc|namespace|service))"

  - action: "labelmap"
    regex: "__label_(.*)__"
EOH
      }

      resources {
        cpu        = 256
        memory     = 128
        memory_max = 2048
      }

      service {
        port     = "http"
        provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.${var.domain}`)",
          "traefik.http.routers.prometheus.entrypoints=web",
          "traefik.http.routers.prometheus.middlewares=prometheus-https-redirect",
          "traefik.http.middlewares.prometheus-https-redirect.redirectscheme.scheme=https",
          "traefik.http.routers.prometheus-secure.rule=Host(`prometheus.${var.domain}`)",
          "traefik.http.routers.prometheus-secure.entrypoints=web-secure",
          "traefik.http.routers.prometheus-secure.tls=true",
          # Temporarily(?) using the defaultGeneratedCert
          # "traefik.http.routers.prometheus-secure.tls.certresolver=letsencrypt",
        ]

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
