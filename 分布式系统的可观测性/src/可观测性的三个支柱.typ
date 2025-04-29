#import "../lib.typ": *
= 可观测性的三个支柱
Logs、Metrics、Traces被成为可观测性的三大支柱。显然访问Logs、Metrics以及Traces并不能使得系统变得更加容易被观察。但是这三者都是强大的工具，如果理解得当就可以构建一个更好的系统。



== Event Logs 事件日志

_事件日志（event log）_是随着时间而发生的离散事件产生的日志，具有不可变的时间戳。事件日志一般有三种形式，但是基本相同，都是有着时间戳以及某些上下文的有效负载。这三种形式是：
- _纯文本Plaintext_：日志记录可能是任何格式的文本，这也是最常见的日志格式
- _结构化Structured_：最近被广泛传播以及倡导的格式，通常都是JSON格式
- _二进制Binary_：以Protobuf格式记录的Think logs、MySQL中用于复制以及时间点恢复的binlog日志、systemd日志、BSD防火墙`pf`使用的`pflog`格式的日志，这种防火墙通常用作`tcpdump`的前端

对一些不常见的系统的问题需要在非常精细的粒度下进行调试，尤其是事件日志

=== Logs的优缺点

#warn("RELP不是灵丹妙药")[ ]

#note("To Sample, or Not To Sample?（是否取样？）")[

]

=== 将日志记录作为流处理问题

== Metrics

=== 现代Metrics解剖
#picture-figure("Prometheus 指标示例", image("pic/prometheus_metric_sample.png", width: 60%))

=== Metrics相对与Logs的优点

#note("")[
  hello
]

=== Metrics的缺点

== Traces
#picture-figure("请求流程图示例", image("pic/sample_request_flow_diagram.png", width: 70%))
#picture-figure(
  "在请求的生命周期中设计的分布式系统系统的各个组件，表示为有向无环图",
  image("pic/various_components_of_distributed_system.png", width: 70%),
)
#picture-figure(
  "表示为span的trace：span A是根span，span B是span A的子项",
  image("pic/trace_represented_as_spans.png", width: 70%),
)
== Traces的挑战
=== Service Meshes：未来的新希望

== 总结
