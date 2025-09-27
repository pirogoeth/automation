# Proxmox vars
variable "proxmox_url" { type = string }
variable "proxmox_token_id" { type = string }
variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}
variable "proxmox_skip_tls_verify" { type = bool }
variable "proxmox_node" { type = string }
