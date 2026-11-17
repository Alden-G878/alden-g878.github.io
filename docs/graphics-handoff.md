# Graphics plan and handoff — portfolio entries

> **Status:** evidence audit complete; three demo renders produced to prove the
> toolchain; no figure is published yet and no layout support exists.
> **Date:** 2026-11-17
> **Scope:** figure production for the 17 published entries (14 in `_projects/`,
> 3 in `_research/`) and the minimum display path a figure needs to render.
> **Out of scope:** everything else — the CV surfaces (`cv/`), entry prose and
> claims, dates, context fields, taxonomy, the homepage teaser, new entries.

---

## 1. Where the site stands

- **17 entries, zero content images.** `assets/images/projects/` is empty; the only
  images referenced anywhere in the repo are the favicons in
  `_includes/head/custom.html`.
- **No plumbing.** `_layouts/project.html` has no figure block,
  `_includes/project-card.html` has no media slot, and `assets/css/main.scss` has
  no `img`/`figure` rules (it only styles project cards and the CV embed). A
  graphic therefore cannot be added by dropping a file into `assets/` — §6 is the
  prerequisite for everything in §3.
- **No stated image policy.** The nearest existing guidance is
  `docs/machine-readability.md`: raw-HTML and LLM readers see the DOM without CSS,
  so `alt` text is load-bearing, not decorative.

## 2. Evidence inventory

Grades: **◆** source + results (+ visuals); **●** source and/or real data;
**○** adjacent artifacts only; **·** nothing beyond the site file itself.

| Entry | Evidence on this machine | Grade |
|---|---|---|
| CPU Arithmetic Coprocessor | none — no multicycle/microcode/coprocessor HDL under `Documents/` or `Downloads/` | · |
| Decision Tree Training Accelerator | `~/Downloads/rtl/` — `gini.sv`, `div.sv`, `mult.sv`, `best_test.sv`, `studentlib.sv`, `gatelib.v` + TBs (9 `.sv`), `inter.vpd` VCS dump; no report | ● |
| RTOS and Bootloader (STM32F401RE) | `~/Documents/cmu/18349/` — four lab repos, ~120 files, **11,956 lines** of C/H/asm: bootloader (`kernel/asm/boot.S`, IVT + `.data`/`.bss`), drivers (gpio, uart, i2c, adc, lcd via PCF8574→HD44780, keypad, printk), timers/interrupts/syscalls (systick, nvic, exti, svc_handler, MPU, user mode), RTOS (`syscall_thread.c`: MSP/PSP, per-thread MPU, 16-thread table, priorities + C/T), quadrature encoder, H-bridge motor driver, `python/pid.py` + `visualize.py` | ◆ |
| FP32 FPU + Systolic Array | `~/Downloads/18340_proj3/project3` (fpu, fpu_wrapper, sys_arr, 2 TBs, test vectors, weight/label/feature data) + `project3_report.pdf`; `~/Documents/cmu/18340/projects/p4` (fp8_e4m3, exp/div/softmax cores) + P4 report (33/40 accuracy, 23.72 ns path, 41.77 MHz, area 281,298) | ◆ |
| KNN Accelerator | `~/Documents/cmu/18340/projects/p1/rtl` — knn, distance, sort, vote, tb_knn, studentlib/gatelib (9 `.sv`) + extra-credit variant + train/test `.dat`; no timing report | ● |
| Matrix Multiply | `~/Documents/cmu/18341/p2-matrix-Alden-G878` — RTL, TB, `multiplier_8816.v`, ROMs, 9 `.mif`, `sim_out.csv` (32,785-line sim trace), 4 Quartus screenshots | ● |
| Network-on-a-Chip | `~/Documents/cmu/18341/p3-noc-Alden-G878` — Router/Node/Top + 4 TBs; `images/` Overview, Router, InsideTheNode, Arrays, Waveforms ×2 (12 PNG counting the `Downloads/` copy) | ● |
| Physics Engine ASIC | `~/sandsim` (~1 GB) — TT RTL + cocotb tests + full LibreLane run (13 GDS, DEF/SDF/SPEF, 536 `.rpt`), `metrics.csv` (327 rows; die 75,602 µm², 4,458 stdcells, 56.6 % util, skew +0.275/−0.265 ns), `docs/info.md` (36×48 grid) | ◆ |
| Robobuggy | `~/Documents/cmu/robobuggy` — Teensy firmware with `micros()` control-latency instrumentation + UKF, `robobuggy-pcb/teensy-breakout` (sch+pcb), 215 telemetry logs (43 × 5 channels), `plot.py`, 2 logos; no photos | ◆ |
| Robotics Club Electronics | `~/Documents/cmu/roboclub` — robot-board 2026 (KiCad + Sierra package: fab drawing, assembly top/bottom, drill charts, BOM/POS/XYRS), line-sensor, 7-seg, RedRobotBreakout 2023, combat PDB; 26 gerbers; only joke renders | ○ |
| RV32I Core | none — `~/Documents/cmu/18447/` holds one homework text file; no RTL, no benchmark, no waveform | · |
| Standard Cell Library | none — no 45 nm PDK, no own SPICE decks, no LEF/Liberty | · |
| STA Tool | none — `~/Documents/cmu/fibonacci/` is a stock Yosys clone carrying only `fib.sv` (Synlig test) | · |
| USB 2.0 Hardware | none | · |
| DCDL (research) | none — `Documents/pll28/` is the ADPLL; io_harness has no DCDL module | · |
| Nanopositioning (research) | `~/Documents/cmu/hackerfab/fall2025/hackerfab-positioning` — Teensy 4.1 PlatformIO firmware (main, stepper, piezo, encoder, software-serial) + "V4 … less backlash" README; summer OpenFlexure tree is upstream | ● |
| ADPLL + I/O Harness (research) | `~/Documents/cmu/io_harness/IO-Harnesses` — 77 `.sv` (IDM, IVM/scan chain, data router, UART/I2C/SPI/SpaceWire, west fabric), docs with `io_harness-System.png`, `harness_example.svg`/drawio, TikZ `diagramlib.tex`, PCB specs; `~/Documents/pll28` — 3 finished ADPLL figures; `physics/pys_m.py` three-body sim. Missing: ADPLL RTL (`rtl/PLL` is empty), all TSMC 28 nm data | ◆ |

**Six entries have no artifact at all:** `cpu-arithmetic-coprocessor`,
`rv32i-core`, `standard-cell-library-design`, `static-timing-analysis-tool`,
`usb-2-0-hardware`, `dcdl-design-space-exploration`. Do not illustrate these from
memory: a block diagram of a design whose source does not exist here would assert
detail the page cannot corroborate, which is the failure mode `notes_missing_data:
true` was invented to prevent. Leave them text-only unless the original course/lab
repo is recovered.

## 3. Graphics plan

Effort: **S** ≤ 30 min, **M** 1–2 h, **L** ≥ half day. "Ready" = the asset exists
and only needs cropping/sizing.

| Entry | Figures | Source of truth | Effort | State |
|---|---|---|---|---|
| Physics Engine ASIC | GDS layout, zoomed core detail, metrics table, block diagram (row buffer / QSPI / VGA shift-out), 96→12 B + 3× cycles bars | `runs/*/final/gds`, `metrics.csv`, `docs/info.md`, `src/` | S + S + S + M + S | layout demo ready |
| ADPLL + I/O Harness | `adpll_blocks.png`, `adpll_dco.png`, `io_harness-System.png`, `harness_example.svg`, three-body animation | `Documents/pll28`, `io_harness/docs/images`, `physics/pys_m.py` | S ×4 + M | four assets ready |
| RTOS and Bootloader (STM32F401RE, 18-349) | boot memory map (IVT → `.text` → `.data` copy → `.bss` → MSP/PSP + per-thread stacks), encoder quadrature FSM, scheduler timeline from real C/T (3/10 ms prio 0, 100/300 ms prio 1), lab-2 wiring (MCU → I2C1 → PCF8574 → HD44780, keypad, UART) | `kernel/asm/boot.S` + linker script; `user_proj/default/src/main.c`; `kernel/src/syscall_thread.c`; `kernel/include/*.h` | M + S + S/M + S | nothing drawn |
| FP32 FPU + Systolic Array | FPU block diagram (align → add/sub → normalize → round, sticky/priority-encoder paths), systolic tile diagram, accuracy bar P3 33/40 vs P4, critical path 23.94 ns vs 100 MHz target | `project3_report.pdf`, `Project 4 report.pdf`, RTL | M + M + S + S | nothing drawn |
| Matrix Multiply | streaming/cycle chart from `sim_out.csv`, Fmax panel re-cropped from Quartus, DSP+ROM datapath | `sim_out.csv`, `images/Fmax_Summary.png`, RTL | S + S + M | nothing drawn |
| Network-on-a-Chip | Overview/Router/InsideTheNode, waveform panel, or a redrawn top-level from `Router.sv` | `images/*.png` (handout), `Router.sv` | S ×2 / M | assets exist, provenance caveat |
| Robobuggy | UKF trajectory, PCB top view, encoder/speed plots, control-latency histogram | 215 SD-card logs, `teensy-breakout.kicad_pcb`, firmware instrumentation | S + S + S + M | trajectory + PCB demos ready |
| Robotics Club Electronics | robot-board render, assembly drawing from the Sierra package, line-sensor/7-seg renders | `*.kicad_pcb`, `sierra/drawings/*.pdf` | S ×3 | PCB demo ready |
| Decision Tree Accelerator | Gini datapath (3× divide → multiply → sum), cycles/op bar (32→1, CV-sourced) | `Downloads/rtl/*.sv` | M + S | nothing drawn; `.vpd` needs VCS |
| KNN Accelerator | pipeline/datapath (distance → sort → vote); **no** Fmax figure — the 300 MHz claim has no local report | `18340/projects/p1/rtl` | M | nothing drawn |
| Nanopositioning | firmware/hardware block diagram (Teensy ↔ stepper/piezo/encoder); a build photo must come from the lab | `hackerfab-positioning/Firmware/src` | M | nothing drawn |
| 6 empty entries | — | — | — | not possible |

## 4. Toolchain verified here

All four commands below were run on this machine on 2026-11-17; output was
inspected, not assumed.

**KiCad board → figure** (KiCad 10.0.8 is a flatpak; `kicad-cli` is not on `PATH`):

```bash
flatpak run --command=kicad-cli org.kicad.KiCad pcb export pdf \
  -o /tmp/board.pdf -l F.Cu,B.Cu,F.Silkscreen,Edge.Cuts --mode-single board.kicad_pcb
pdftoppm -r 300 -png -singlefile /tmp/board.pdf /tmp/board
magick /tmp/board.png -trim +repage -resize 1200x /tmp/board-web.png
```

The PDF is an A4 page with the board centred, so `-trim` is required: the
untouched 150 dpi render of `robot-board` was 1754×1241 and trimmed to 445×605.
`--include-border-title` is opt-in, so no title block appears unless asked for.
SVG export works too, but nothing here rasterises SVG cleanly — `magick` falls
back to an internal renderer after the Inkscape delegate fails, and it keeps the
page frame. PDF → `pdftoppm` is the reliable path.

**GDS → figure** (KLayout 0.30.13, no root install):

```ruby
# gds2png.rb — run with: ~/eda/bin/kl -b -r gds2png.rb
app = RBA::Application.instance
lv = RBA::LayoutView::new
lv.load_layout("/home/cleo/sandsim/runs/wokwi/final/gds/tt_um_sandsim_Alden_G878.gds", 0)
lv.max_hier
lv.zoom_fit
lv.save_image("/tmp/layout.png", 1600, 1600)
lv.destroy
```

1600 px is legible as a whole-die figure; for a detail shot, set the view box to a
core sub-rectangle instead of `zoom_fit`.

**Plots:** `/usr/bin/python3` has matplotlib 3.10.7. Note that bare `python3` on
`PATH` is a Hermes venv **without** matplotlib — use the absolute path, or the
`gestalt` venv (3.11.2).

**Numbers out of PDFs:** `pdftotext file.pdf -` (used for the P3/P4 reports).

## 5. Provenance and honesty rules

- **Course handout figures are not yours.** The 18-341 `images/` set (Overview,
  Router, InsideTheNode, Arrays, Waveforms) is drawn in the handout's visual
  language. Either caption them as the course figure or redraw from `Router.sv`.
- **Screenshots leak context.** `p2-matrix/images/Timing_Analyzer.png` shows a
  Windows desktop with `C:/Users/danie/...` in the path bar — a lab machine, not
  this account. Crop the chrome or use the Fmax summary panel only.
- **Upstream repo assets are not your work.** The 244 photos under
  `hackerfab/summer2025/OpenFlexure microscope/` are OpenFlexure documentation.
- **Group repo assets are group work.** `io_harness-System.png`,
  `harness_example.svg` come from the group's repo — attribute to the group.
- **Modelled ≠ measured.** The 18-349 scheduler timeline is derived from
  `thread_create()` C/T parameters, not from a trace. Label it that way, or add a
  per-switch timestamp and re-flash. Same rule for the "32→1 cycles" and
  "96→12 bytes" bars: they restate CV claims, so the caption should say so.
- Never synthesise a plot from plausible-looking numbers. Six entries have no
  data; that is the finding, not a gap to paper over.

## 6. Site plumbing — the only website change this plan needs

Front matter, per entry — one teaser and an optional figure list:

```yaml
image: /assets/images/projects/<slug>/teaser.png      # card thumbnail
image_alt: "Falling-sand ASIC die after place and route"
figures:
  - src: /assets/images/projects/<slug>/layout.png
    alt: "Sky130 layout, 4,458 standard cells"
    caption: "LibreLane output, 1600 px KLayout render."
```

`_layouts/project.html` — insert after `{{ content }}` and before the Tech Stack
section, so prose introduces the figures and chips stay last:

```liquid
{% if page.figures %}
  <section class="project-figures">
    {% for fig in page.figures %}
      <figure class="project-figure">
        <img src="{{ fig.src | relative_url }}" alt="{{ fig.alt }}" loading="lazy">
        {% if fig.caption %}<figcaption>{{ fig.caption }}</figcaption>{% endif %}
      </figure>
    {% endfor %}
  </section>
{% endif %}
```

`_includes/project-card.html` — insert directly after the closing `</div>` of
`.project-card__header`, so the thumbnail sits under the title and badges:

```liquid
{% if entry.image %}
  <a class="project-card__media" href="{{ entry.url | relative_url }}">
    <img src="{{ entry.image | relative_url }}"
         alt="{{ entry.image_alt | default: entry.title }}" loading="lazy">
  </a>
{% endif %}
```

`assets/css/main.scss` — append after the `.project-card__repo` block (the theme is
`remote_theme`, so this file is the only extension point):

```scss
.project-card__media { display: block; margin: 0 0 .75rem; }
.project-card__media img { width: 100%; height: auto; display: block; border-radius: 3px; }

.project-figures { margin: 1.75rem 0; }
.project-figure { margin: 1.5rem 0; }
.project-figure img { width: 100%; height: auto; border: 1px solid #e5e5e5; border-radius: 4px; }
.project-figure figcaption { font-size: .85rem; color: #6b7280; margin-top: .5rem; }
```

Conventions: SVG for diagrams, PNG for layout renders and screenshots; 1200–1600 px
wide; under ~400 kB each; `alt` always present (see `docs/machine-readability.md`);
one file per slug under `assets/images/projects/<slug>/`.

Verify with `bundle exec jekyll build` (Ruby 3.2 toolchain — see
`docs/build-performance-plan.md`), then check one entry page and one card. CI
(`.github/workflows/deploy.yml`) rebuilds and deploys on every push to `main`
after `cv/build.sh`, so a layout change ships the same way the team fix did.

## 7. Work order

1. **Plumbing (§6)** — nothing can land without it. Acceptance: one dummy figure
   renders on an entry page and on its card, `jekyll build` clean.
2. **Physics Engine ASIC** — layout, metrics table, zoom; the deepest evidence on
   the site and the strongest first impression.
3. **ADPLL + I/O Harness** — four assets already exist; mostly captioning.
4. **RTOS and Bootloader** — FSM and memory map from the code; highest
   figure-count per hour. Caption in STM32F401RE / Cortex-M4F terms.
5. **Robobuggy** — trajectory and PCB are done; fix the timestamp colourbar (logs
   are per-run, so absolute ms is meaningless) and add a speed plot.
6. **Network-on-a-Chip** — after the provenance decision.
7. **Matrix Multiply** — chart from `sim_out.csv`.
8. **Robotics Club Electronics** — board render; the page is one line of text.
9. **FP32 FPU** — two drawings plus two bars from report numbers.
10. **Decision Tree, KNN** — datapath diagrams only.

## 8. Artifacts on disk

Demos from the audit (not part of the site build, nothing under `assets/`):

- `~/Documents/website/graphics-audit/sandsim-gds-klayout-1600.png` — KLayout
  re-render of `tt_um_sandsim` at 1600 px.
- `~/Documents/website/graphics-audit/robobuggy-ukf-trajectory.png` — 62,027
  recovered UKF positions from the 43 filter logs; colourbar needs the per-run fix.
- `~/Documents/website/graphics-audit/robot-board-top.png` — robot-board F.Cu +
  silkscreen via kicad-cli → PDF → PNG.

Scratch scripts used: `~/.hermes/cache/scratch/kicadtest/{gds2png.rb,plot.py}`
(pruned after 24 h idle — copy them somewhere durable before relying on them).
