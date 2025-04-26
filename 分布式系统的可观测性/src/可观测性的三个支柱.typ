#import "../lib.typ":*

= 可观测性的三个支柱

#picture-figure("Prometheus 指标示例", image("pic/prometheus_metric_sample.png"))
#picture-figure("请求流程图示例", image("pic/sample_request_flow_diagram.png"))
#picture-figure(
  "在请求的生命周期中设计的分布式系统系统的各个组件，表示为有向无环图",
  image("pic/various_components_of_distributed_system.png"),
)
#picture-figure(
  "表示为span的trace：span A是根span，span B是span A的子项",
  image("pic/trace_represented_as_spans.png", height: 50%),
)

== Logs

=== 时间日志（Event Logs）

=== Logs的优缺点

#warn("RELP不是灵丹妙药")[
]

#note("To Sample, or Not To Sample?（是否取样？）")[

]

=== 将日志记录作为流处理问题

== Metrics

=== 现代Metrics解剖

=== Metrics相对与Logs的优点

#note("")[
  hello
]

=== Metrics的缺点

== Traces

== Traces的挑战
=== Service Meshes：未来的新希望

== 总结