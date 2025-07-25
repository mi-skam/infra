{ lib, ... }:
{
  home = {
    username = "mi-skam";
    homeDirectory = "/home/mi-skam";
    stateVersion = "24.11";
  };

  userConfig = {
    name = "mi-skam";
    email = "maksim.bronsky@adminforge.de";
    gitName = "mi-skam";
  };
}