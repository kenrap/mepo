#!/usr/bin/env sh
cd "$(realpath $(dirname "$0"))"/..
USER=m
CONN=$USER@pine64-pinephone
rsync -v -a --exclude 'zig-out' --exclude 'zig-cache' . $CONN:/home/$USER/mepo
ssh -t $CONN 'sudo sh -c "
  set -e
  cd /home/'$USER'/mepo
  zig build
  cp zig-out/bin/* /usr/bin/
  cp zig-out/share/applications/* /usr/share/applications/
"'
