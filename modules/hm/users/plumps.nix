{ lib, ... }:
let 
  username = "plumps";
in
{
  home = {
    inherit username;
    stateVersion = "25.05";
  };

  userConfig = {
    name = username;
    email = "maksim@miskam.xyz";
    gitName = "mi-skam";
  };
}
