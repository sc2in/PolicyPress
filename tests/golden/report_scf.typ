#set document(
  title: "SCF Coverage Report",
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
      [SCF Coverage Report],
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

  #heading(level: 1, outlined: false)[#text(size: 36pt, weight: "bold")[SCF Coverage Report]]

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

*3* of *5* controls (60%) are covered by at least one published policy.

Coverage means a published policy lists the control in its front-matter taxonomy. Draft policies are excluded, matching the website.

*1* control(s) are declared out of scope by a published policy; an exclusion is a documented decision not to apply a control and is counted separately from coverage.

= Governance

2 of 3 controls covered.

#table(
  columns: (auto, 1fr, 1fr),
  align: (left, left, left),
  table.header(
    [*Control*], [*Name*], [*Covering Policies*],
  ),
  [GOV-01], [Security Governance Program], [Alpha Security Policy; Bravo Handling Policy],
  [GOV-02], [Publishing \*Security\* \[Documentation\] \#with \$pecials], [Alpha Security Policy; Charlie \*Escaping\* \[Policy\] \#1],
  [GOV-03], [Periodic Review], [out of scope: Alpha Security Policy],
)

= Human Resources

1 of 2 controls covered.

#table(
  columns: (auto, 1fr, 1fr),
  align: (left, left, left),
  table.header(
    [*Control*], [*Name*], [*Covering Policies*],
  ),
  [HRS-01], [HR Security Management], [Bravo Handling Policy],
  [HRS-02], [Onboarding & Offboarding], [—],
)
