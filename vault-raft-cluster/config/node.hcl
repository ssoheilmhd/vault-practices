# Storage configuration
storage "raft" {
  path    = "/vault/data"
  node_id = "node3"

  retry_join {
    leader_api_addr = "http://10.20.30.123:8200"
    leader_tls_skip_verify = true
  }
}

# Listener configuration with TLS
listener "tcp" {
  address          = "0.0.0.0:8200"
  cluster_address  = "0.0.0.0:8201"
  tls_disable      = true
}

# Other settings
api_addr = "http://10.20.30.123:8200"
cluster_addr = "http://10.20.30.3:8201"
disable_mlock = true
ui = true
