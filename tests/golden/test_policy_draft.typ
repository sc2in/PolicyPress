#set document(
  title: "Test Policy",
  author: "Star City Security Consulting",
)

#set image(alt: "Diagram")

#let _pp_draft_bg = place(center + horizon, image("/static/draft.png", width: 100%))

#set page(
  paper: "us-letter",
  margin: (x: 2.5cm, y: 2.5cm),
  background: _pp_draft_bg,
  header: [
    #set text(size: 9pt, fill: rgb("#777777"))
    #grid(
      columns: (1fr, 1fr, 1fr),
      align: (left, center, right),
      [Test Policy v1.1],
      [],
      [#image("/static/logo.png", height: 20pt)],
    )
  ],
  footer: [
    #set text(size: 9pt, fill: rgb("#777777"))
    #grid(
      columns: (1fr, 1fr, 1fr),
      align: (left, center, right),
      [Star City Security Consulting © 2026],
      [Confidential],
      [#context counter(page).display("1")],
    )
  ],
)

#set text(
  font: "Source Sans 3",
  size: 11pt,
  lang: "en",
)

#show raw: set text(font: ("Source Code Pro", "DejaVu Sans Mono"))

#show raw.where(block: true): it => block(
  fill: rgb("#F7F7F7"),
  inset: 10pt,
  radius: 4pt,
  width: 100%,
  stroke: 0.5pt + rgb("#DDDDDD"),
  it,
)

#show heading: it => {
  set text(fill: rgb("#282828"))
  it
}

#show link: set text(fill: rgb("#A50000"))

#show figure.caption: it => {
  set text(fill: rgb("#777777"), size: 9pt)
  it
}

#set table(
  fill: (_, row) => if row == 0 { rgb("#EEEEEE") } else if calc.odd(row) { white } else { rgb("#F7F7F7") },
  stroke: rgb("#999999"),
)

// ── Title page ─────────────────────────────────────────────────────────
#page(
  margin: (x: 2.5cm, y: 2.5cm),
  header: none,
  footer: none,
  background: _pp_draft_bg,
)[
  #v(3cm)

  #heading(level: 1, outlined: false)[#text(size: 36pt, weight: "bold")[Test Policy]]

  #v(0.5cm)
  #text(size: 18pt)[Version v1.1]

  #v(1.5cm)
  #line(length: 100%, stroke: 4pt + rgb("#0e90f3"))

  #text(size: 18pt)[Star City Security Consulting]

  #v(1fr)

  #image("/static/logo.png", width: 6cm)

  #text(size: 11pt)[Last Reviewed: 2025-02-24]
]

#outline(
  title: "Contents",
  depth: 3,
)

== Introduction
Star City Security Consulting is committed to testing its policy center.

== Mermaid
#{
  let d = bytes("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"220\" height=\"496\" viewBox=\"0 0 220 496\">
<defs>
  <marker id=\"arrow\" markerWidth=\"10\" markerHeight=\"7\" refX=\"10\" refY=\"3.5\" orient=\"auto\">
    <polygon points=\"0 0, 10 3.5, 0 7\" fill=\"#333333\"/>
  </marker>
  <marker id=\"arrow-open\" markerWidth=\"10\" markerHeight=\"7\" refX=\"10\" refY=\"3.5\" orient=\"auto\">
    <polyline points=\"0 0, 10 3.5, 0 7\" fill=\"none\" stroke=\"#333333\" stroke-width=\"1.5\"/>
  </marker>
</defs>
<rect x=\"0.00\" y=\"0.00\" width=\"220.00\" height=\"496.00\" rx=\"0.00\" fill=\"#ffffff\" stroke=\"#ffffff\" stroke-width=\"0.0\"/>
<path d=\"M 110.0 84.0 L 110.0 124.0 L 110.0 124.0 L 110.0 164.0\" fill=\"none\" stroke=\"#333333\" stroke-width=\"1.5\"/>
<polygon points=\"105.5,156.0 110.0,164.0 114.5,156.0\" fill=\"#333333\" stroke=\"#333333\" stroke-width=\"0.0\"/>
<path d=\"M 110.0 208.0 L 110.0 248.0 L 110.0 248.0 L 110.0 288.0\" fill=\"none\" stroke=\"#333333\" stroke-width=\"1.5\"/>
<polygon points=\"105.5,280.0 110.0,288.0 114.5,280.0\" fill=\"#333333\" stroke=\"#333333\" stroke-width=\"0.0\"/>
<path d=\"M 110.0 208.0 L 110.0 310.0 L 110.0 310.0 L 110.0 412.0\" fill=\"none\" stroke=\"#333333\" stroke-width=\"1.5\"/>
<polygon points=\"105.5,404.0 110.0,412.0 114.5,404.0\" fill=\"#333333\" stroke=\"#333333\" stroke-width=\"0.0\"/>
<path d=\"M 110.0 332.0 L 110.0 372.0 L 110.0 372.0 L 110.0 412.0\" fill=\"none\" stroke=\"#333333\" stroke-width=\"1.5\"/>
<polygon points=\"105.5,404.0 110.0,412.0 114.5,404.0\" fill=\"#333333\" stroke=\"#333333\" stroke-width=\"0.0\"/>
<rect x=\"96.50\" y=\"228.00\" width=\"27.00\" height=\"16.00\" rx=\"2.00\" fill=\"#ffffff\" stroke=\"none\" stroke-width=\"0.0\"/>
<text x=\"110.00\" y=\"242.00\" fill=\"#333333\" font-size=\"12\" text-anchor=\"middle\" font-weight=\"normal\" font-family=\"Source Sans 3, DejaVu Sans, sans-serif\">Yes</text>
<rect x=\"100.00\" y=\"290.00\" width=\"20.00\" height=\"16.00\" rx=\"2.00\" fill=\"#ffffff\" stroke=\"none\" stroke-width=\"0.0\"/>
<text x=\"110.00\" y=\"304.00\" fill=\"#333333\" font-size=\"12\" text-anchor=\"middle\" font-weight=\"normal\" font-family=\"Source Sans 3, DejaVu Sans, sans-serif\">No</text>
<rect x=\"40.00\" y=\"40.00\" width=\"140.00\" height=\"44.00\" rx=\"4.00\" fill=\"#ececff\" stroke=\"#9370db\" stroke-width=\"1.5\"/>
<text x=\"110.00\" y=\"66.00\" fill=\"#333333\" font-size=\"14\" text-anchor=\"middle\" font-weight=\"normal\" font-family=\"Source Sans 3, DejaVu Sans, sans-serif\">Start</text>
<polygon points=\"110.0,164.0 180.0,186.0 110.0,208.0 40.0,186.0\" fill=\"#ececff\" stroke=\"#9370db\" stroke-width=\"1.5\"/>
<text fill=\"#333333\" font-size=\"14\" text-anchor=\"middle\" font-weight=\"normal\" font-family=\"Source Sans 3, DejaVu Sans, sans-serif\"><tspan x=\"110.00\" y=\"182.00\">Is it a</tspan><tspan x=\"110.00\" y=\"198.00\">test?</tspan></text>
<rect x=\"40.00\" y=\"288.00\" width=\"140.00\" height=\"44.00\" rx=\"4.00\" fill=\"#ececff\" stroke=\"#9370db\" stroke-width=\"1.5\"/>
<text x=\"110.00\" y=\"314.00\" fill=\"#333333\" font-size=\"14\" text-anchor=\"middle\" font-weight=\"normal\" font-family=\"Source Sans 3, DejaVu Sans, sans-serif\">Run tests</text>
<rect x=\"40.00\" y=\"412.00\" width=\"140.00\" height=\"44.00\" rx=\"4.00\" fill=\"#ececff\" stroke=\"#9370db\" stroke-width=\"1.5\"/>
<text x=\"110.00\" y=\"438.00\" fill=\"#333333\" font-size=\"14\" text-anchor=\"middle\" font-weight=\"normal\" font-family=\"Source Sans 3, DejaVu Sans, sans-serif\">End</text>
</svg>
")
  layout(size => {
    let img = image(d, format: "svg")
    if measure(img).width > size.width { image(d, format: "svg", width: 100%) } else { img }
  })
}

== Zola link replacement
#link("http://localhost:1111/policies/aeip.html")[policy]

#link("http://localhost:1111/policies/")[section]

#link("http://localhost:1111/policies/incident/digital-forensics/")[directory]

== Redaction
This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.


#pagebreak()
= Version History

#table(
  columns: (auto, auto, 1fr, auto, auto),
  align: (center, center, left, center, center),
  table.header(
    [*Version*], [*Date*], [*Description*], [*Revised By*], [*Approved By*],
  ),
  [1.1],
  [2025-06-24],
  [Demo revision.],
  [Ben Craton],
  [Ben Craton],
  [1.0],
  [2024-02-11],
  [Initial version.],
  [Ben Craton],
  [Ben Craton],
)
