// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (
  large: (
    path: "_static/tree-512.png"
  ),
  medium: (
    path: "_static/tree-256.png"
  ),
  small: (
    path: "_static/tree-64.png"
  )
)
#set text()
#show heading: set text(font: ("Roboto",), )
#show raw.where(block: false): set text(fill: rgb("#222222"), )
#show raw.where(block: false): content => highlight(fill: rgb("#ddeaf1"), content)
#show raw.where(block: true): set text()
#show raw.where(block: true): set block(fill: rgb("#eef4f8"))
#show link: set text()
#show link: content => underline(content)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
#set page(background: align(right+top, box(inset: (right: 0.5in, top: 0.25in), image("/_static/tree-64.png", width: 1in, alt: "Alternate alternate text"))))

#show: doc => article(
  title: [Наши фамилии],
  font: ("Roboto",),
  heading-family: ("Roboto",),
  sectionnumbering: "1.1.a",
  codefont: ("Fira Code",),
  toc: true,
  toc_title: [Оглавление],
  toc_depth: 3,
  doc,
)

= Абрамовы
<абрамовы>
- Борис,
- Виталий Борисович,
- Полина Витальевна

= Барабаш
<барабаш>
- Людмила Сергеевна,
- Анастасия Александровна

= Батищевы
<батищевы>
- #link("./Батищевы/Василий_Иванович")[Василий Иванович],
- #link("./Батищевы/Антонина_Яковлевна")[Антонина Яковлевна],
- #link("./Батищевы/Галина_Васильевна")[Галина Васильевна],
- #link("./Батищевы/Екатерина_Васильевна")[Екатерина Васильевна],
- #link("./Батищевы/Надежда_Васильевна")[Надежда Васильевна]

= Бахтемировы
<бахтемировы>
- Андрей Иванович,
- Мария Николаевна,
- Константин Андреевич,
- Михаил Андреевич,
- Иван Андреевич,
- Николай Андреевич,
- Павел Андреевич,
- Александр Андреевич,
- Сергей Андреевич,
- Мария Андреевна,
- Елизавета Андреевна

= #link("./img/schemes/Levykiny_shema.pdf")[Безверхние]:
<безверхние>
- Вилен Николаевич,
- Наталья Николаевна,
- Олег Виленович

= Беляевы
<беляевы>
- Степан Иванович,
- Александра Захаровна,
- #link("./Беляевы/Иван_Степанович")[Иван Степанович],
- #link("./Беляевы/Анастасия_Михайловна")[Анастасия Михайловна],
- Александр Степанович,
- Пелагея Тимофеевна,
- Мария Степановна,
- Наталья Степановна,
- Михаил Степанович,
- Александра,
- Галина Михайловна,
- Василий Степанович,
- Зоя Васильевна,
- Анатолий Васильевич,
- #link("./Беляевы/Анна_Ивановна")[Анна Ивановна],
- #link("./Беляевы/Виталий_Иванович")[Виталий Иванович],
- Валерий Витальевич,
- #link("./Беляевы/Агния_Ивановна")[Агния Ивановна],
- Александра Ивановна,
- Пётр Иванович,
- #link("./Беляевы/Александр_Иванович")[Александр Иванович],
- Сергей Александрович,
- Михаил Александрович,
- #link("./Беляевы/Аркадий_Иванович")[Аркадий Иванович],
- Злата Алексеевна,
- Алексей Аркадьевич,
- Лидия Алексеевна,
- Антон Сергеевич,
- Евгения Сергеевна,
- Иван Михайлович,
- Александр Михайлович,
- Елена Алексеевна

= Буткевичи
<буткевичи>
- Фридрих Александрович,
- Наталия Фридриховна

= Бутт
<бутт>
- #link("./Батищевы/Галина_Васильевна")[Галина Васильевна]

= Васильковы
<васильковы>
- Иван Георгиевич,
- Евгения Владимировна,
- Михаил Иванович,
- Иван Михайлович

= Веденеевы
<веденеевы>
- #link("./Веденеевы/Василий_Афанасьевич")[Василий Афанасьевич],
- #link("./Веденеевы/Анисия_Павловна")[Анисия Павловна],
- #link("./Веденеевы/Василий_Васильевич")[Василий Васильевич],
- #link("./Веденеевы/Валентина_Спиридоновна")[Валентина Спиридоновна],
- #link("./Веденеевы/Анна_Васильевна")[Анна Васильевна],
- #link("./Веденеевы/Элеонора_Васильевна")[Элеонора Васильевна],
- #link("./Веденеевы/Владислав_Дмитриевич")[Владислав Дмитриевич],
- #link("./Веденеевы/Максим_Владиславович")[Максим Владиславович],
- #link("./Веденеевы/Мария_Владиславовна")[Мария Владиславовна]

= Веригины
<веригины>
- Иван Фёдорович,
- Мария Ильинична,
- #link("index.php?option=com_content&view=article&id=4:veriginaliv&catid=9:nashi-lyudi&Itemid=104")[Алексей Иванович],
- #link("index.php?option=com_content&view=article&id=6:veriginayulserg&catid=9:nashi-lyudi&Itemid=104")[Юлия Сергеевна],
- Мария Ивановна,
- #link("index.php?option=com_content&view=article&id=7:veriginanadal&catid=9:nashi-lyudi&Itemid=104")[Надежда Алексеевна],
- #link("index.php?option=com_content&view=article&id=5:veriginvlal&catid=9:nashi-lyudi&Itemid=104")[Владимир Алексеевич],
- #link("index.php?option=com_content&view=article&id=8:veriginazinalex&catid=9:nashi-lyudi&Itemid=104")[Зинаида Александровна],
- #link("index.php?option=com_content&view=article&id=50:veriginagalvl&catid=9:nashi-lyudi&Itemid=104")[Галина Владимировна],
- #link("index.php?option=com_content&view=article&id=11:veriginakirvl&catid=9:nashi-lyudi&Itemid=104")[Кира Владимировна],
- Юлия Алексеевна,
- Мария Алексеевна,
- Сергей Алексеевич,
- #link("index.php?option=com_content&view=article&id=9:veriginvasal&catid=9:nashi-lyudi&Itemid=104")[Василий Алексеевич],
- #link("index.php?option=com_content&view=article&id=10:levykinasofal&catid=9:nashi-lyudi&Itemid=104")[Софья Алексеевна]
- #link("index.php?option=com_content&view=article&id=44:veriginviktiv&catid=9:nashi-lyudi&Itemid=104")[Виктор Иванович],
- Елизавета Самсоновна,
- Варвара Викторовна,
- Екатерина Викторовна

= Гаусман
<гаусман>
- Валентин,
- Татьяна Алексеевна,
- Юрий Валентинович

= Гуревичи
<гуревичи>
- #link("index.php?option=com_content&view=article&id=33:gurevicharsvlad&catid=9:nashi-lyudi&Itemid=104")[Арсений Владиславович],
- #link("index.php?option=com_content&view=article&id=34:gurevichleovlad&catid=9:nashi-lyudi&Itemid=104")[Леонид Владиславович]

= Гуреевы
<гуреевы>
- Анна Александровна
- Валентина Владимировна

= Давыдовы
<давыдовы>
- Ольга Владимировна

= Дудниковы
<дудниковы>
- Алексей Тимофеевич,
- Александра Васильевна,
- Лидия Алексеевна

= Ивановы
<ивановы>
- Ольга Фёдоровна

= Иларионовы
<иларионовы>
- Самсон,
- Елена Михайловна,
- Анна Самсоновна,
- Мария Самсоновна,
- Ирина Егоровна,
- Николай Самсонович,
- Елизавента Самсоновна,
- Мария Самсоновна,
- Агния Самсоновна,
- Сергей Самсонович,
- Александр Самсонович,
- Надежда Самсоновна,
- Александр Самсонович

= Камышаловы
<камышаловы>
- Лариса Сергеевна,
- Станислав Владимирович

= Киселёвы
<киселёвы>
- Юлия Николаевна

= Климановы
<климановы>
- Максим Данилович,
- Наталья Павловна,
- Агриппина Максимовна

= Козловы
<козловы>
- Вера Владимировна

= Комаровы
<комаровы>
- Алексей Иванович,
- #link("index.php?option=com_content&view=article&id=15:komarovairalex&catid=9:nashi-lyudi&Itemid=104")[Ирина Александровна],
- Елена Алексеевна

= Крыловы
<крыловы>
- Сергей Дмитриевич,
- Мария Борисовна,
- Мария Сергеевна

= #link("./img/schemes/Levykiny_shema.pdf")[Кудрявцевы]
<кудрявцевы>
- Константин Дмитриевич,
- Анна Васильевна,
- Константин Константинович,
- Эстер Хацкелевна,
- Геннадий Константинович

= Кузнецовы
<кузнецовы>
- Валентин,
- Елена Владимировна,
- Юрий Валентинович,
- Виктор Валентинович,
- Наталья Викторовна,
- Сергей Викторович

= Кумровы
<кумровы>
- Ольга Николаевна

= #link("img/schemes/Levykiny_shema.pdf")[Левыкины]
<левыкины>
- #link("./Левыкины/Василий_Михайлович")[Василий Михайлович],
- Александра Семёновна,
- Владимир Васильевич,
- Николай Васильевич,
- #link("./Левыкины/Софья_Алексеевна")[Софья Алексеевна],
- Татьяна Николаевна,
- Виталий Васильевич,
- Василий Васильевич,
- Гурий Васильевич,
- Нина Васильевна,
- Анна Васильевна

= Лясковские
<лясковские>
- #link("index.php?option=com_content&view=article&id=23:lyaskovskayaagvl&catid=9:nashi-lyudi&Itemid=104")[Агния Владимировна],
- #link("index.php?option=com_content&view=article&id=29:lyaskovskayaekole&catid=9:nashi-lyudi&Itemid=104")[Екатерина Олеговна]

= #link("img/schemes/Levykiny_shema.pdf")[Михайловские]
<михайловские>
- Александр Александрович,
- Татьяна Николаевна,
- Лидия Александровна

= Нестеровичи
<нестеровичи>
- Иван Францевич,
- Сергей Францевич,
- #link("index.php?option=com_content&view=article&id=16:nesterovichevffr&catid=9:nashi-lyudi&Itemid=104")[Евфимия Францевна],
- #link("index.php?option=com_content&view=article&id=13:nesterovichalexal&catid=9:nashi-lyudi&Itemid=104")[Александр Алексеевич],
- Татьяна Алексеевна,
- Владимир Алексеевич,
- Елена Владимировна,
- #link("index.php?option=com_content&view=article&id=14:sayakinlyudalex&catid=9:nashi-lyudi&Itemid=104")[Людмила Александровна],
- #link("index.php?option=com_content&view=article&id=15:komarovairalex&catid=9:nashi-lyudi&Itemid=104")[Ирина Александровна],
- Валентина Владимировна,
- Владимир Александрович,
- Галина Петровна,
- Наталья Васильевна,
- Евгений Александрович,
- Татьяна Александровна,
- Сергей Юрьевич,
- Александра Сергеевна,
- Александр Евгеньевич,
- Екатерина Александровна,
- #link("index.php?option=com_content&view=article&id=38:nesterovichmihevg&catid=9:nashi-lyudi&Itemid=104")[Михаил Евгеньевич],
- Ольга Фёдоровна,
- #link("index.php?option=com_content&view=article&id=39:nesterovichmikhmikh&catid=9:nashi-lyudi&Itemid=104")[Михаил Михайлович],
- Галина Евгеньевна

= Николаевы
<николаевы>
- Александр Николаевич,
- Авдотья Васильевна,
- Сергей Александрович,
- Александра Васильевна,
- Пётр Александрович,
- Василий Сергеевич,
- Надежда Сергеевна,
- #link("index.php?option=com_content&view=article&id=6:veriginayulserg&catid=9:nashi-lyudi&Itemid=104")[Юлия Сергеевна]

= Ореховы
<ореховы>
- Александра Николаевна

= #link("img/schemes/Levykiny_shema.pdf")[Плущевские]
<плущевские>
- Николай Петрович,
- Нина Васильевна,
- Наталья Николаевна,
- Анатолий Николаевич

= Подобаевы
<подобаевы>
- Тимофей Александрович,
- Вера Владимировна,
- Василиса Тимофеевна,
- Василий Тимофеевич

= Пучковы
<пучковы>
- ~Татьяна Владимировна,
- Борис,
- Валерия Борисовна

= Руденко
<руденко>
- #link("./Веденеевы/Валентина_Спиридоновна")[Валентина Спиридоновна] \[26 \]

= Савины
<савины>
- #link("./Савины/Владимир_Григорьевич")[Владимир Григорьевич], \[27\]
- #link("./Савины/Марина_Ивановна")[Марина Ивановна], \[28\]
- Михаил Владимирович,
- Вера Владимировна

= Саякины
<саякины>
- Иван Евдокимович,
- Наталья Ивановна,
- Полина Ивановна,
- #link("./Саякины/Григорий_Иванович")[Григорий Иванович], \[17\]
- #link("index.php?option=com_content&view=article&id=14:sayakinlyudalex&catid=9:nashi-lyudi&Itemid=104")[Людмила Александровна],
- Валентина Ивановна,
- Анна Ивановна,
- #link("./Савины/Владимир_Григорьевич")[Владимир Григорьевич], \[27\]
- #link("./Саякины/Дмитрий_Григорьевич")[Дмитрий Григорьевич], \[19\]
- #link("index.php?option=com_content&view=article&id=20:sayakinaelvas&catid=9:nashi-lyudi&Itemid=104")[Элеонора Васильевна],
- #link("index.php?option=com_content&view=article&id=21:sayakindmdm&catid=9:nashi-lyudi&Itemid=104")[Дмитрий Дмитриевич],
- Наталия Фридриховна,
- #link("./Веденеевы/Владислав_Дмитриевич")[Владислав Дмитриевич] \[22\]

= Сипотовские
<сипотовские>
- Карп Семёнович,
- Праскева Карповна,
- Анна Карповна,
- Иван Карпович,
- Василий Карпович,
- Андрей Карпович,
- Мария Андреевна,
- Владимир Андреевич,
- Любовь Фёдоровна,
- Борис Владимирович,
- Елена Владимировна,
- Татьяна Владимировна

= Соловьёвы
<соловьёвы>
- Анна Ивановна,
- Серёжа,
- Галина Дмитриевна,
- Ирина Дмитриевна

= Сургучёвы
<сургучёвы>
- Яков Григорьевич,
- Дарья Михайловна,
- Антонина Яковлевна

= Томковичи
<томковичи>
- Пётр Михайлович,
- Полина Ивановна,
- Герард Петрович,
- Ирина Борисовна,
- Ольга Герардовна,
- Валентин Петрович,
- Надежда Валентиновна

= Трушины
<трушины>
- Василий Павлович,
- Агриппина Максимовна,
- Виктор Васильевич,
- Зинаида Васильевна,
- Наталья Васильевна

= Филиповичи
<филиповичи>
- #link("index.php?option=com_content&view=article&id=7:veriginanadal&catid=9:nashi-lyudi")[Надежда Алексеевна],
- Николай Алексеевич,
- Павел Алексеевич,
- Екатерина Викторовна

= Фроловы
<фроловы>
- Павел Фролович,
- Татьяна Лукинична,
- Наталья Павловна,
- Иван Павлович,
- Анна Ивановна,
- Василий Иванович,
- Александра Николаевна,
- Анатолий Васильевич,
- Татьяна Васильевна

= Хребтовы
<хребтовы>
- #link("index.php?option=com_content&view=article&id=37:lkhrebtovanativ&catid=9:nashi-lyudi&Itemid=104")[Анатолий Иванович],
- #link("index.php?option=com_content&view=article&id=31:khrebtovaagiv&catid=9:nashi-lyudi&Itemid=104")[Агния Ивановна],
- #link("index.php?option=com_content&view=article&id=35:khrebtovlvanat&catid=9:nashi-lyudi&Itemid=104")[Владимир Анатольевич],
- #link("index.php?option=com_content&view=article&id=36:khrebtovaekatbas&catid=9:nashi-lyudi&Itemid=104")[Екатерина Васильевна],
- #link("index.php?option=com_content&view=article&id=23:lyaskovskayaagvl&catid=9:nashi-lyudi&Itemid=104")[Агния Владимировна],
- #link("index.php?option=com_content&view=article&id=32:khrebtovanatvl&catid=9:nashi-lyudi&Itemid=104")[Наталья Владимировна]

= Чекомасовы
<чекомасовы>
- Татьяна Васильевна,
- Михаил Александрович

= Чижовы
<чижовы>
- Владимир,
- Зоя Ивановна,
- Сергей Владимирович,
- Галина Парфёновна,
- Людмила Сергеевна,
- Наталья Сергеевна

= Шипорины
<шипорины>
- Валентина Ивановна,
- Вячеслав Владимирович,
- Лидия

= Швогер-Летецкие
<швогер-летецкие>
- Людвиг Антонович,
- Петр Антонович,
- Анатолий Антонович,
- Варвара Викторовна,
- Анатолий Анатольевич

= Щербаковы
<щербаковы>
- Роман Вячеславович,
- Галина Евгеньевна,
- Василий Романович,
- Данила Романович,
- Елизавета Романовна

= Ясинчук
<ясинчук>
- #link("./Батищевы/Надежда_Васильевна")[Надежда Васильевна]

= Яфа
<яфа>
- Александр Фёдорович,
- Софья Петровна,
- #link("index.php?option=com_content&view=article&id=8:veriginazinalex&catid=9:nashi-lyudi&Itemid=104")[Зинаида Александровна],
- Александр Александрович,
- Нина Александровна,
- Ольга Александровна,
- Константин Александрович.
