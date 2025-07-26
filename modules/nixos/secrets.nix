{
  config,
  ...
}:
{
  sops = {
    defaultSopsFile = ../../secrets/users.yaml;
    age.keyFile = "/etc/sops/age/keys.txt";
    
    secrets = {
      "mi-skam" = {
        neededForUsers = true;
      };
      "plumps" = {
        neededForUsers = true;
      };
    };
  };
  
  # Create the age key directory - the key must be manually deployed
  system.activationScripts.sops-age-key-dir = {
    text = ''
      mkdir -p /etc/sops/age
      chmod 755 /etc/sops/age
    '';
    deps = [];
  };
}