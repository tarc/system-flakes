{ ezModules
, ...
}:
{
  imports = [
    ezModules.bat
    ezModules.devenv
    ezModules.direnv
    ezModules.swaylock
    ezModules.tldr
  ];
}
