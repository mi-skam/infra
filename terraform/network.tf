# Private network for all servers
resource "hcloud_network" "homelab" {
  name     = var.network_name
  ip_range = var.network_ip_range
}

resource "hcloud_network_subnet" "homelab_subnet" {
  network_id   = hcloud_network.homelab.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.network_subnet_range
}
