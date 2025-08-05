variable "minio_server" {
  type    = string
  default = "http://10.100.10.2:9000"
}

variable "minio_ssl" {
  type    = bool
  default = false
}

variable "minio_username" {
  type    = string
  default = "minio"
}

variable "minio_password" {
  type    = string
  default = "minio"
}

variable "bucket_configs" {
  type = list(object({
    user = string
    buckets = list(object({
      name = string
      acl  = optional(string)
      lifecycle_rules = optional(list(object({
        id         = string
        expiration = string
      })))
    }))
  }))
}
