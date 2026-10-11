#!/bin/zsh
# Export kitchen.scad as one STL per material into export/, for render.py (Blender).
set -e
cd "${0:A:h}"

OPENSCAD=$(ls -d /Applications/OpenSCAD*.app/Contents/MacOS/OpenSCAD | tail -1)
mkdir -p export
rm -f export/*.stl(N)

for name in floor wall column door oak oak_dk stone black steel white glass; do
    hex=$(sed -n "s/^c_${name} *= *\"\(#[0-9a-fA-F]*\)\".*/\1/p" kitchen.scad)
    echo "-> $name ($hex)"
    "$OPENSCAD" -o "export/$name.stl" \
        -D "export_part=\"$hex\"" -D show_labels=false \
        kitchen.scad 2>&1 | grep -iE "error|empty" || true
done
ls -l export
