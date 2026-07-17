#set document(
  title: "Policy Review Report",
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
      [Policy Review Report],
      [],
      [],
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

  #heading(level: 1, outlined: false)[#text(size: 36pt, weight: "bold")[Policy Review Report]]

  #v(1.5cm)
  #line(length: 100%, stroke: 4pt + rgb("#0e90f3"))

  #text(size: 18pt)[Star City Security Consulting]

  #v(1fr)

  #text(size: 11pt)[Generated: 2026-01-01]
]

#outline(
  title: "Contents",
  depth: 3,
)

= Summary

*4* published policies; *1* overdue for review (last reviewed more than 365 days before this report was generated).

= Review Status

#table(
  columns: (1fr, auto, auto, auto, auto),
  align: (left, center, left, center, center),
  table.header(
    [*Policy*], [*Version*], [*Owner*], [*Last Reviewed*], [*Status*],
  ),
  [Bravo Handling Policy], [v1.0], [People Ops], [2024-06-01], table.cell(fill: rgb("#f09d9d"))[Overdue],
  [Charlie \*Escaping\* \[Policy\] \#1], [], [—], [2025-03-15], table.cell(fill: rgb("#e2bc76"))[Due soon],
  [Alpha Security Policy], [v2.0], [Security Team], [2025-12-01], table.cell(fill: rgb("#a2dea2"))[Current],
  [Delta Undated Policy], [], [—], [not-a-date], [Unknown],
)
