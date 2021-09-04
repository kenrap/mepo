# **Software Bill of Materials**

**Base application** (mepo):
- Zig: Used for compile core application logic
- Zig Standard Library: Used to build out core application logic
- SDL2: Base application, used for rendering graphics
- SDL2_image: Used for loading PNG data
- SDL2_ttf: Used for displaying truetype fonts
- Libcurl: Used for parallel downloading of tiles

**Scripts** (mepo_scripts):
- Dmenu: Used for menuing system (X)
- Bemenu: Used for menuing system (Wayland)
- Busybox: Used to shell & provide tools for scripts
- Jq: Used for parsing JSON datastructures from external sources
- Xmllint: Used for extracting XML from OSM API via Xpath
