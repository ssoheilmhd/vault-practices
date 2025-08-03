auto_auth {
  method "approle" {
    config = {
      role_id_file_path = "/tmp/role_id"
      secret_id_file_path = "/tmp/secret_id"
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault_token"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "0.0.0.0:8100"
  tls_disable = true
}


vault {
  address = "http:/<Vault-Addr>:<Vault-Port>"
}
