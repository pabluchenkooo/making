# Daniel's kitchen

New kitchen for the small room with the counter in Daniel's flat: plywood
cabinets, a dark linoleum countertop, the existing oven, a new fridge on the
opposite wall, dishwasher (60 cm), washing machine (70 cm) and the Sage
Barista Express.

Blog post: [Planning a kitchen](https://blog.pabluchenko.de/posts/making/woodworking/planning-a-kitchen/)

## Files

| File | What |
|---|---|
| `danielsWohnung.stl` | The flat as exported from SketchUp: source of all measurements |
| `room.scad` | The room only, measured from the STL (door, column, old counter) |
| `kitchen.scad` | The kitchen design. Layout lives in `COUNTER_RUN` and `OPPOSITE_RUN` |
| `export.sh` | `kitchen.scad` → `export/<material>.stl`, one file per material |
| `render.py` | Builds the Blender scene from `export/` and renders to `renders/` |

Room (interior, cm, SketchUp coordinates): x −522 (window) … −212.5,
y −143 … 58, ceiling 265.5. The window size in `render.py` is a guess:
measure it on site.

## Use

```sh
open kitchen.scad                     # edit; OpenSCAD reloads on save
./export.sh                           # after changing the design
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P render.py                                   # all stills → renders/*.png
$B -b -P render.py -- --only wall_counter,wall_opposite   # just some cameras
$B -b -P render.py -- --video                        # walk-through → renders/walkthrough.mp4
open kitchen.blend                    # look around in Blender
```

Cameras: `from_door`, `from_window`, `wall_counter`, `wall_opposite` (each
long wall straight on, with the other one clipped away), plus `walk` for the
video.
