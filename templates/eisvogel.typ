// ==========================================================================
// Eisvogel-style Typst template for Pandoc
// Ported from the Eisvogel pandoc-latex-template
// https://github.com/Wandmalfarbe/pandoc-latex-template
//
// Usage:
//   pandoc input.md -o output.pdf \
//     --template eisvogel.typ \
//     --pdf-engine=typst
// ==========================================================================

// ---------------------------------------------------------------------------
// Pandoc-required definitions
// Pandoc's Typst writer emits these in the body; they MUST be defined
// or you get "unknown variable" errors.
// ---------------------------------------------------------------------------
#let horizontalrule = block(
  width: 100%,
  v(0.5em) + line(start: (25%, 0%), end: (75%, 0%), stroke: 0.5pt + gray) + v(0.5em)
)

// Endnote support (pandoc may emit this for certain footnote styles)
#let endnote(num, contents) = [
  #super(num)
  #contents
]

// ---------------------------------------------------------------------------
// Color Definitions
// ---------------------------------------------------------------------------
#let heading-color = rgb("#282828")
#let link-color = rgb("#A50000")
#let url-color = rgb("#4077C0")
#let cite-color = rgb("#4077C0")
#let caption-color = rgb("#777777")
#let blockquote-border = rgb("#DDDDDD")
#let blockquote-text = rgb("#777777")
#let table-row-color = rgb("#F5F5F5")
#let table-rule-color = rgb("#999999")
#let listing-background = rgb("#F7F7F7")
#let listing-rule = rgb("#B3B2B3")

// ---------------------------------------------------------------------------
// Template Function
// ---------------------------------------------------------------------------
#let eisvogel(
  // --- Metadata ---
  title: none,
  subtitle: none,
  authors: (),
  date: none,
  last-reviewed: none,
  abstract: none,
  keywords: (),
  subject: none,
  lang: "en",

  // --- Title Page ---
  titlepage: true,
  titlepage-color: none,
  titlepage-text-color: rgb("#5F5F5F"),
  titlepage-rule-color: rgb("#435488"),
  titlepage-rule-height: 4pt,
  titlepage-background: none,
  titlepage-logo: none,
  logo-width: 35mm,

  // --- Institution ---
  institution: none,

  // --- Page Layout ---
  paper: "us-letter",
  margin: (x: 2.5cm, y: 2.5cm),
  fontsize: 11pt,
  linestretch: 1.2,

  // --- Fonts ---
  mainfont: "Source Sans 3",
  monofont: "Source Code Pro",

  // --- Features ---
  toc: false,
  toc-title: "Table of Contents",
  toc-depth: 3,
  toc-own-page: false,
  numbersections: false,
  colorlinks: true,
  footnotes-pretty: true,

  // --- Header & Footer ---
  disable-header-and-footer: false,
  header-left: none,
  header-center: none,
  header-right: none,
  footer-left: none,
  footer-center: none,
  footer-right: none,

  // --- Tables ---
  table-use-row-colors: true,

  // --- Code ---
  code-block-font-size: 0.85em,

  // --- Version History ---
  major-revisions: (),

  // --- Body ---
  body,
) = {

  // =========================================================================
  // Document Metadata
  // =========================================================================
  set document(
    title: if title != none { title } else { "" },
    author: authors,
    keywords: keywords,
  )

  // =========================================================================
  // Page Setup
  // =========================================================================
  set page(
    paper: "us-letter",
    margin: margin,
    // Header and footer are set after the title page
  )

  set text(
    font: mainfont,
    size: fontsize,
    lang: lang,
    fill: rgb("#333333"),
  )

  set par(
    leading: fontsize * linestretch * 0.65,
    justify: true,
    first-line-indent: 0pt,
  )

  // Paragraph spacing
  show par: set par(spacing: 0.65em)

  // =========================================================================
  // Heading Styles
  // =========================================================================
  set heading(numbering: if numbersections { "1.1.1.1.1" } else { none })

  show heading: set text(fill: heading-color, font: mainfont, weight: "bold")

  show heading.where(level: 1): it => {
    v(1.2em)
    block(text(size: 1.6em, it))
    v(0.6em)
  }

  show heading.where(level: 2): it => {
    v(1em)
    block(text(size: 1.3em, it))
    v(0.4em)
  }

  show heading.where(level: 3): it => {
    v(0.8em)
    block(text(size: 1.1em, it))
    v(0.3em)
  }

  show heading.where(level: 4): it => {
    v(0.6em)
    block(text(size: 1em, style: "italic", it))
    v(0.2em)
  }

  // =========================================================================
  // Link Styles
  // =========================================================================
  show link: it => {
    if colorlinks {
      set text(fill: url-color)
      it
    } else {
      it
    }
  }

  show ref: it => {
    if colorlinks {
      set text(fill: cite-color)
      it
    } else {
      it
    }
  }

  // =========================================================================
  // Blockquote Style
  // =========================================================================
  show quote: it => {
    block(
      width: 100%,
      inset: (left: 1em, y: 0.6em, right: 0.6em),
      stroke: (left: 3pt + blockquote-border),
      text(fill: blockquote-text, it.body),
    )
  }

  // =========================================================================
  // Code Block Styles
  // =========================================================================
  // Inline code
  show raw.where(block: false): box.with(
    fill: listing-background,
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
  )

  // Code blocks
  show raw.where(block: true): it => {
    set text(font: monofont, size: code-block-font-size)
    block(
      width: 100%,
      fill: listing-background,
      stroke: 0.5pt + listing-rule,
      radius: 0pt,
      inset: 10pt,
      it,
    )
  }

  // =========================================================================
  // Table Styles
  // =========================================================================
  set table(
    stroke: (x: none, y: 0.5pt + table-rule-color),
    inset: 6pt,
  )

  show table: set text(size: 0.95em)

  // Table header styling
  show table.cell.where(y: 0): set text(weight: "bold")

  show table.cell.where(y: 0): set table.cell(
    fill: white,
    stroke: (bottom: 1.5pt + table-rule-color),
  )

  // =========================================================================
  // Figure / Caption Styles
  // =========================================================================
  show figure.caption: it => {
    set text(fill: caption-color, size: 0.9em, style: "normal")
    set align(left)
    block(
      inset: (top: 4pt),
      [
        #text(weight: "bold")[#it.supplement #context it.counter.display(it.numbering):#h(0.5em)]#it.body
      ],
    )
  }

  // =========================================================================
  // Footnote Styles
  // =========================================================================
  set footnote.entry(separator: line(length: 30%, stroke: 0.5pt + gray))

  // =========================================================================
  // Title Page
  // =========================================================================
  if titlepage and title != none {
    // Title page with background image
    if titlepage-background != none {
      page(
        margin: (top: 2cm, right: 4cm, bottom: 3cm, left: 4cm),
        background: image(titlepage-background, width: 100%, height: 100%),
        header: none,
        footer: none,
      )[
        #set text(fill: titlepage-text-color)
        #v(1fr)
        #v(-4em)
        #text(size: 2.2em, weight: "bold", font: mainfont, title)
        #if subtitle != none {
          v(0.8em)
          text(size: 1.4em, font: mainfont, subtitle)
        }
        #if major-revisions.len() > 0 {
          v(0.8em)
          text(size: 1.4em, font: mainfont, [Version #major-revisions.first().at("version", default: "")])
        }
        #v(1.5em)
        #text(size: 1.3em, font: mainfont)[
          #authors.join(", ")
          #if institution != none {
            v(0.3em)
            institution
          }
          #v(0.4em)
          #if last-reviewed != none [Last Reviewed: #last-reviewed]
          #if date != none and last-reviewed == none [#date]
        ]
        #v(1fr)
        #if titlepage-logo != none {
          image(titlepage-logo, width: logo-width)
        }
      ]
    } else {
      // Title page without background (Eisvogel default style)
      page(
        margin: (left: 6cm, rest: 2.5cm),
        header: none,
        footer: none,
        ..if titlepage-color != none {
          (fill: titlepage-color)
        },
      )[
        #set text(fill: titlepage-text-color)
        // Colored rule across the page
        #place(
          dx: -0.3cm,
          dy: 0pt,
          block(
            width: 130% + 0.3cm,
            height: titlepage-rule-height,
            fill: titlepage-rule-color,
          ),
        )
        #v(1fr)

        #text(size: 2.2em, weight: "bold", font: mainfont, title)

        #if subtitle != none {
          v(0.8em)
          text(size: 1.4em, font: mainfont, subtitle)
        }

        #if major-revisions.len() > 0 {
          v(0.8em)
          text(size: 1.4em, font: mainfont, [Version #major-revisions.first().at("version", default: "")])
        }

        #v(1.5em)
        #text(size: 1.3em, font: mainfont, authors.join(", "))
        #if institution != none {
          v(0.3em)
          text(size: 1.1em, font: mainfont, institution)
        }
        #v(1fr)

        #if titlepage-logo != none {
          image(titlepage-logo, width: logo-width)
          v(0.5em)
        }

        #if last-reviewed != none {
          text(font: mainfont, [Last Reviewed: #last-reviewed])
        } else if date != none {
          text(font: mainfont, date)
        }
      ]
    }
  }

  // =========================================================================
  // Configure Header & Footer for remaining pages
  // =========================================================================
  set page(
    header: if not disable-header-and-footer {
      context {
        set text(size: 0.85em, fill: rgb("#666666"))
        let hl = if header-left != none { header-left } else if title != none { title } else { "" }
        let hc = if header-center != none { header-center } else { "" }
        let hr = if header-right != none {
          header-right
        } else if last-reviewed != none {
          [Last Reviewed: #last-reviewed]
        } else if date != none {
          date
        } else {
          ""
        }
        grid(
          columns: (1fr, auto, 1fr),
          align: (left, center, right),
          hl, hc, hr,
        )
        v(-3pt)
        line(length: 100%, stroke: 0.5pt + rgb("#CCCCCC"))
      }
    },
    footer: if not disable-header-and-footer {
      context {
        set text(size: 0.85em, fill: rgb("#666666"))
        line(length: 100%, stroke: 0.5pt + rgb("#CCCCCC"))
        v(-3pt)
        let fl = if footer-left != none { footer-left } else { authors.join(", ") }
        let fc = if footer-center != none { footer-center } else { "" }
        let fr = if footer-right != none {
          footer-right
        } else {
          counter(page).display("1")
        }
        grid(
          columns: (1fr, auto, 1fr),
          align: (left, center, right),
          fl, fc, fr,
        )
      }
    },
  )

  // Reset page counter after title page
  counter(page).update(1)

  // =========================================================================
  // Abstract
  // =========================================================================
  if abstract != none {
    v(1em)
    block(
      width: 100%,
      inset: (x: 2em, y: 1em),
      stroke: (y: 0.5pt + gray),
    )[
      #text(weight: "bold", size: 1.1em)[Abstract]
      #v(0.4em)
      #abstract
    ]
    v(1em)
  }

  // =========================================================================
  // Table of Contents
  // =========================================================================
  if toc {
    heading(level: 1, outlined: false, bookmarked: false, toc-title)
    outline(
      depth: toc-depth,
      indent: auto,
    )
    if toc-own-page {
      pagebreak()
    } else {
      v(1em)
    }
  }

  // =========================================================================
  // Body Content
  // =========================================================================
  body

  // =========================================================================
  // Version History
  // =========================================================================
  if major-revisions.len() > 0 {
    pagebreak()
    heading(level: 1, [Version History])
    v(0.5em)
    table(
      columns: (auto, auto, auto, 1fr),
      align: (center, center, center, left),
      stroke: (x: none, y: 0.5pt + table-rule-color),
      inset: 8pt,
      table.header(
        text(weight: "bold")[Version],
        text(weight: "bold")[Date],
        text(weight: "bold")[Approved By],
        text(weight: "bold")[Comment],
      ),
      ..major-revisions.map(rev => (
        rev.at("version", default: ""),
        rev.at("date", default: ""),
        rev.at("approved_by", default: rev.at("approved-by", default: "")),
        rev.at("description", default: rev.at("comment", default: "")),
      )).flatten(),
    )
  }
}

// ===========================================================================
// Pandoc Template Wiring
// ===========================================================================

#show: eisvogel.with(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
  authors: (
$for(author)$
    "$author$",
$endfor$
  ),
$if(date)$
  date: [$date$],
$endif$
$if(extra.last_reviewed)$
  last-reviewed: [$extra.last_reviewed$],
$endif$
$if(abstract)$
  abstract: [$abstract$],
$endif$
$if(keywords)$
  keywords: ($for(keywords)$"$keywords$",$endfor$),
$endif$
$if(lang)$
  lang: "$lang$",
$endif$

  // Title page
$if(titlepage)$
  titlepage: $titlepage$,
$endif$
$if(titlepage-color)$
  titlepage-color: rgb("#$titlepage-color$"),
$endif$
$if(titlepage-text-color)$
  titlepage-text-color: rgb("#$titlepage-text-color$"),
$endif$
$if(titlepage-rule-color)$
  titlepage-rule-color: rgb("#$titlepage-rule-color$"),
$endif$
$if(titlepage-rule-height)$
  titlepage-rule-height: $titlepage-rule-height$pt,
$endif$
$if(titlepage-background)$
  titlepage-background: "$titlepage-background$",
$endif$
$if(titlepage-logo)$
  titlepage-logo: "$titlepage-logo$",
$endif$
$if(logo-width)$
  logo-width: $logo-width$,
$endif$

  // Institution
$if(institution)$
  institution: [$institution$],
$endif$

  // Page layout
$if(papersize)$
  paper: "$papersize$",
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(linestretch)$
  linestretch: $linestretch$,
$endif$
$if(mainfont)$
  mainfont: "$mainfont$",
$endif$
$if(monofont)$
  monofont: "$monofont$",
$endif$

  // Features
$if(toc)$
  toc: $toc$,
$endif$
$if(toc-title)$
  toc-title: "$toc-title$",
$endif$
$if(toc-depth)$
  toc-depth: $toc-depth$,
$endif$
$if(toc-own-page)$
  toc-own-page: $toc-own-page$,
$endif$
$if(numbersections)$
  numbersections: $numbersections$,
$endif$
$if(colorlinks)$
  colorlinks: $colorlinks$,
$endif$

  // Header & Footer
$if(disable-header-and-footer)$
  disable-header-and-footer: $disable-header-and-footer$,
$endif$
$if(header-left)$
  header-left: [$header-left$],
$endif$
$if(header-center)$
  header-center: [$header-center$],
$endif$
$if(header-right)$
  header-right: [$header-right$],
$endif$
$if(footer-left)$
  footer-left: [$footer-left$],
$endif$
$if(footer-center)$
  footer-center: [$footer-center$],
$endif$
$if(footer-right)$
  footer-right: [$footer-right$],
$endif$

  // Tables
$if(table-use-row-colors)$
  table-use-row-colors: $table-use-row-colors$,
$endif$

  // Code
$if(code-block-font-size)$
  code-block-font-size: $code-block-font-size$,
$endif$

  // Version history
$if(extra.major_revisions)$
  major-revisions: (
$for(extra.major_revisions)$
    (
      version: "$it.version$",
      date: "$it.date$",
      approved_by: "$it.approved_by$",
      description: "$it.description$",
    ),
$endfor$
  ),
$endif$
)

$body$