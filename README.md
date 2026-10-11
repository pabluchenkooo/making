# making

Sketches, models and render scripts for the projects in the **Making** section
of the blog (woodworking, tinkering, sewing). One folder per project.

| Project | What | Blog post |
|---|---|---|
| [daniels-kitchen](daniels-kitchen/) | Plywood kitchen for a small room | [Planning a kitchen](https://blog.pabluchenko.de/posts/making/woodworking/planning-a-kitchen/) |

## Conventions

- **Units are cm** in models, unless a project says otherwise.
- **Keep the source of the measurements** in the project (scan, SketchUp export,
  notes); everything else is derived from it.
- Models are parametric (OpenSCAD): change a number, not the geometry.
- Each project has a `README.md` with how to open, export and render it.
- `export/` (model files for Blender, cut lists, …) is committed.
- `renders/`, `*.blend` and videos are **not** committed: they're rebuilt by
  the project's scripts. Renders that go into a post are copied into the blog
  (`pabloblog/static/images/posts/making/...`); videos go to engram through
  the blog's pre-push hook.

## New project

```sh
mkdir my-project && cd my-project
# copy the scripts from the closest earlier project, e.g.
cp ../daniels-kitchen/{export.sh,render.py} .
```

## Tools

- [OpenSCAD](https://openscad.org/): models. Open the `.scad`, Design → Automatic Reload and Preview.
- [Blender](https://www.blender.org/): renders, run headless from the command line.

## Git

Commits are by `Pablo <pabluchenkooo@gmail.com>` with no AI attribution lines,
like the blog. Enforced by `.githooks/commit-msg`; on a fresh clone run
`git config core.hooksPath .githooks`.
