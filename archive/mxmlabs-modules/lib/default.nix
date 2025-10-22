{ inputs }:
# Custom Nix library functions for mxmlabs infrastructure

{
  # Helper function to conditionally include modules
  mkConditionalModule = condition: module:
    if condition then [ module ] else [ ];
    
  # Generate common user configuration
  mkUser = { name, description ? "", shell ? "zsh", extraGroups ? [ ] }: {
    users.users.${name} = {
      inherit description shell;
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ] ++ extraGroups;
    };
  };
  
  # Common system configuration helper
  mkSystemConfig = { hostname, timeZone ? "UTC", locale ? "en_US.UTF-8" }: {
    networking.hostName = hostname;
    time.timeZone = timeZone;
    i18n.defaultLocale = locale;
  };
}
