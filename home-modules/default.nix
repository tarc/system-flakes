{ ezModules
, osConfig
, ...
}:
{
  imports = [
    ezModules.direnv
    ezModules.bat
    ezModules.tldr
  ];
}
