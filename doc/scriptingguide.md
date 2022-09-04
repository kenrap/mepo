# Scripting Guide

Mepo has advanced scripting capabilities through [mepolang](api.md) by way
of primarily mechanisms two mechanims: 1) via interactive scripting through 
STDIN, 2) and via the shellpipe mepolang.

## Scripting via Interactive STDIN
Mepo has a capability of being scripted noninteractively via feeding mepolang
commands continually into the application's STDIN filedescriptor. This functionality
can be enabled via using the `-i` commandline flag which indicates to the application
logic to continually read commands from STDIN.

One example might be:
```sh
echo "prefset_n crosshair_size 200;" | mepo -i
```

Or continually:
```sh
mkfifo foo
cat foo | mepo -i &
echo "prefset_n crosshair_size 200;" > foo
```

## Scripting via Mepolang `shellpipe_sync` / `shellpipe_async`

Since mepo is designedto be a relatively minimal SDL application focusing
on only rendering OSM tiles and overlays, a good amount of functionality
in the default configuration is offloaded to external programs via a 
mechnaism known as `shellpipe`.

Coming in two variants, `shellpipe_async` and `shellpipe_sync`, the shellpipe
mechanism allows you to run an external command with a set of ENV variables
representing mepo's state and allows you to run arbitrary mepolang code by
simply printing to STDOUT in the shellpipe script.

An example of a simple `shellpipe_sync` script might be:

```sh
#!/usr/bin/env sh

echo "prefset_n crosshair_size 30;"
sleep 2
echo "prefset_n crosshair_size 100;"
sleep 2
echo "prefset_n crosshair_size 15;"
```
