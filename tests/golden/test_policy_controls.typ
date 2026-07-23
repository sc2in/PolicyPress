#set document(
  title: "Access Control Test Policy",
  author: "Star City Security Consulting",
)

#set image(alt: "Diagram")

#set page(
  paper: "us-letter",
  margin: (x: 2.5cm, y: 2.5cm),
  header: [
    #set text(size: 9pt, fill: rgb("#777777"))
    #grid(
      columns: (1fr, 1fr, 1fr),
      align: (left, center, right),
      [Access Control Test Policy v1.0],
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
)[
  #v(3cm)

  #heading(level: 1, outlined: false)[#text(size: 36pt, weight: "bold")[Access Control Test Policy]]

  #v(0.5cm)
  #text(size: 18pt)[Version v1.0]

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

== Purpose
Access is least-privilege #footnote[IAC-01 — Identity & Access Management. praxis: in control spine. Covered by: Access Control Test Policy.] enforced across all systems.

== Data protection
All data is classified and protected #footnote[DCH-01 — Data Protection. praxis: not in control spine. Covered by: Access Control Test Policy.] according to its sensitivity.


#pagebreak()
= Version History

#table(
  columns: (auto, auto, 1fr, auto, auto),
  align: (center, center, left, center, center),
  table.header(
    [*Version*], [*Date*], [*Description*], [*Revised By*], [*Approved By*],
  ),
  [1.0],
  [2025-06-24],
  [Initial version.],
  [Ada Byrne],
  [Ada Byrne],
)
