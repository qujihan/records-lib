#import "../lib.typ": *

= 可扩展的查询优化器<可扩展的查询优化器>
构建一个可以扩展的查询优化器的方式之一是拥有一组可以扩展的_规则（rule）_，这个规则用于定义所有等效的计划的空间。正如@介绍\中所提及的，这种方法以逻辑算子、物理算子以及一系列的_转换（transformation）_和_实现规则（implementation
  rules）_的概念为中心。优化器在_搜索策略（search
  strategy）_的指导下，按照一定的顺序应用规则（rules），在等效的计划空间内探索，并且在众多备选计划空间中选择一个高效的计划。

在这一章中，我们首先介绍一下扩展的优化器的概念（@可扩展的查询优化器基本概念）。然后我们深入讨论两个可以扩展的优化器框架：Volcano框架以及Cascades框架。我们从介绍Volcano以及其搜索开始（@volcano）, 之后简单的看下Volcano的局限性。也正因其局限性，催生了其后来者: Cascades框架（@cascades）。我们介绍了在实践中用于提高Volcano和Cascades效率的其他优化以及启发式方法（@提高查询效率的技术）。为了说明可扩展的查询优化器如何轻松的将新功能合并到查询处理中，我们介绍了Microsoft SQL Server的优化器是如何利用Cascades框架的可扩展性来实现列存的（@Microsoft-SQL-Server的扩展性示例）。在本章的最后，我们将介绍可扩展的查询优化器是如何生成多核并行以及分布式的查询（@并行分布式查询流程）。

== 基本概念<可扩展的查询优化器基本概念>
我们在基于规则的（rule-based）的可扩展优化器（Volcano/Cascades）中介绍了一些重要的概念。但是需要注意，这些概念（例如：算子operators、属性properties）并不是Volcano/Cascades中所独有的概念，它们也被用于System R、Starburst以及EXODUS等系统的查询优化器中。

下面看一下@query2，其相应的逻辑以及物理计划在@query2的逻辑以及物理计划\中。

#sql-code()[
  ```sql
  SELECT *
  FROM A, B
  WHERE A.k = B.k
  ```
]<query2>

#picture-figure("query2的逻辑以及物理计划", image("../pic/query2的逻辑以及物理计划.png"))<query2的逻辑以及物理计划>

*逻辑以及物理算子* 逻辑算子定义了一个或者多个关系的关系操作，例如在@query2的逻辑以及物理计划\中A和B之间的Join运算符。这里有一点需要注意，在查询优化器中，可能会引入非关系的逻辑算子，例如`Apply`。`Apply`用来处理子查询（@使用Apply代数表示子查询）以及用于处理并行性的交换操作（@多核并行）。因此使用逻辑算子的集合以及由此产生的优化器的搜索空间，超过了SQL查询中所呈现的范围。物理算子是一种算法的实现，用于执行在查询执行中所需的操作。物理算子的一个例子是`Hash Join`（@query2的逻辑以及物理计划）。注意，一个逻辑算子可以由不同的物理算子来实现，反之亦然。例如，逻辑算子`Join`可以由`Hash Join`和`Nested Loops Join`来实现。类似，物理算子`Hash Join`可以用于实现多种逻辑算子，例如`Join`、`Left Outer Join`以及`Union`。此外，一个逻辑算子可以由多个物理算子来实现。例如我们在
@inner-join转换\将会介绍的逻辑算子`Inner Join`，该算子一个通过`Sort`以及`Merge Join`算子来实现。

*逻辑以及物理表达式* 一个逻辑表达式是由逻辑算子构成的树状结构。它代表着一个关系代数表达式。例如@query2\中的连接操作就可以使用$L_1: A join B$表示，也正如@query2的逻辑以及物理计划\所表示的一样。一个物理表达式是一个由物理算子构成的树状结构，它也被成为_物理计划（physical
  plan）_或者简称为_计划（plan）_。例如表达式$P_1:italic("HashJoin(TableScan(A), TableScan(B))")$表示的就是@query2的逻辑以及物理计划\中的$L_1$实现。

*逻辑以及物理属性* 一个表达式的逻辑属性包含关系代数表达式以及表达式的基数等信息。例如$A join B$以及$B join A$都会产生A与B的连接的结果，并且它们有相同的逻辑属性（例如相同的基数）。表达式的物理属性包括表达式的输出顺序、并行度（执行一个表达式所使用的线程的数量）等。例如在@query2的逻辑以及物理计划\e中，`Merge Join`引入了排序这个物理属性，也就是说输出的结果是按照`A.k`列排序的。
表达式的物理属性可能是来自原始SQL的需求，或者是某个输入的物理属性而引入的。例如在@query3\中，该查询要求从表T中获取按列T.b排序的前3个元组，并且具有`T.a>10`这个条件。在这种情况下，查询中的`ORDER BY`子句引入了对`T.b`排序的物理属性。

#sql-code()[
  ```sql
  SELECT TOP 3 *
  FROM T
  WHERE T.a > 10
  ORDER BY T.b
  ```
]<query3>


*表达式的等价性* 如果两个逻辑表达式的逻辑属性是相同的，那么就认为这两个逻辑表达式是等价的。例如@query2的逻辑以及物理计划\a中的表达式$L_1: A join B$与@query2的逻辑以及物理计划\b中的表达式$L_2: B join A$是等价的。类似，如果两个物理表达式的物理属性是相同的，那么就认为这两个物理表达式是等价的。例如@query2的逻辑以及物理计划\c中的表达式$P_1: "HashJoin(TableScan(A), TableScan(B))"$与@query2的逻辑以及物理计划\d中的表达式$P_2: "NestedLoopsJoin(TableScan(A), TableScan(B))"$是等价的。然而由于@query2的逻辑以及物理计划\e的表达式$P_3: "MergeJoin(IndexScan(A), IndexScan(B))"$会生成`A.k`上的排序顺序，所以$P_3$既不等价于$P_2$，也不等价于$P_1$。

同样的，如果一个带有所需的物理属性的逻辑表达式与一个物理表达式在满足以下两个条件时，我们认为等价：
- 物理表达式的逻辑属性 == 逻辑表达式的逻辑属性
- 物理表达式具有所需的物理属性（译者注：不理解可以跳过，在下面有例子）

*规则Rules* 规则会将一个表达式重写为另外一个等价的表达式，从而帮助优化器从其他_查询（query）_中探索可替代的_计划（plan）_。对于一个优化器而言，有两种等价关系是值得关注的：
- 两个逻辑表达式之间的等价关系
- 具有所需物理属性的逻辑表达式与物理表达式之间的等价关系

_转换规则（transformation rule）_会将一个逻辑表达式重写为另外一个等价的逻辑表达式。例如连接的交换律将$L_1: A join B$改写成$L_2:B join A$。_实现规则（implementation rule）_将逻辑表达式的一部分转换为具有相关物理属性的，等价的物理表达式。例如`Merge Join`实现规则将@query2的逻辑以及物理计划\a中的表达式$L_1$中的逻辑运算符转换成@query2的逻辑以及物理计划\3中的$P_3$的归并连接运算符，其结果按照连接的列排序。我们将会在@volcano-search\中看到，Volcano中的搜索会递归的应用规则，将这个逻辑表达式转换成物理表达式。

规则是有两个方法定义的：`CheckPattern`以及`Transform`。`CheckPattern`检查该规则是否可以用于给定的表达式的根节点。如果适用返回True，反之False。为了检查规则是否适用，`CheckPattern`可能会检查输入的表达式中的其他的节点的属性。例如会检查父节点或者子节点。在`CheckPattern`返回`True`的时候，`Transform`就会被调用了。调用`Transform`会输出一个转换后的等价的表达式。在@执行计划的关键转化\中我们会探讨在实践中被广泛应用的一些重要的规则。

*强制执行器 Enforcers* 强制执行器是一系列物理操作符，仅用于强制执行输出必要的物理属性，例如有序性、并行度等。强制执行器的作用与在@system-r\中提到的有趣性排序类似。不过强制执行器将其推广到了除了有序性以外的其他物理属性。

#picture-figure("在计划搜索时执行强制执行的例子", image("../pic/2_2.png"))<enforcer>

现在我们回过头看看下之前提到的@query3\。假设数据库在表T上有两个索引：索引$I_a$是列`T.a`上的一个B+树索引，索引$I_b$是列`T.b`上的一个B+树索引。如@enforcer\所示，优化器在寻找$sigma_"T.a > 10" (T)$的最佳执行计划时，要求其具有在`T.b`上有序这一个物理属性。一种可能的实现规则是将该表达式重写为基于$I_b$的`Index Scan`。这里，该索引提供了基于$T.b$的有序性。第二种方式就是使用强制执行器，在$sigma_"T.a > 10"$上添加一个基于$T.b$的排序运算符，以得到所需的有序性。正式由于强制执行器的存在，其输出的逻辑表达式$sigma_"T.a > 10"$没有所需的物理属性，因此可以将其转换成基于$I_b$的`range-based Index Scan`。

== Volcano<volcano>
=== 简介
正如文献@Volcano---An-Extensible-and-Parallel-Query-Evaluation-System @The-Volcano-Optimizer-Generator--Extensibility-and-Efficient-Search\所描述的，Volcano是一个可扩展的基于规则的优化器框架。它提出了几个核心概念，包括表达式的物理属性和强制执行器（这是对System R中的interesting order的一种泛化）、_Mono（备忘录）_以及基于动态规划的自顶向下的搜索算法（这种算法利用_承诺（promise）_这个概念来确定下一步的动作，利用_引导（guidance）_来控制所要探索的搜索空间）。在@可扩展的查询优化器基本概念\这一章节我们了解了可扩展的查询优化器的基本概念。下面，我们将会详细的描述Volcano的_搜索（search）_以及_备忘录（mono）_机制。

*搜索策略 Search strategy* Volcano将其搜索分成两个阶段：_生成阶段（Generate phase）_以及_代价分析阶段（Cost analysis phase）_。在生成阶段，优化器将会在转换规则集合中生成所有可以替代的等价的逻辑表达式。在成本分析阶段，他会为第一个阶段生拆而逻辑表达式生成物理执行计划，并且返回原始查询的最佳计划，也就是所有枚举的计划中，成本最低的那一个。

与自底向上搜索的System R不同@system-r，Volcano使用_自顶向下动态规划（top-down dynamic programming）_，亦可被称为_记忆化（memoization）_以确保搜索的全面以及高效。在生成阶段，搜索会递归的将逻辑表达式以及其输入通过一组规则进行转换，生成等价的，可以替换的逻辑表达式。在代价分析阶段，优化器会递归对逻辑表达式以及其输入应用实现规则，并且推倒它们的成本，以便找到该逻辑表达式最佳的物理计划。

在整个搜索的过程中，Volcano会记住推导出来的逻辑表达式和物理表达式，并将它们缓存在一个名为`Momo`的数据结构中，以避免冗余计算。接下来我们会详细说明`Momo`这个数据结构。

*备忘录（Momo）*


#picture-figure(
  [
    以$A join B$为例的`Mono`示例，其中表B有可以使用的索引
    #linebreak()
    蓝色标注的是逻辑表达式 / 物理表达式和组都标注了相应的最佳计划的成本
  ],
  image("../pic/2_3.png"),
)<memo-example>

=== 查询<volcano-search>

#[
  #pagebreak()
  #set text(size: 0.8em)
  #algorithm-code(
    [
      在Volcano优化器中查询，在`GenerateLogicalExpr`、`MatchTransRule`、`UpdatePlan`这几个操作中，_备忘录（Mono）_中的组和表达式会被更新。随着搜索结果的推进，表达式的成本的限制也会被更新。在`FindBestPlan`操作结束以后，搜索得到的缓存结果会被添加到Mono中。
    ],
  )[
    + function GenerateLogicalExpr$italic("(LogExpr, Rules)")$ #sym.triangle.stroked.r
      + for $italic("Child")$ in inputs of $italic("LogExpr")$
        + if $italic("Group(Child)") in.not italic("Memo")$ then
          + $italic("GererateLogicalExpr(Child)")$
      + $italic("MatchTransRules(LogExpr, Rules)")$

    + function MatchTransRule$italic("LogExpr, Rules")$
      + for $italic("rule")$ in $italic("Rules")$ do
        + if $italic("rule")$ matches $italic("LogExpr")$ then
          + $italic("NewLogExpr") arrow.l italic("Transform(LogExpr, rule)")$ #sym.triangle.stroked.r 更新memo并且记录其邻居
          + $italic("GenerateLogicalExpr(NewLogExpr)")$
          + #sym.triangle.stroked.r 只会在$italic("NewLogExpr")$在memo中不存在的时候才会执行
  ]

]

=== 自定义查询策略
=== 添加新的规则以及运算符
== Cascades<cascades>
=== Cascades的主要改进
=== 查询简介
=== 查询算法
=== Cascades中的查询优化示例
== 提高查询效率的技术<提高查询效率的技术>
== Microsoft SQL Server的扩展性示例<Microsoft-SQL-Server的扩展性示例>
== 并行分布式查询流程<并行分布式查询流程>
=== 多核并行<多核并行>
=== 分布式查询优化
== 建议阅读
