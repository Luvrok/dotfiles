# ssh with TERM=xterm: remote hosts don't have kitty's terminfo.
{ writeShellScriptBin, openssh }:

writeShellScriptBin "ssh" ''
  TERM=xterm ${openssh}/bin/ssh "$@"
''
