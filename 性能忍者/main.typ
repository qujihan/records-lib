#import "lib.typ": *

#set text(lang: "zh")
#show: book.with(info: (
  title: "性能忍者（C++性能调优）小册子",
  author: "渠继涵",
  latin-font: "Lora",
  cjk-font: "Noto Serif CJK SC",
  code-font: "Maple Mono NF",
))

#include "src/intro.typ"
#include "src/core_bound.typ"
#include "src/memory_bound.typ"
#include "src/bad_speculation.typ"
#include "src/cpu_frontend_bound.typ"
#include "src/data_driven_optimization.typ"
#include "src/misc.typ"