locals {
  default_acl     = "private"
  _bucket_mapping = merge([for cfg in var.bucket_configs : { for bucket in cfg.buckets : bucket.name => bucket }]...)
  _user_mapping   = { for cfg in var.bucket_configs : cfg.user => cfg }
}

resource "minio_iam_user" "user" {
  for_each = toset(keys(local._user_mapping))

  name = each.key
}

resource "minio_iam_service_account" "user_sa" {
  for_each = minio_iam_user.user

  target_user = each.value.name

  lifecycle {
    ignore_changes = [policy]
  }
}

resource "minio_iam_user_policy_attachment" "user_policy" {
  for_each = minio_iam_user.user

  user_name   = each.value.name
  policy_name = minio_iam_policy.policy[each.key].name
}

resource "minio_s3_bucket" "bucket" {
  for_each = toset(keys(local._bucket_mapping))

  bucket = each.key
  acl    = lookup(local._bucket_mapping[each.value], "acl", local.default_acl)
}

resource "minio_ilm_policy" "bucket_lifecycle_policy" {
  for_each = toset([
    for bucket in keys(local._bucket_mapping) : bucket
    if lookup(local._bucket_mapping[bucket], "lifecycle_rules", null) != null
  ])

  bucket = minio_s3_bucket.bucket[each.value].bucket

  dynamic "rule" {
    for_each = lookup(local._bucket_mapping[each.key], "lifecycle_rules", [])
    content {
      # required
      id = rule.value["id"]
      # optional
      expiration = lookup(rule.value, "expiration", null)
      filter     = lookup(rule.value, "filter", null)
      tags       = lookup(rule.value, "tags", {})

      dynamic "transition" {
        for_each = lookup(rule.value, "transition", [])
        content {
          # required
          storage_class = transition.value["storage_class"]
          # optional
          days = lookup(transition.value, "days", null)
          date = lookup(transition.value, "date", null)
        }
      }

      dynamic "noncurrent_transition" {
        for_each = lookup(rule.value, "noncurrent_transition", [])
        content {
          # required
          days          = noncurrent_transition.value["days"]
          storage_class = lookup(noncurrent_transition.value, "storage_class", null)
          # optional
          newer_versions = noncurrent_transition.value["newer_versions"]
        }
      }

      dynamic "noncurrent_expiration" {
        for_each = lookup(rule.value, "noncurrent_expiration", [])
        content {
          # required
          days = noncurrent_expiration.value["days"]
          # optional
          newer_versions = lookup(noncurrent_expiration.value, "newer_versions", null)
        }
      }
    }
  }
}

resource "minio_iam_policy" "policy" {
  for_each = minio_iam_user.user

  name = "${each.key}-user-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : [
            minio_iam_user.user[each.key].id
          ]
        },
        "Action" : [
          "s3:*",
        ],
        "Resource" : flatten([
          for bucket in local._user_mapping[each.key].buckets : [
            "arn:aws:s3:::${minio_s3_bucket.bucket[bucket.name].bucket}",
            "arn:aws:s3:::${minio_s3_bucket.bucket[bucket.name].bucket}/*",
          ]
        ]),
      },
    ],
  })

  lifecycle {
    ignore_changes = [policy]
  }
}

output "endpoint" {
  value = var.minio_server
}

output "buckets" {
  value = keys(local._bucket_mapping)
}

output "credentials" {
  sensitive = true
  value = { for user in keys(local._user_mapping) :
    user => {
      access_key_id     = minio_iam_service_account.user_sa[user].access_key
      secret_access_key = minio_iam_service_account.user_sa[user].secret_key
    }
  }
}

