# Software Bill of Materials

**Base application** (mepo):
- Zig: Used to compile core application logic
- Zig Standard Library: Used to build out core application logic
- SDL2: Used for rendering graphics
- SDL2_image: Used for loading PNG data
- SDL2_gfx: Used for drawing (diagonol) antialiased lines
- SDL2_ttf: Used for displaying TrueType fonts
- Libcurl: Used for parallel downloading of tiles

**Scripts** (mepo_scripts):
- Dmenu: Used for menuing system (X)
- Bemenu: Used for menuing system (Wayland)
- Busybox: Used for base shell & provide tools for scripts
- Jq: Used for parsing JSON data structures from external sources
- Xmllint: Used for extracting XML from OSM API via XPath
- Ncurses: Use for tput/colorizing scripts
