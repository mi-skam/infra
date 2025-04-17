{ pkgs, inputs, ...}:
{
  imports = [ inputs.self.homeModules.desktop ];

  userConfig.name = "mi-skam";
  userConfig.email = "maksim@miskam.xyz";
}
