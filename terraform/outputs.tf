
# Local values for building inventory automatically
locals {
  # All servers in a map
  all_servers = {
    mail_prod_nbg      = hcloud_server.mail_prod_nbg
    syncthing_prod_hel = hcloud_server.syncthing_prod_hel
    test_dev_nbg       = hcloud_server.test_dev_nbg
  }

  # Build Ansible hosts automatically from server labels
  ansible_hosts = {
    for key, server in local.all_servers : server.name => {
      ansible_host = server.ipv4_address
      public_ipv4  = server.ipv4_address
      private_ip   = length(server.network) > 0 ? [for net in server.network : net.ip][0] : null
      env          = server.labels["env"]
      role         = server.labels["role"]
      os_family    = server.labels["os_family"]
    }
  }

  # Build environment groups automatically from server labels
  prod_hosts = {
    for key, server in local.all_servers :
    server.name => {}
    if server.labels["env"] == "prod"
  }

  dev_hosts = {
    for key, server in local.all_servers :
    server.name => {}
    if server.labels["env"] == "dev"
  }

  # Build role groups automatically from server labels
  mail_hosts = {
    for key, server in local.all_servers :
    server.name => {}
    if server.labels["role"] == "mail"
  }
}

output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.homelab.id
}

output "network_ip_range" {
  description = "IP range of the private network"
  value       = hcloud_network.homelab.ip_range
}

output "servers" {
  description = "All server details"
  value = {
    for key, server in local.all_servers : key => {
      id         = server.id
      name       = server.name
      ipv4       = server.ipv4_address
      ipv6       = server.ipv6_address
      private_ip = length(server.network) > 0 ? [for net in server.network : net.ip][0] : null
      status     = server.status
      env        = server.labels["env"]
      role       = server.labels["role"]
    }
  }
}

output "ansible_inventory" {
  description = "Ansible inventory in YAML format"
  value = yamlencode({
    all = {
      hosts = local.ansible_hosts
      vars = {
        ansible_user                 = "root"
        ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
        ansible_ssh_private_key_file = "~/.ssh/homelab/hetzner"
        ansible_python_interpreter   = "/usr/bin/python3"
      }
    }
    prod = {
      hosts = local.prod_hosts
    }
    dev = {
      hosts = local.dev_hosts
    }
    mail = {
      hosts = local.mail_hosts
    }
  })
}
