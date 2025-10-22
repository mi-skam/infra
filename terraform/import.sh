#!/usr/bin/env bash
# Import existing Hetzner resources into Terraform state
# Run this after: tofu init

set -euo pipefail

echo "🔄 Importing existing Hetzner resources into OpenTofu state..."
echo ""

# Check if state is already initialized
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
  echo "ℹ️  No existing state found. Will import resources."
else
  echo "⚠️  Existing state found. Resources may already be imported."
  echo "   Continue anyway? (y/N)"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
echo "Importing network..."
tofu import hcloud_network.homelab 10620750 || echo "  ⚠️  Already imported or failed"

echo ""
echo "Importing network subnet..."
tofu import hcloud_network_subnet.homelab_subnet 10620750-10.0.0.0/24 || echo "  ⚠️  Already imported or failed"

echo ""
echo "Importing servers..."
tofu import hcloud_server.mail_prod_nbg 58455669 || echo "  ⚠️  Already imported or failed"
tofu import hcloud_server.syncthing_prod_hel 59552733 || echo "  ⚠️  Already imported or failed"
tofu import hcloud_server.test_dev_nbg 111301341 || echo "  ⚠️  Already imported or failed"

echo ""
echo "✅ Import complete! Run 'tofu plan' to verify state matches configuration."
