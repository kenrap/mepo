#!/usr/bin/env sh
cd "$(realpath $(dirname "$0"))"/..
USER=user
CONN=$USER@10.0.0.102
rsync -v -a --exclude 'zig-out' --exclude 'zig-cache' . $CONN:/home/$USER/mepo
ssh -t $CONN 'sudo sh -c "
  set -e
  pkill -9 mepo || echo
  cd /home/'$USER'/mepo
  zig build
  cp zig-out/bin/* /usr/bin/
  cp zig-out/share/applications/* /usr/share/applications/
  cp zig-out/share/icons/hicolor/512x512/apps/mepo.png /usr/share/icons/hicolor/512x512/apps/mepo.png
"'
