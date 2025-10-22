# SSH key for server access
# Note: This will be imported from existing key, not created
data "hcloud_ssh_key" "homelab" {
  name = var.ssh_key_name
}
