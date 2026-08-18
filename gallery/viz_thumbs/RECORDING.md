# Gallery Thumbnail Recording Instructions

How to (re-)record the VIZ thumbnail videos in `gallery/viz_thumbs/` for the examples gallery
(`gallery/examples.js` / `gallery/index.html`). Settings for each recording are logged in that
example's `capture` field in `gallery/examples.js`.

## Conventions

- **Size:** 350×250 px (the gallery `.media-wrap` aspect is 1.4; cards use `object-fit: contain`
  on a white background).
- **Format:** MP4 for every example **except** `all_examples`, which stays a GIF.
- **Output path:** `gallery/viz_thumbs/<key>.mp4` (paths in this doc are relative to the repo
  root, where the shell commands run) where `<key>` is the example's `key` in `examples.js`.

## Prerequisites

1. **SandHost running:** `cd <mono-clone> && bin/start` (serves the IDE at `http://localhost:8080/ide/`).
2. **Extension reloaded (important):** the `makerchip_capture_video` tool must expose the `mode`
   parameter. If it was just rebuilt, run **Developer: Reload Window** once so the new tool schema
   registers. Without this, `mode: 'fit-relative'` cannot be passed through the tool.
3. **Webview fresh:** after a SandHost restart, reload the IDE webview so it serves the latest
   client code.

## Framing: use `fit-relative`

`fit-relative` frames relative to the **whole-design contain-fit at the recording size**, so you
don't have to hand-tune an absolute `scale`. This is the reliable replacement for the older
`absolute` + `fitKeyframe`/hand-scaled workflow.

- **Whole design (default):** `mode: 'fit-relative'` with **no keyframes** ⇒ the entire design is
  framed and centered (equivalent to `scale: 1`, `focus: {x: 0, y: 0}`).
- **Zoom into a region:** `keyframes: [{ scale: Z, focus: { x: fx, y: fy } }]` where
  - `scale` is a multiplier on the whole-design fit (`1` = whole design, `2` = 2× zoom in, `0.5` = out),
  - `focus` is an **{x, y} offset as a fraction of the fit's visible area** (`+x` right, `+y` down;
    e.g. `x: 0.15` pans right 15%).

## Per-example workflow

1. **Compile:** open/compile `<key>.tlv` (`makerchip_compile`, `waitForDiagram: true`).
2. **Pick a cycle range** that shows the interesting behavior (see the per-example table / prior
   `capture` fields in `examples.js` for guidance).
3. **Pick playback timing by animation type:**
   - **Static** (state changes per cycle, no `animate()` calls): omit `fps` (1 frame/cycle) and set
     `cyclesPerSecond` (e.g. 2–8 depending on how fast it should read).
   - **Animated** (`.animate(...)` calls, i.e. inter-cycle motion): set `fps` (~18–20) for smooth
     motion, plus a modest `cyclesPerSecond`.
4. **(Optional) cheap framing check:** render a single low-res frame (e.g. 56×40 GIF, same 1.4
   aspect ⇒ identical framing) and view it before committing to the full render.
5. **Render:** `makerchip_capture_video` with `width: 350, height: 250, format: 'mp4',
   mode: 'fit-relative'` (+ `keyframes` only if zooming), writing to `gallery/viz_thumbs/<key>.mp4`.
6. **Verify:** extract a frame and view it —
   `ffmpeg -y -i gallery/viz_thumbs/<key>.mp4 -vf "select=eq(n\,<N>)" -vframes 1 /tmp/check.png`.
7. **Record settings** for the example in its `capture` field in `examples.js` (match the existing
   shape: `startCyc`, `endCyc`, `cyclesPerSecond`, optional `fps`, `interCycleAnimation`, `note`;
   under `fit-relative` also record any zoom `scale`/`focus`, and set `mode: "fit-relative"`).
8. **Wire the gallery:** in `examples.js` set the example's `media` to `"viz_thumbs/<key>.mp4"`
   (relative to `examples.js`, so no `gallery/` prefix) and `preferredFormat` to `"mp4"`.

## Examples to (re-)record

Everything through `tt_um_AES` is already framed well and logged in its `capture` field. Record
these from `mat_mul` onward (gallery order), all currently badly framed or still GIFs:

| key | animation | notes |
|-----|-----------|-------|
| `mat_mul` | animated | output-stationary matrix multiply; `animate()` motion ⇒ set `fps`. |
| `viz_demo` | static | tutorial of 8 separate units (`/example1`…`/example8`) spread across canvas. Whole-design fit shows 8 tiny boxes — either capture the whole spread or zoom onto one representative example. (Its `media` is currently `null`.) |
| `claude_booth_multiplier` | static | Booth multiplier walkthrough. |
| `logic_analyzer` | static | logic-analyzer-style waves. |
| `fifo_viz` | static | FIFO occupancy. |
| `ring_viz` | animated | ring NoC; **startCyc ≥ 4** (early cycles empty); `.animate()` ⇒ set `fps`. |
| `life_minimal` | static | minimal Game of Life. |
| `life_sv_viz` | static | Verilog Game of Life. |
| `knight_rider` | static | LED chaser. |
| `pythagoras_viz` | static | right-triangle solver. |
| `closest_point` | static | nearest-neighbor geometry. |
| `dancing_stick_figure` | static | stick figure poses per cycle. |
| `snakes_and_ladders` | static | board progress. |
| `neural_network_viz` | static | 3-layer NN activations. |
| `claude_uart` | static | UART bit-level waves. |

Confirm animation type per file with:
`grep -nE "\.animate[A-Za-z0-9_]*[[:space:]]*\(" <key>.tlv` (a hit ⇒ animated ⇒ use `fps`).

## Notes

- Files live in `makerchip_examples/` root (except `tt_um_AES` under `tiny_tapeout_examples/`).
- `all_examples` stays a GIF and is not re-recorded.
- Back up any thumbnail you replace if you want to keep the old framing.
