{
  config,
  ...
}:
{
  sops = {
    defaultSopsFile = ../../secrets/users.yaml;
    age.keyFile = "/opt/homebrew/etc/sops/age/keys.txt";
    
    secrets = {
      "mi-skam" = {};
      "plumps" = {};
    };
  };
}