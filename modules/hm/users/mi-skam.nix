{ lib, ... }:
let
  username = "mi-skam";
in
{
  home = {
    inherit username;
    stateVersion = "25.05";
  };

  userConfig = {
    name = username;
    email = "maksim.bronsky@adminforge.de";
    gitName = "mi-skam";
  };
}
