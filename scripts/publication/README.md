# Chapters 1–7 publication assets

The drafts are the Korean source of truth. Publication copies use GitHub raw
image URLs and omit local-preview alignment wrappers. English translations retain
the same paragraphs, examples, command output, and citations.

Run from the repository root with `/usr/bin/python3` on macOS (Pillow and the
system Apple SD Gothic Neo/Menlo fonts):

```sh
/usr/bin/python3 scripts/make-chapter03-namespace-diagram.py --en
/usr/bin/python3 scripts/publication/rebuild-chapters.py
/usr/bin/python3 scripts/publication/render-ch04-lifecycle.py
/usr/bin/python3 scripts/publication/render-ch04-lifecycle.py --en
/usr/bin/python3 scripts/render-chapter04-probe-flows.py
/usr/bin/python3 scripts/render-chapter04-probe-flows.py --en
/usr/bin/python3 scripts/publication/render-ch05-english.py
/usr/bin/python3 scripts/publication/validate-chapters.py
```

`*.translations.json` maps each draft block to its reviewed English translation.
The publication builder stops if a draft block has changed and needs review.
`probe-labels.en.json` supplies English diagram labels. Fig 3/4 reuse the English
stage descriptions in the older Swift source files, but use the current Python
renderer and the same cluster layout as Fig 5/6.

The linked SVG files are directly editable sources. Chapter 1 uses Fig 1–18 (its introductory Docker logo is unnumbered);
chapter 2 uses Fig 1–17; chapter 3 uses Fig 1–11;
chapter 4 uses Fig 1–6; chapter 5 uses Fig 1–3. Fig 1 is the shared official logo. Text-free illustrations
and official resource icons are shared across languages. Korean diagrams are in
`images/articles/02`, `03`, `04`, and `05`; corresponding English diagrams are in each
`en` subdirectory. Keep figure labels and arrow geometry synchronized across languages.

Both GIF renderers check text bounds and decode every output frame. Identical
hold frames may be merged by the encoder, so validation checks total duration
rather than requiring one output frame for every input image. Contact sheets
are written under `/tmp` for visual review. Preview sheets may be scaled;
inspect full-size frames when checking label placement.

The validator checks draft/publication parity, translation completeness, image
paths, language-specific image selection, reference anchors, unchanged code
values and command output, SVG parsing, and complete GIF decoding.

## English figure review

- Match the current draft’s components, state values, control and traffic paths,
  and figure numbers before reusing an older English asset.
- Translate labels and captions, preserving commands, API keys, names, and values.
- Keep official marks and text-free illustrations shared across languages.
- Fit English labels with concise wording, line breaks, and suitable box sizes;
  do not let labels cross borders, arrows, or adjacent text.
- Render SVGs for visual review and inspect every distinct GIF stage. Decode all
  GIF frames and verify loop settings and total duration.
- For macOS Quick Look previews, use temporary SVG copies whose root width is
  at most 760px with a proportional height and the original viewBox. This avoids
  clipping by its web viewport; do not change publication dimensions for previews.

Chapter 5 uses `ch05-labels.en.json` with the original Python renderers to keep
English figures synchronized with Korean geometry. The English renderer checks
component text bounds and writes full-size stage previews under `/tmp`.

## Chapter 7

Build only chapter 7 without rewriting the other publication copies:

```sh
/usr/bin/python3 scripts/publication/rebuild-chapters.py 07-ingress-and-https
/usr/bin/python3 scripts/publication/prepare-ch07-english.py
swift -module-cache-path /tmp/ch07-swift-cache /tmp/ch07-english/make-chapter07-concept-visuals.swift
swift -module-cache-path /tmp/ch07-swift-cache /tmp/ch07-english/make-chapter07-controller-figure.swift
swift -module-cache-path /tmp/ch07-swift-cache /tmp/ch07-english/make-chapter07-tls-gif.swift
swift -module-cache-path /tmp/ch07-swift-cache /tmp/ch07-english/make-chapter07-diagnosis-figure.swift
/usr/bin/python3 scripts/publication/validate-chapters.py 07-ingress-and-https
```

The eight figures include six static diagrams and two nine-stage animations.
`ch07-labels.en.json` translates the original Swift renderers while preserving
layout, routing, timing, and frame counts. English labels are fitted to their
reserved widths with a 16px minimum; overflow and arrow/label overlap checks
remain enabled. The Kubernetes and CKA logos and text-free illustrations are
shared. Only explanatory certificate placeholders are translated in YAML;
resource names, field values, commands, and output are preserved.
