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
      homelab_private_key = {
        path = "${config.home.homeDirectory}/.ssh/homelab";
        mode = "0600";
      };
      homelab_public_key = {
        path = "${config.home.homeDirectory}/.ssh/homelab.pub";
        mode = "0644";
      };
    };
  };
}