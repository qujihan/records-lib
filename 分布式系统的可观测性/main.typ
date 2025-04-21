#import "lib.typ": *

#set text(lang: "zh")
#show: book.with(info: (
  title: "分布式系统的可观测性",
  author: "作者: Cindy Sridharan 译者: 渠继涵",
  latin-font: "Lora",
  cjk-font: "Noto Serif CJK SC",
  code-font: "Maple Mono NF",
))

#include "src/为什么需要可观测性.typ"
#include "src/监控以及可观测性.typ"
#include "src/编码以及测试的可观测性.typ"
#include "src/可观测性的三个支柱.typ"
#include "src/总结.typ"