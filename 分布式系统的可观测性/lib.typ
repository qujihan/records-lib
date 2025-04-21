#import "../book-template/book.typ":*

#let darken-red-text(body) = {
  text(fill: red.darken(40%), body)
}

#import "@preview/showybox:2.0.4": showybox
#let custom-box-style(base-color, title, ..body) = {
  showybox(
    //
    frame: (
      border-color: base-color.darken(30%),
      title-color: base-color.lighten(60%),
      body-color: base-color.lighten(80%),
    ),
    //
    title-style: (color: black, weight: "bold", align: center),
    shadow: (offset: 2pt),
    //
    title: title,
    ..body,
  )
}

#let note(title, ..body) = {
  custom-box-style(blue, title, ..body)
}

#let warn(title, ..body) = {
  custom-box-style(red, title, ..body)
}

#let ref(title, ..body) = {
  let ref-color = black.darken(15%)
  showybox(
    title-style: (weight: 900, color: ref-color.darken(40%), sep-thickness: 0pt, align: center),
    frame: (title-color: ref-color.lighten(80%), border-color: ref-color.darken(40%), thickness: (left: 1pt), radius: 0pt),
    title: title,
    ..body,
  )
}