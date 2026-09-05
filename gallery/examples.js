// Per-example VIZ thumbnail capture settings (recording metadata; NOT used by the gallery at
// runtime). Recorded at 350x250 (media-wrap aspect 1.4) as MP4. Entries with `mode:"fit-relative"`
// frame relative to the whole-design fit (`scale` multiplies that fit; `focus` is a fraction of the
// visible area). Entries WITHOUT `mode` use absolute keyframes with width/height = recording dims,
// so `scale` is absolute VIZ px/unit. Entries with inter-cycle animation set `fps`; others render
// 1 frame/cycle at `cyclesPerSecond`. Test framing cheaply with a 56x40 single-frame GIF (same 1.4
// aspect => identical framing). See viz_thumbs/RECORDING.md for the recording workflow.
const captureDefaults = { width: 350, height: 250, format: "mp4", focus: { x: 0, y: 0 } };

const examples = [
  {
    key: "all_examples",
    file: "all_examples.tlv",
    title: "all_examples.tlv",
    desc: "Combines many Makerchip designs into one, illustrating the compositional properties of VIZ and navigation by zoom in/out.",
    media: "viz_thumbs/all_examples.gif",
    preferredFormat: "gif"
  },
  {
    key: "logic_gates",
    file: "logic_gates.tlv",
    title: "logic_gates.tlv",
    desc: "For explaining logic gates and their truth tables.",
    media: "viz_thumbs/logic_gates.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 1, endCyc: 8,
      cyclesPerSecond: 2,
      scale: 0.43, focus: { x: 0, y: 0 },
      interCycleAnimation: false,
      note: "Nearly-square cream box fills frame; 2-bit input counter cycles combos every 4 cycles."
    }
  },
  {
    key: "life_viz",
    file: "life_viz.tlv",
    title: "life_viz.tlv",
    desc: "Conway's Game of Life.",
    media: "viz_thumbs/life_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 0, endCyc: 20,
      cyclesPerSecond: 4,
      scale: 0.417, focus: { x: 0, y: 0 },
      interCycleAnimation: false,
      note: "Square Game-of-Life grid fills height; discrete state per cycle."
    }
  },
  {
    key: "sort_viz",
    file: "sort_viz.tlv",
    title: "sort_viz.tlv",
    desc: "A value sorting circuit.",
    media: "viz_thumbs/sort_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 0, endCyc: 15,
      cyclesPerSecond: 3,
      scale: 0.334, focus: { x: 0, y: 0 },
      interCycleAnimation: false,
      note: "Wide sorting network (aspect ~3); fills width, inherent vertical whitespace (cannot crop stages)."
    }
  },
  {
    key: "DAC_ring_example",
    file: "DAC_ring_example.tlv",
    title: "DAC_ring_example.tlv",
    desc: "A tiny ring NoC example used in a DAC 2020 \"Transcending RTL\" session.",
    media: "viz_thumbs/DAC_ring_example.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 30, endCyc: 42,
      cyclesPerSecond: 1.5, fps: 20,
      scale: 1.15, focus: { x: 0, y: 0.08 },
      interCycleAnimation: true,
      note: "Sparse, oddly-laid-out design: a tall ring column on the left (green/blue hash boxes '8245a33b'/'609168ce' on a black wire loop with traveling dots) plus a small separate ring at top-right. Whole-design fit leaves the two clusters tiny with lots of whitespace ('positioned oddly'); a modest fit-relative zoom (scale 1.15, focus y 0.08) centers and enlarges the content without clipping the main column (faded trailing/history boxes bleed off the left edge, which is fine). Dots animate 700ms -> fps 20."
    }
  },
  {
    key: "frog_maze",
    file: "frog_maze.tlv",
    title: "frog_maze.tlv",
    desc: "A playful maze-solver. The frog must hit walls to align properly to get out.",
    media: "viz_thumbs/frog_maze.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 0, endCyc: 24,
      cyclesPerSecond: 2.5, fps: 20,
      scale: 0.417, focus: { x: 0, y: 0 },
      interCycleAnimation: true,
      note: "Square maze grid fills height; frog hop animation -> fps 20."
    }
  },
  {
    key: "mandelbrot_as_img",
    file: "mandelbrot_as_img.tlv",
    title: "mandelbrot_as_img.tlv",
    desc: "A Mandelbrot generator with VIZ showing the iterative computation and the resulting image.",
    media: "viz_thumbs/mandelbrot_as_img.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 0, endCyc: 48,
      cyclesPerSecond: 8,
      scale: 0.558, focus: { x: 0, y: 0 },
      interCycleAnimation: false,
      note: "Text calc panel (left) + colorful computed image (right), combined aspect ~1.34 fills frame. Image static; red cursor scans pixels per cycle."
    }
  },
  {
    key: "smith_waterman",
    file: "smith_waterman.tlv",
    title: "smith_waterman.tlv",
    desc: "A hardware Smith-Waterman implementation for genome sequence alignment. Computation walks the wavefront in O(n) hardware x O(n) cycles in three passes.",
    media: "viz_thumbs/smith_waterman.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 9, endCyc: 34,
      cyclesPerSecond: 3.5,
      scale: 0.377, focus: { x: 0, y: 0 },
      interCycleAnimation: false,
      note: "Green box + DNA scoring matrix (aspect ~1.55) fills width. startCyc=9 (user); systolic wavefront fills matrix."
    }
  },
  {
    key: "tt_um_AES",
    file: "tiny_tapeout_examples/tt_um_AES.tlv",
    title: "tiny_tapeout_examples/tt_um_AES.tlv",
    desc: "AES encryption final project from a team in a two-week DoD course with Efabless using Tiny Tapeout (VIZ added afterward, based on Wikipedia).",
    media: "viz_thumbs/tt_um_AES.mp4",
    preferredFormat: "mp4",
    capture: {
      startCyc: 24, endCyc: 48,
      cyclesPerSecond: 2.5, fps: 18,
      scale: 12.5, focus: { x: 0, y: -28 },
      interCycleAnimation: true,
      note: "~14x zoom (user) into chip on TinyTapeout board photo to reveal live AES datapath (S-box node network + state byte matrices). Whole-board fit scale ~0.892; 14x -> 12.5. Data flows -> fps 18."
    }
  },
  {
    key: "mat_mul",
    file: "mat_mul.tlv",
    title: "mat_mul.tlv",
    desc: "Output-stationary matrix multiply for ML acceleration concepts.",
    media: "viz_thumbs/mat_mul.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 2, endCyc: 28,
      cyclesPerSecond: 2, fps: 18,
      interCycleAnimation: true,
      note: "fit-relative whole-design fit; 4x4 output-stationary systolic array fills the frame. Data flows in with animate() (360ms) -> fps 18."
    }
  },
  {
    key: "viz_demo",
    file: "viz_demo.tlv",
    title: "viz_demo.tlv",
    desc: "A progressive example teaching VIZ constructs.",
    media: "viz_thumbs/viz_demo.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 28,
      cyclesPerSecond: 3,
      scale: 2.35, focus: { x: -0.185, y: 0 },
      interCycleAnimation: false,
      note: "Tutorial of 9 units spread across the canvas (whole-design fit = tiny boxes + lots of whitespace). Zoomed (scale 2.35, focus x -0.185) to frame Examples 2 & 3 (top row) above 8 & 9 (bottom row) as a 2x2 block: Ex2 blue-box/pink-circle figure, Ex3 three black circles, Ex8 red bar, Ex9 growing red histogram. Static VIZ; values (plant/histogram/circles) update per cycle."
    }
  },
  {
    key: "claude_booth_multiplier",
    file: "claude_booth_multiplier.tlv",
    title: "claude_booth_multiplier.tlv",
    desc: "A Booth multiplier.",
    media: "viz_thumbs/claude_booth_multiplier.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 1, endCyc: 14,
      cyclesPerSecond: 2,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; fixed 'Booth Radix-2 Multiplier' walkthrough panel (aspect ~0.7) fills the frame. Range covers one full 8-iteration multiply into DONE (Product 143 = 13x11)."
    }
  },
  {
    key: "logic_analyzer",
    file: "logic_analyzer.tlv",
    title: "logic_analyzer.tlv",
    desc: "A logic-analyzer example translated from Spade HDL. The VIZ illustrates VIZ overlay on an pre-existing image.",
    media: "viz_thumbs/logic_analyzer.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 12, endCyc: 52,
      cyclesPerSecond: 5,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; 'Quickscope Logic Analyzer' hand-drawn schematic + states legend + output-bytes packet grid fills the frame. Bytes/highlights update per cycle -> cyclesPerSecond 5."
    }
  },
  {
    key: "fifo_viz",
    file: "fifo_viz.tlv",
    title: "fifo_viz.tlv",
    desc: "A simple illustration of a FIFO queue.",
    media: "viz_thumbs/fifo_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 1, endCyc: 22,
      cyclesPerSecond: 3,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; wide 'FIFO (First In, First Out)' panel (circular buffer + physical memory, aspect ~2.4) fills width with inherent vertical margins. Fill/drain phases across cyc 3-19 -> range 1-22."
    }
  },
  {
    key: "ring_viz",
    file: "ring_viz.tlv",
    title: "ring_viz.tlv",
    desc: "A ring network NoC (Network-on-Chip) with input FIFO queues.",
    media: "viz_thumbs/ring_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 4, endCyc: 28,
      cyclesPerSecond: 1.5, fps: 18,
      interCycleAnimation: true,
      note: "fit-relative whole-design fit; ring NoC (4 channel rows + node column) inside outer border. startCyc 4 (cycles 0-3 empty). Packets slide between nodes via animate() -> fps 18."
    }
  },
  {
    key: "life_minimal",
    file: "life_minimal.tlv",
    title: "life_minimal.tlv",
    desc: "Conway's Game of Life, coded minimally.",
    media: "viz_thumbs/life_minimal.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 20,
      cyclesPerSecond: 4,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; square Game-of-Life grid (green cells on dark) fills the frame. Discrete state per cycle."
    }
  },
  {
    key: "life_sv_viz",
    file: "life_sv_viz.tlv",
    title: "life_sv_viz.tlv",
    desc: "Conway's Game of Life implemented in Verilog illustrating VIZ use with Verilog code, showing previous state shadows.",
    media: "viz_thumbs/life_sv_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 20,
      cyclesPerSecond: 4,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; square Verilog Game-of-Life grid (blue live cells + dark-red trails on red) fills the frame. Discrete state per cycle."
    }
  },
  {
    key: "knight_rider",
    file: "knight_rider.tlv",
    title: "knight_rider.tlv",
    desc: "An illustration of simple FPGA logic using the Virtual FPGA Lab showing an LED chaser pattern moving across outputs.",
    media: "viz_thumbs/knight_rider.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 30,
      cyclesPerSecond: 6,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; Basys3 FPGA board photo (aspect ~1.4, matches frame) fills the frame. LED chaser sweeps the bottom LED row + 7-seg display -> cyclesPerSecond 6 for a lively sweep."
    }
  },
  {
    key: "pythagoras_viz",
    file: "pythagoras_viz.tlv",
    title: "pythagoras_viz.tlv",
    desc: "A Pythagorean theorem computation circuit.",
    media: "viz_thumbs/pythagoras_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 24,
      cyclesPerSecond: 3,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; 'Pythagorean Theorem' right-triangle solver (legs/hypotenuse labels + a^2+b^2 sum) fills width, some inherent whitespace below the triangle. Values update per cycle."
    }
  },
  {
    key: "closest_point",
    file: "closest_point.tlv",
    title: "closest_point.tlv",
    desc: "A computational geometry example finding and visualizing nearest-neighbor distances.",
    media: "viz_thumbs/closest_point.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 24,
      cyclesPerSecond: 3,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; nearest-neighbor 'Distance from main point to targets' plot (concentric distance rings + rays to targets) fills the frame, centered. Highlights update per cycle."
    }
  },
  {
    key: "dancing_stick_figure",
    file: "dancing_stick_figure.tlv",
    title: "dancing_stick_figure.tlv",
    desc: "It is what it is.",
    media: "viz_thumbs/dancing_stick_figure.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 0, endCyc: 32,
      cyclesPerSecond: 4,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; 'Silly Dancing Stick Figure!' scene (title + figure + ground line, aspect ~1.4) fills the frame. New pose per cycle -> cyclesPerSecond 4."
    }
  },
  {
    key: "snakes_and_ladders",
    file: "snakes_and_ladders.tlv",
    title: "snakes_and_ladders.tlv",
    desc: "The classic board game implemented in one shot.",
    media: "viz_thumbs/snakes_and_ladders.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 2, endCyc: 40,
      cyclesPerSecond: 4,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; 10x10 board (snakes/ladders) + 'Game status' panel (aspect ~1.4) fills the frame. Two tokens advance one move/cycle -> range 2-40 shows the race progress."
    }
  },
  {
    key: "neural_network_viz",
    file: "neural_network_viz.tlv",
    title: "neural_network_viz.tlv",
    desc: "A 3-layer neural network with inter-layer connections and activation visualization.",
    media: "viz_thumbs/neural_network_viz.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 68, endCyc: 200,
      cyclesPerSecond: 25,
      scale: 3, focus: { x: 0, y: -0.33 },
      interCycleAnimation: false,
      note: "Design is uninteresting until cycle 68, then activations/weights change on cycles 69, 98, 102-103, 132-133, 162, 166-167, 196-197 (200 max). Static VIZ so 1 frame/cycle at 25 cyclesPerSecond (25 fps effective). Zoomed onto the top ~third (scale 3, focus y -0.33): 'Neural Network Architecture' title, Layer 1/2/3 labels, neuron columns and the colorful weighted connections fill the frame."
    }
  },
  {
    key: "claude_uart",
    file: "claude_uart.tlv",
    title: "claude_uart.tlv",
    desc: "A one-shot UART transmitter/receiver with bit-level visualization and protocol state display.",
    media: "viz_thumbs/claude_uart.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 15, endCyc: 75,
      cyclesPerSecond: 5,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; 'UART Transceiver' panel (Transmitter/Serial Line/Receiver/Debug Info) fills the frame. BAUD_DIV=5 in Makerchip mode so ~5 cycles/bit, ~50 cycles/byte; the 15-75 window spans a byte transmission — TX State cycles D0..stop, the Serial Line red-dot bit moves, and the Receiver picks up the byte. Static VIZ (no .animate), so 1 frame/cycle."
    }
  },
  {
    key: "claude_chess_clock",
    file: "claude_chess_clock.tlv",
    title: "claude_chess_clock.tlv",
    desc: "A chess clock.",
    media: "viz_thumbs/claude_chess_clock.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 4, endCyc: 88,
      cyclesPerSecond: 8,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; two cream analog clock faces (with tick marks and sweeping hands) plus toggle buttons fill the frame. Each cycle = 1 minute; random button presses (at $random==20/40/60) switch the active player, so hands advance and the pressed button animates. Static VIZ (no .animate), 1 frame/cycle."
    }
  },
  {
    key: "moku_lfm_chirp_matched_filter",
    file: "moku_lfm_chirp_matched_filter.tlv",
    title: "moku_lfm_chirp_matched_filter.tlv",
    desc: "A one-shot LFM (linear-frequency-modulated) chirp matched filter, as a Moku:Go instrument.",
    media: "viz_thumbs/moku_lfm_chirp_matched_filter.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 2, endCyc: 128,
      cyclesPerSecond: 12,
      scale: 1.7, focus: { x: 0.05, y: 0.24 },
      interCycleAnimation: false,
      note: "LFM chirp matched filter (Moku:Go instrument). Zoomed (scale 1.7, focus x 0.05, y 0.24) onto the signal/correlation waveforms where the incoming chirp is correlated against time-reversed taps, producing the sharp pulse-compression peak. Static VIZ, 1 frame/cycle."
    }
  },
  {
    key: "N-body",
    file: "N-body.tlv",
    title: "N-body.tlv",
    desc: "A fixed-point N-body gravitational simulation, one physics step per clock cycle. Bodies attract and orbit in a 512x512 world.",
    media: "viz_thumbs/N-body.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 100, endCyc: 500,
      cyclesPerSecond: 40,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; fixed-point N-body gravitational simulation in a 512x512 world, one physics step per cycle. startCyc 100 skips the initial settling; 100-500 at 40 cyclesPerSecond (1 frame/cycle) shows bodies attracting and orbiting. Static VIZ (positions update per cycle)."
    }
  },
  {
    key: "uw_ece755",
    file: "uw_ece755.tlv",
    title: "uw_ece755.tlv",
    desc: "A simple neural network from the UW ECE755 course.",
    media: "viz_thumbs/uw_ece755.mp4",
    preferredFormat: "mp4",
    capture: {
      mode: "fit-relative",
      startCyc: 2, endCyc: 40,
      cyclesPerSecond: 4,
      interCycleAnimation: false,
      note: "fit-relative whole-design fit; UW ECE755 course example. Captures a set of random input values and visualizes their flow through a node-based pipeline. Static VIZ, 1 frame/cycle."
    }
  }
];

const grid = document.getElementById("grid");
const tpl = document.getElementById("card-template");
const inlinePanel = document.getElementById("inline-panel");
const inlineTitle = document.getElementById("inline-title");
const inlineFrame = document.getElementById("inline-frame");
const closeInline = document.getElementById("close-inline");
const popoutInline = document.getElementById("popout-inline");

const RAW_BASE = "https://raw.githubusercontent.com/stevehoover/makerchip_examples/master/";
const MAKERCHIP_BASE = "https://www.makerchip.com/sandbox?code_url=";

function makerchipUrlFor(file) {
  return `${MAKERCHIP_BASE}${encodeURIComponent(`${RAW_BASE}${file}`)}`;
}

function openInline(ex) {
  inlineTitle.textContent = ex.title;
  inlineFrame.src = makerchipUrlFor(ex.file);
  inlinePanel.hidden = false;
  document.body.classList.add("panel-open");
}

function closeInlinePanel() {
  inlinePanel.hidden = true;
  inlineFrame.src = "about:blank";
  document.body.classList.remove("panel-open");
}

function popoutInlinePanel() {
  if (!inlineFrame.src || inlineFrame.src === "about:blank") return;
  window.open(inlineFrame.src, "_blank", "noopener,noreferrer");
}

closeInline.addEventListener("click", closeInlinePanel);
popoutInline.addEventListener("click", popoutInlinePanel);
inlinePanel.hidden = true;

for (const ex of examples) {
  const node = tpl.content.cloneNode(true);
  const card = node.querySelector(".card");
  const mediaWrap = node.querySelector(".media-wrap");
  const title = node.querySelector("h2");
  const status = node.querySelector(".status");
  const desc = node.querySelector(".desc");
  const mcLink = node.querySelector(".mc-link");
  const inlineBtn = node.querySelector(".inline-btn");
  const ideBtn = node.querySelector(".ide-btn");

  title.textContent = ex.title;
  desc.textContent = ex.desc;
  mcLink.href = makerchipUrlFor(ex.file);
  inlineBtn.addEventListener("click", () => openInline(ex));
  ideBtn.addEventListener("click", () => openInIde(ex, ideBtn));

  if (ex.media) {
    const isVideo = ex.media.endsWith(".mp4");
    const el = document.createElement(isVideo ? "video" : "img");
    el.src = ex.media;
    if (isVideo) {
      el.muted = true;
      el.loop = true;
      el.playsInline = true;
      el.preload = "metadata";
      el.autoplay = false;
      el.pause();
      el.addEventListener("mouseenter", () => el.play().catch(() => {}));
      el.addEventListener("mouseleave", () => el.pause());
      el.addEventListener("focus", () => el.play().catch(() => {}));
      el.addEventListener("blur", () => el.pause());
    } else {
      el.alt = `${ex.title} capture`;
      el.loading = "lazy";
    }
    mediaWrap.appendChild(el);

    // "Ready" is the normal state; leave the status badge empty so it's hidden.
  } else {
    const pending = document.createElement("div");
    pending.className = "pending";
    pending.textContent = "PENDING CAPTURE";
    mediaWrap.appendChild(pending);

    status.textContent = "Pending";
    status.classList.add("pending");
    card.classList.add("is-pending");
  }

  grid.appendChild(node);
}

// ---------------------------------------------------------------------------
// Makerchip pane integration
//
// When this page is loaded as a *connected* third-party iframe pane inside the
// Makerchip IDE (opened with a channel contract that has `rpc: true`), each card
// shows a single "Open" button (beside the card title) that loads the example
// into the IDE via `setCode`: into the Editor and compiles it, or — when the IDE
// has no Editor pane (hasEditor: false) — headlessly compiles it. When loaded as
// a normal standalone web page, that button is hidden and the usual web links
// (Open Below / Open in Makerchip) are used instead.
//
// The pane<->IDE protocol is a simple postMessage RPC (nothing is injected into
// this page); see doc-src/plugin/Third_Party_Pane_API.md in the mono repo.
// ---------------------------------------------------------------------------

const PANE_V = 1;
let _rpcSeq = 0;
const _rpcPending = new Map();

window.addEventListener("message", (e) => {
  const m = e.data;
  if (!m || m.v !== PANE_V) return;
  if (m.kind === "rpc-result") {
    _rpcPending.get(m.id)?.resolve(m.result);
    _rpcPending.delete(m.id);
  } else if (m.kind === "rpc-error") {
    _rpcPending.get(m.id)?.reject(new Error(m.error));
    _rpcPending.delete(m.id);
  }
});

function callIde(method, ...args) {
  const id = ++_rpcSeq;
  return new Promise((resolve, reject) => {
    _rpcPending.set(id, { resolve, reject });
    // target "ide" is the only supported RPC destination today.
    parent.postMessage({ v: PANE_V, kind: "rpc", id, target: "ide", method, args }, "*");
  });
}

function callIdeWithTimeout(method, args, ms) {
  return Promise.race([
    callIde(method, ...args),
    new Promise((_, reject) => setTimeout(() => reject(new Error("IDE RPC timed out")), ms)),
  ]);
}

async function initPaneMode() {
  // A standalone, top-level page is never a pane.
  if (window.parent === window) return;

  // Announce readiness (harmless if the parent isn't the Makerchip IDE).
  try { parent.postMessage({ v: PANE_V, type: "ready" }, "*"); } catch (_) {}

  // Probe the IDE: if it answers, we're a connected Makerchip pane.
  try {
    await callIdeWithTimeout("getAvailablePanes", [], 1500);
  } catch (_) {
    return; // No Makerchip IDE (plain iframe / other embed) -> stay in web mode.
  }

  document.body.classList.add("pane-mode");
  // Reword the intro: in a pane there are no "open in this page / new tab"
  // choices -- clicking Open loads the example into the current session.
  const intro = document.querySelector(".intro");
  if (intro) {
    intro.textContent =
      "A visual gallery of illustrative Makerchip examples. Mouse over to animate. " +
      "Click Open to load an example into this Makerchip session and compile it.";
  }
  // Move the single "Open" button up beside the card title (to its right,
  // wrapping below when the title is too long -- see styles.css pane-mode rules).
  for (const card of document.querySelectorAll(".card")) {
    const btn = card.querySelector(".ide-btn");
    const metaTop = card.querySelector(".meta-top");
    if (btn && metaTop) {
      btn.textContent = "Load";
      metaTop.appendChild(btn);
    }
  }
}

async function openInIde(ex, btn) {
  if (btn.disabled) return;
  const restore = btn.textContent;
  btn.disabled = true;
  btn.textContent = "Loading\u2026";
  try {
    const res = await fetch(`${RAW_BASE}${ex.file}`);
    if (!res.ok) throw new Error(`Failed to fetch ${ex.file}: HTTP ${res.status}`);
    const code = await res.text();

    // setCode loads the source into the Editor and compiles it; in an editor-less
    // IDE (hasEditor: false) it degrades to a headless compile.
    await callIde("setCode", code);
  } catch (err) {
    console.error("Open in Makerchip failed:", err);
    btn.textContent = "Failed \u2014 retry";
    btn.disabled = false;
    return;
  }
  btn.textContent = restore;
  btn.disabled = false;
}

initPaneMode();
