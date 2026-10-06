# Chapter 4 English figures

The English publication uses `images/articles/04/en/`. Korean originals remain in
`images/articles/04/`. The two static SVGs are editable directly in the English
asset directory. `animation-base.svg` is the shared, square background for the
creation, status-query, and probe animations.

Run from the repository root on macOS with Swift/AppKit, Quick Look, Pillow,
and the system Apple SD Gothic Neo font installed:

```sh
mkdir -p /tmp/ch04-en-render /tmp/ch04-en-swift-cache
qlmanage -t -s 1400 -o /tmp/ch04-en-render scripts/chapter04-en/animation-base.svg
swift -module-cache-path /tmp/ch04-en-swift-cache scripts/chapter04-en/render-ch04-fig3.swift /tmp/ch04-en-render/animation-base.svg.png images/articles/04/en/12-pod-creation-and-replicas.gif
swift -module-cache-path /tmp/ch04-en-swift-cache scripts/chapter04-en/render-ch04-status.swift /tmp/ch04-en-render/animation-base.svg.png images/articles/04/en/14-pod-status-query.gif
swift -module-cache-path /tmp/ch04-en-swift-cache scripts/chapter04-en/render-ch04-three-probes.swift /tmp/ch04-en-render/animation-base.svg.png images/articles/04/en/15-runtime-and-probe-status.gif
/usr/bin/python3 scripts/chapter04-en/make-chapter04-node-recovery-gif.py
/usr/bin/python3 scripts/chapter04-en/make-chapter04-pending-gif.py
```

Use a Python interpreter with Pillow installed if `/usr/bin/python3` does not
provide it. Generators save representative stage images under `/tmp/ch04-en-*`
for layout review. Text rendering fits long English labels within their available
width; review stage images after changing wording or box positions.
