{ ... }:
{
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.enable = true;

  # Enable KWallet PAM integration to prevent service failures
  security.pam.services = {
    login.enableKwallet = true;
    sddm.enableKwallet = true;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "neo";
  };

}
