# Mail server - Debian 12, CAX21 (ARM64, 4 cores, 8GB RAM)
resource "hcloud_server" "mail_prod_nbg" {
  name               = "mail-1.prod.nbg"
  server_type        = "cax21"
  image              = "debian-12"
  location           = "nbg1"
  ssh_keys           = [data.hcloud_ssh_key.homelab.id]
  backups            = true
  delete_protection  = true
  rebuild_protection = true

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.homelab.id
    ip         = "10.0.0.3"
  }

  labels = {
    env       = "prod"
    role      = "mail"
    os_family = "debian"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys]
  }
}

# Syncthing server - Rocky Linux 9, CAX11 (ARM64, 2 cores, 4GB RAM)
resource "hcloud_server" "syncthing_prod_hel" {
  name               = "syncthing-1.prod.hel"
  server_type        = "cax11"
  image              = "rocky-9"
  location           = "hel1"
  ssh_keys           = [data.hcloud_ssh_key.homelab.id]
  backups            = true
  delete_protection  = false
  rebuild_protection = false

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.homelab.id
    ip         = "10.0.0.2"
  }

  labels = {
    env       = "prod"
    role      = "syncthing"
    os_family = "redhat"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ssh_keys]
  }
}

# Test server - Ubuntu 24.04, CAX11 (ARM64, 2 cores, 4GB RAM)
resource "hcloud_server" "test_dev_nbg" {
  name               = "test-1.dev.nbg"
  server_type        = "cax11"
  image              = "ubuntu-24.04"
  location           = "nbg1"
  ssh_keys           = [data.hcloud_ssh_key.homelab.id]
  backups            = false
  delete_protection  = false
  rebuild_protection = false

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.homelab.id
    ip         = "10.0.0.4"
  }

  labels = {
    env       = "dev"
    role      = "test"
    os_family = "debian"
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [ssh_keys]
  }
}
