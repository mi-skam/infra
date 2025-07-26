{
  inputs,
  pkgs,
  osConfig,
  config,
  lib,
  ...
}:

let
  cfg = config.userConfig;
in
{
  programs.ssh = {
    enable = true;
    
    # Connection settings
    compression = true;
    forwardAgent = false;
    addKeysToAgent = "no";
    
    # Keep-alive settings
    serverAliveInterval = 0;
    serverAliveCountMax = 3;
    
    # Host verification
    hashKnownHosts = false;
    userKnownHostsFile = "~/.ssh/known_hosts";
    
    # Connection multiplexing
    controlMaster = "no";
    controlPath = "~/.ssh/master-%r@%n:%p";
    controlPersist = "no";
    
    # Host-specific configurations
    matchBlocks = {
      "git.adminforge.de" = {
        user = "git";
        port = 222;
        identityFile = "~/.ssh/homelab";
        identitiesOnly = true;
      };
    };
  };
}