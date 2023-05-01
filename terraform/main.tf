provider "vault" {
  address = "http://127.0.0.1:8200"
}

resource "vault_mount" "kvv2" {
  path        = "kvv2"
  type        = "kv"
  options     = {
    version = "2"
  }
  description = "KV Version 2 secret engine mount"
}

variable "pg_superuser_password" {
  type = string
}

resource "vault_database_secrets_mount" "pg" {
  path = "pg"

  postgresql {
    name              = "pg"
    username          = "postgres"
#    password          = var.pg_superuser_password
    connection_url    = "postgresql://{{username}}:{{password}}@demo-cluster-rw.default:5432/postgres"
    verify_connection = true
    allowed_roles = ["app"]
  }
}

resource "vault_database_secret_backend_role" "app" {
  name    = "app"
  backend = vault_database_secrets_mount.pg.path
  db_name = vault_database_secrets_mount.pg.postgresql[0].name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
  default_ttl = 60
  max_ttl = 300
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  kubernetes_host = "https://$KUBERNETES_PORT_443_TCP_ADDR:443"
}

resource "vault_policy" "app" {
  name = "app"

  policy = <<EOT
path "pg/creds/app" {
  capabilities = ["read"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "app" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "app"
  bound_service_account_names      = ["app"]
  bound_service_account_namespaces = ["default"]
  token_ttl                        = 3600
  token_policies                   = ["app"]
}
