# Adding a tool

The toolbox is flat: one top-level folder per tool, each a self-contained
Processing sketch. There is no shared library and no build step. Adding a tool is
mostly a matter of following three constraints.

## 1. Folder name must equal main sketch name

Processing will not open a sketch whose main `.pde` differs from its folder:

```
WidgetGenerator/
├── WidgetGenerator.pde     ← required, exact match
├── UI.pde
└── README.md
```

This is why tools are named `PaperPolyhedra` rather than `paper-polyhedra`.

## 2. Every tool gets a README

At minimum: what it does, how to run it, which libraries it needs, and what each
source file is responsible for. Look at
[PaperPolyhedra/README.md](../PaperPolyhedra/README.md) for the full shape, or
[DataPhysicalisation/README.md](../DataPhysicalisation/README.md) for a lighter one.

If the tool exchanges files with another, document the format. The handoff is the
part that breaks silently.

## 3. Add it to the root README table

With an honest status. `Planned` with a scaffold README is a perfectly good
state — it records intent and stops the same idea being restarted from zero
later.

## Bringing in an existing sketch

1. Copy **source only** — `.pde`, plus small fixed reference data. Leave `output/`
   and bulk media behind.
2. Rename the main `.pde` to match the folder.
3. Check `loadImage` / `loadStrings` / `loadTable` calls for assets you did not
   copy. If an asset is large or personal, generate a placeholder at startup
   instead of committing it — see `PaperPolyhedra/PlaceholderAssets.pde`.
4. Run it before committing. A sketch that does not open is worse than no sketch,
   because it looks available.
5. Write the README, update the root table, commit.

## Things that must not be committed

`.gitignore` already blocks these, but the reasoning matters more than the rule:

| Never commit | Why |
|---|---|
| `output/` exports | Reproducible. They are results, not source. |
| `*.zip` snapshots | A tag or branch does this properly and costs nothing. |
| Dated folder copies | `tool_v3_20260619/` is a commit wearing a disguise. |
| Bulk artwork | Personal media. Generate placeholders, load real art at runtime. |

Git history is append-only in practice: a 12 MB `.tif` committed once is carried
by every clone forever, even after deletion. That is how the predecessor
repository reached 650 MB.

## Versioning

Use git, not folder names.

```bash
git switch -c widget-generator-extraction   # in-progress work
git tag workshop-2026-09                    # a build you handed to people
```

A tag is a permanent, zero-cost, restorable snapshot. It is strictly better than
a copied folder in every way, including being findable a year later.
