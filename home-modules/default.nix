{ ezModules
, osConfig
, ...
}:
{
  imports = [
    ezModules.devenv
    ezModules.direnv
    ezModules.bat
    ezModules.tldr
  ];
}
