# S7 Naming Rule — Capital Letter Distinguishes the Composite

**Source:** Jamie, 2026-04-13 —
*"planes Planes the Capital letter is distinguishing in curve position location Location"*

## The rule

When a name comes in **two casings**, the distinction is not
stylistic — it's **semantic**:

| lowercase | meaning | Capital | meaning |
|---|---|---|---|
| `plane` | a single axis of the Prism (sensory, episodic, ...) — one of 8 | `Plane` | the full 8-axis Plane object: the group of directions-and-magnitudes that together form one prism decomposition |
| `position` | a single ternary value on one axis (−1 / 0 / +1) | `Position` | the 8-tuple of all positions — the integer cell address |
| `location` | a raw placement on one axis (a number) | `Location` | the full composite LocationID: 8-plane Position + subposition + Long/Lat + Sun + Time + For/RevToken + aptitude + forbidden flag |
| `cell` | one integer cell in the cube | `Cell` | the same thing viewed as a composite object with display scaling |
| `prism` | a decomposition dict keyed by plane name | `Prism` | the decomposer class / the product family |

## Why the rule matters

When everything is lowercase, a reader has to guess which scope a
name refers to. "the position of the row" — is that one axis value
or the whole cell? "the location" — is that Long/Lat, the cell, or
the full LocationID? Ambiguity slows code review and hides bugs.

The Capital/lowercase distinction gives us one-letter precision:
- `p.semantic.position = -1` — one ternary value
- `Position(p) = (0, 0, -1, 0, 0, 0, 0, 0)` — the cell
- `Location(p) = <full LocationID record>` — the composite

## How it applies in tonight's code

Already Capital (following the rule):
- `LocationID` (as a concept and a table column name)
- `Prism`, `ModalityProjector`, `TextProjector`, `CodeProjector`
- `OCTI_PLANES` (constant — treat as proper noun)
- `SkyMMIP`, `QBIT Prism`, `SkyQUBi`

Already lowercase (following the rule):
- `cell_tuple(prism)` — returns one integer cell
- `plane` as dict key in a prism decomposition
- `cell_display(cell)` — operates on one cell
- `direction`, `magnitude` — single-axis scalars

New Capital-name aliases (this commit):
- `Cell(prism)` — alias for `cell_tuple`, conveys "the composite position"
- `Position(prism)` — alias for `cell_tuple`, emphasises the 8-tuple shape
- `Location(prism, **kwargs)` — alias for `build_location_id`
- `CellDisplay(cell)` — alias for `cell_display_str`

These are additive. Nothing is renamed. Existing code keeps working.
New code can use whichever form better expresses its intent.

## What this rule does NOT do

- Does not rename existing functions or variables. The lowercase
  originals stay.
- Does not apply to class names (which are already TitleCase by
  Python convention).
- Does not apply to module names (which are already
  `lower_with_underscores` by Python convention).
- Does not retroactively fix historical prose in docstrings or
  memory entries.

## Follow-up work

- A cross-codebase pass that flags ambiguous-scope references in
  docstrings (e.g., "the location" without specifying lowercase
  vs Capital). Not yet started.
- A contributor guide entry making the rule explicit for anyone
  touching S7 code. Pinned.
- A pre-commit hook that warns when a new function takes both
  a `position` and a `Position` argument in the same signature
  (which would be confusing). Pinned.
