#!/usr/bin/env sh
cd "$(realpath "$(dirname "$0")")"/.. || exit 1
USER=user
CONN=$USER@pine64-pinephone
rsync --delete -v -a --exclude 'zig-out' --exclude 'zig-cache' . $CONN:/home/$USER/mepo
ssh -t $CONN 'sudo sh -c "
  set -e
  pkill -9 mepo || echo
  cd /home/'$USER'/mepo
  zig build
  rm -f /usr/bin/mepo_*
  cp zig-out/bin/* /usr/bin/
  cp zig-out/share/applications/* /usr/share/applications/
  cp zig-out/share/pixmaps/mepo.png /usr/share/pixmaps/mepo.png
"'
