{ pkgs, inputs, ... }:

{
  imports = [
    inputs.srvos.nixosModules.desktop
    
    ./common.nix
    ./mullvad-vpn.nix
  ];
  # set for VSCode
  boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

  environment.systemPackages = with pkgs; [
    ntfs3g
    pciutils
  ];

  networking.networkmanager.enable = true;

  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "overload(m3, esc)";
          };
        };
      };
      logitechMX = {
        ids = [ "046d:408a:cc02868b" ];
        settings = {
          main = {
            leftalt = "leftmeta";
            leftmeta = "leftalt";

            capslock = "overload(m3, esc)";
          };
        };
      };
    };
  };

  services.fwupd.enable = true;
}
