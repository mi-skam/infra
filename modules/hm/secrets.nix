{
  inputs,
  pkgs,
  osConfig,
  config,
  lib,
  ...
}:

{
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh-keys.yaml;
    
    secrets = {
      # SSH Keys
      homelab_private_key = {
        path = "${config.home.homeDirectory}/.ssh/homelab";
        mode = "0600";
      };
      homelab_public_key = {
        path = "${config.home.homeDirectory}/.ssh/homelab.pub";
        mode = "0644";
      };
      
      # PGP Keys
      pgp_private_key = {
        sopsFile = ../../secrets/pgp-keys.yaml;
        path = "${config.home.homeDirectory}/.gnupg/private-keys-v1.d/B84E7184.key";
        mode = "0600";
      };
      pgp_revocation_cert = {
        sopsFile = ../../secrets/pgp-keys.yaml;
        path = "${config.home.homeDirectory}/.gnupg/revoke-cert.asc";
        mode = "0600";
      };
      pgp_public_key_maksim = {
        sopsFile = ../../secrets/pgp-keys.yaml;
        path = "${config.home.homeDirectory}/.gnupg/pubring.kbx.tmp";
        mode = "0644";
      };
      pgp_public_key_adminforge = {
        sopsFile = ../../secrets/pgp-keys.yaml;
        path = "${config.home.homeDirectory}/.gnupg/adminforge-pubkey.asc";
        mode = "0644";
      };
    };
  };
}