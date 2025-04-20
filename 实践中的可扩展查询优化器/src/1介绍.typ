#import "../lib.typ":*
= 介绍<介绍>

SQL是一个用于查询关系型数据的高级声明式语言。它已经成为了关系数据查询的事实标准，并且被大部分的关系型数据库所支持。此外，在一些大数据系统中也逐渐开始流行。

SQL允许对关系型数据进行声明式的查询，包括选择、连接、分组、聚合以及嵌套子查询，这对各种决策的支持非常重要，尤其是企业中的商业智能场景。

以下面的@query1\为例：

#sql-code()[
```sql
SELECT *
FROM R, S, T
WHERE R.a = S.a AND S.c = T.d AND T.e = 10
```
]<query1>

在@查询处理流程\中展示了在一个数据库管理系统中，处理一个Query的SQL的主要流程。Query处理的三个流程将会在下面依次介绍。

#picture-figure("查询处理流程", image("../pic/查询处理流程.png"))<查询处理流程>

*解析以及验证（Parsing and Validation）* 解析与验证这一步是将一个SQL查询转换成内部的表现形式，这一步确保查询符合SQL的语法规则并且引用了已经存在的数据库的对象，例如：表或者列等。这一步的输出结果为逻辑查询树，逻辑查询树是一个使用代数表示的Query，其中每一个树的节点是一个关系算子（例如：Select、Join等）。在@查询处理流程\展示了@query1\在经过解析以及验证后的输出的逻辑查询树。

*查询优化（Query optimizer）* _查询优化（query optimizer）_将逻辑查询树作为输入，并负责生成由查询执行引擎解释或者编译的_高效的_执行计划。_执行计划（execution
plan）_（也被成为_计划（plan）_）是一个由物理算子所组成的树，树的边表示为两个操作之间的数据流动。例如在@查询处理流程\中展示了@query1\在经过查询优化后输出的执行计划。对于一个给定的查询来说，生成的执行计划的数量可能会随着引用的表的数量而呈现指数增长的趋势。并且不同的执行计划会有着不同的执行效率。因此，查询的性能很大程度上取决于优化器是否能从大量的执行计划中选择出一个效率高的执行计划的能力。有关关系型数据库的查询优化的概述，可以参考@An-overview-of-query-optimization-in-relational-systems。

*查询执行（Query execution）* 查询执行引擎从查询优化中获取执行的计划，然后生成查询的结果。查询执行引擎实现了一系列的_物理算子_，物理算子负责为查询计划构建数据块。一个物理算子将一个或者多个数据记录作为其输入，称之为_行（rows）_，并输出一组行。常见的物理算子包括`Table Scan`、`Index Scan`、`Index Seek`（详见
@附录 ）、`Hash Join`、`Nested Loops Join`、`Merge Join`、`Sort`等。有关各种物理算子算法的描述，建议参考
@Query-Evaluation-Techniques-for-Large-Databases。

大多数关系型数据库中，执行引擎都使用迭代器模型，这个模型的每一个物理算子都实现`Open`、`GetNext`、`Close`这三个方法。每一个迭代器都包含了记录其状态（包括大小、哈希表的位置等信息）。在`Open`中，算子初始化并且开始准备处理数据。当`GetNext`被调用的时候，算子会生成下一个输出的行，或者返回没有行（没有结果，意味着处理的结束）。这不难想到，要生成输出的行，执行计划中的非叶节点必须要多次对其子算子调用`GetNext`。例如在@查询处理流程\中，`Nested Loop Join`算子在`Hash Join`算子上调用`GetNext`，而`Hash Join`算子又调用了`Table Scan`的`GetNext`方法。当一个算子完成了输出（也就是没有更多的行了），父算子会对其调用`Close`方法，允许其清理状态信息。上述迭代器模型可以方便的添加新的算子，由于每一个运算符都是一个迭代器，对数据执行的是“拉”取操作。所以也被成为_拉取模型（pull
module）_。这里建议通过阅读@Volcano---An-Extensible-and-Parallel-Query-Evaluation-System\来了解更多的关于执行引擎中_pull
module_的相关知识。

但是迭代器模型存在较高的函数调用开销，每一次调用`GetNext`仅处理了一行数据，在现代CPU上的性能表现并不理想。_向量化（Vectorization）_支持批量处理，也就是说，每一次物理算子调用`GetNext`都可以处理一批数据行，并且利用现代CPU的SIMD（）@MonetDB-X100--Hyper-Pipelining-Query-Execution\指令集。结合列式存储@C-store--a-column-oriented--DBMS\，向量化显著的提高了哪些用于决策的查询的执行效率。此外，_代码生成（code
generation）_是一个可以从执行计划生成高效代码的技术。例如使用C语言，生成的代码随后被编译执行。或者利用LLVM这样的工具直接生成机器码。在@Everything-You-Always-Wanted-to-Know-About-Compiled-and-Vectorized-Queries-But-Were-Afraid-to-Ask\讨论了向量化与编译的一些取舍，感兴趣可以看一下。

== 查询优化的关键挑战<查询优化的关键挑战>

为了在众多可选的执行计划中选择最为高效的那一个，查询优化器必须明确需要_搜索的空间（Search
space）_，然后通过_代价估计（Cost estimation）_来比较不同的执行计划，最后通过_搜索算法（Search
Algorithm）_遍历搜索空间，找到执行执行效率比较低（理想情况下是最低）的那个执行计划。下面我们来简单的介绍以下查询优化器的这几个方面。

*搜索空间（Search space）* 对于一个查询来说，搜索空间包含了大量的等价的执行计划。如果这个查询非常复杂，那么这个搜索空间也会非常的大。首先，对于一个给定的查询的代数表示来说，它可以等价的转换成不同的代数表示。这种等价转换的主要原因是关系代数的一些性质。例如$italic("Join(Join(R, S), T)") arrow.l.r.double.long italic("Join(Join(S, T), R)")$就是利用了Join操作的交换律与结合率@Normal-Forms-and-Relational-Database-Operators。在@等价的逻辑查询树\中展示了同一个查询语句的四种等价而关系代数的表示方式。

#picture-figure("等价的逻辑查询树", image("../pic/等价的逻辑查询树.png"))<等价的逻辑查询树>

其次，对于一个给定的逻辑算子他也有众多不同的实现方式。因此一个给定的逻辑查询树会有众多不同的执行计划。例如在@相同的逻辑计划会有不同的执行计划\中，对于给定的$(a)$图中的逻辑查询树来说，我们在众多执行计划中，还给出了等价的三种执行计划$(b)、(c)、(d)$。尽管这三种执行计划的`Join`算子的求值顺序是相同的，但是用于实现`Join`的物理算子却有所不同。在$(a)$中的`Select`逻辑算子可以使用`Table Scan`、`Index Scan`或者`Index Seek`来实现。并且`Join`算子也可以使用`Nested Loops Join`、`Hash Join`、`Merge Join`来实现。当$S$与$T$之间的_连接大小（Join
size）_比较小，且在列$R.a$上才在索引$I_a$的时候，$(b)$是效率最高的执行计划。当$S.b$以及$R.a$分别存在索引$I.b、I.a$时，`Merge Join`的效率是最高的（也就是索引提供`Merge Join`所需的字段的排序）。相比之下，当$S、R$之间的连接规模比较大的时候，`Hash Join`可能是首选。因此，除非优化器在其搜索空间中考虑到了每一个这样的执行计划，并且比较它们的资源的使用情况以及预期的相对性能，否则根本无法生成一个好的执行计划。

#picture-figure("相同的逻辑计划会有不同的执行计划", image("../pic/给定逻辑计划的不同执行计划.png"))<相同的逻辑计划会有不同的执行计划>

*代价估计（Cost estimation）* 相同查询的不同执行计划会有不同的效率，我们通过消耗的时间以及资源（例如CPU、内存、I/O）来度量。如@相同的逻辑计划会有不同的执行计划\所示，对于大型的数据库的复杂查询来说，一个好的执行计划与一个差的执行计划之间的在时间消耗的差距可能是几个数量级的差距。因此，为了为一个查询在搜索空间里选择一个好的执行计划，查询优化器通常使用_代价模型（Cost
Module）_来准确的估算执行查询所需的工作，以便对执行计划进行相对比较。具体来说，一个物理算子必须通过查询的连接关系的大小以及统计信息来估算用于实现该操作的算法所需的代价。最后，尽管在成本的估算中有至少三个维度的信息（CPU、内存、I/O），但是最后代价模型会将多个维度的结果变成一个数字，用于在不同的两个执行计划之间进行比较。

*搜索算法（Search Algorithm）* 原则上，我们可以通过枚举每一个搜索空间中的执行计划，并且调用代价模型来确定每一个计划的成本，最终找到代价最低的计划。但是不同的执行计划可能会共享相同的逻辑/逻辑查询树（子树），例如@等价的逻辑查询树\中的`Select`以及在@相同的逻辑计划会有不同的执行计划\中的`Table Scan`。所以在枚举的时候需要避免重复的探索。但是即便如此，在实际的应用中，枚举的成本依旧是极其高昂的。因此一个优秀的查询优化器会在不显著影响执行计划的选择的情况下，尽量降低枚举的成本。

总的来说，一个优秀的查询优化器应该具备以下几个特点：
+ 考虑足够大的潜在的计划的搜索空间。
+ 对执行计划的成本能够准备的建模，以便能够在不同的计划中找到相对来说更高效的计划。
+ 提供一种搜索算法可以高效的找到低成本的执行计划。

== System R 查询优化器

IBM的System R项目是查询优化领域的先驱者。我们简单的回顾一下System
R的查询优化器是如何解决在@查询优化的关键挑战\中提到的这些挑战的。该项目中使用的技术对所有后来者都产生了深远的影响（包括可扩展的查询优化器）。

*搜索空间* System
R基于成本的查询优化的计划选择主要聚焦于选择-投影-连接（Select-Project-Join，SPJ）这几类查询。对于Select这个逻辑算子的物理算子实现包含`Table Scan`以及`Index Scan`。对于Join，System
R提供了两个物理算子：`Nested Loops Join`以及`Merge Join`（需要两个连接的列都是有序的）。对于在@query1\的例子，就像@等价的逻辑查询树\以及@相同的逻辑计划会有不同的执行计划\中展示的一样，对于SPJ查询来说，有着众多逻辑查询树以及执行计划。这主要是因为Join操作具有结合率以及交换律，并且Scan以及Join存在多种物理算子的实现。System
R针对SPJ查询的搜索空间局限于二叉连接操作的_线性序列（linear squence）_空间。例如$italic("Join(Join(R, S), T), U)")$。在@线性序列空间以及浓密空间\左侧展示了一个线性连接的序列的例子。而图右侧的逻辑查询树并不在System
R的搜索空间内。此外，优化器还提供了基于程序分析而并非基于代价的提高嵌套查询效率的技术。

#picture-figure("线性序列空间（Linear）以及浓密（Bushy）空间", image("../pic/线性序列空间以及浓密空间.png"))<线性序列空间以及浓密空间>

*代价估计* System R使用公式来估算执行计划中每一个算子的CPU以及I/O成本。与现在的查询优化器不同，System
R中并没有将内存纳入到成本的估算中。System
R的优化器维护了一系列关于表以及索引的统计信息。例如：表的行数、表的数据页的数量、索引的页数、每一列中不同值的数量。System
R提供了一组公式来计算单个谓词或者Join谓词的被选择的可能性。对于包含多个Select的`WHERE`语句来说，被选择的可能性由所有谓词的选择的可能性的乘积来决定（这也是假设了每个谓词都是相互独立的）。因此Join输出的基数估计为：两个输入关系的基数的乘积$times$所有谓词的选择性。成本模型公式与基于表与索引的统计信息相结合，就能使得System
R可以估算出每一个执行计划的CPU以及I/O成本。

*搜索算法* System R的优化器使用_动态规划（dynamic
projramming）_这种搜索算法来找到“最优”的Join顺序。这种算法核心依赖于代价模型是是满足_最优性原理（principle of
optimality）_的。换句话说，它假设在一个线性序列的Join中，n个Join的最优计划可以通过将n-1个最优计划扩展一个额外的Join来获得。例如：$R$、$S$、$T$的最优连接计划是$P_("RST")$，那么$P_("RST")$可以通过三种方式来获得：将$R$与$P_("ST")$连接、将$S$与$P_("RT")$连接、将$T$与$P_("RS")$连接。其中，$P_("ST")$、$P_("RT")$、$P_("RS")$分别是$S$与$T$、$R$与$T$、$R$与$S$的最优Join计划。与枚举所有Join的朴素方式（时间复杂度为$O(n!)$）不同，动态规划仅枚举了$O("n2"^(n-1))$个计划，因此速度更快。尽管时间复杂度依旧是随着连接的数量而指数增长的。

System R的搜索算法中还有一个比较重要的方面：_有趣的排序（interesting orders）_#footnote("译者注：指合并的结果是有序的。")。以一个Join三张表R、S、T的查询Q为例，其连接谓词$R.a = S.a$和$S.a = T.a$。假设使用`Index Seek`在S表执行`Nested Loops Join`的成本低于使用`Merge Join`的成本。此时优化器在考虑R、S、T的连接计划时，会剪枝掉使用`Merge Join`的R和S的计划。然而使用`Merge Join`会使得连接结果按照`a`排序，这可能会显著降低后续与T表的`Merge Join`的成本。因此这种剪枝方式会导致查询的次优解。

#let 有趣性注释 = [
译者注：同一个逻辑表达式的不同物理计划，若有趣性不同（例如一个有序一个无序），将视为不同的子问题，分别保留最优解。例如$R join S$会同时保留`Merge Join`以及`Nested Loops Join`的结果，即使其中一个在当前步骤中成本较高。
]

这里的核心问题在于，算子输出的有序性（也就是算子具有有趣性）可能会降低父算子亦或者祖先算子的成本。为了在动态规划的框架下处理因有趣性导致的与最优性原理冲突，并且保留动态规划的优势，搜索算法在枚举每一个表达式的时候都会考虑有趣性。具体来说，当且仅当表达式的有趣性相同时，才对其计划进行代价的比较#footnote(有趣性注释)，并且为不同的有序序列保留一个最优的计划。

== 可扩展的查询优化器架构

System
R引用的重要的概念几乎被所有主流查询优化器采用，包括使用统计数据以及代价模型确定执行计划、基于动态规划的Join顺序以及考虑有趣性的必要性。然而这种框架无法以基于成本的方式灵活的、高效的扩展到关系代数中的其他等价变换以及新形态的数据库中，这会错失更低成本的查询计划。随着关系型数据库以及SQL在决策中愈发重要，这些额外的代数等价变换在生成更加高效的执行计划中也变得日益重要。这些代数等价变化包括：将Group-by下推到Join下面执行以降低Join的成本、优化非关联写非交换的Outer
Joins以及去除嵌套查询的关联性。此外数据库系统引入的一些新的架构可以显著的降低执行的成本，例如物化视图（materialized
views）@Materialized-Views@Materialized-views-techniques-implementations-and-applications\通过预计算并存储查询子表达式的结果来显著降低查询执行的成本，这对OLAP以及其他分析型工作至关重要。此外优化器还需要为了支持更加高效的执行SQL查询而引入新的逻辑/物理算子，例如Apply@Orthogonal-Optimization-of-Subqueries-and-Aggregation。

幸运的是，随着SQL查询优化器的实际要求在不断地扩展，关于可以扩展的数据库系统的研究为扩展System
R架构提高来替代方案。可扩展的数据库系统被能够根据应用的需求定制数据库系统。具体的来说，Exodus@The-EXODUS-extensible-DBMS-project-an-overview\以及后来的Volcano@Volcano---An-Extensible-and-Parallel-Query-Evaluation-System\（可以支持用户指定的查询执行算子）都是在这种背景下出现的。由于需要支持自定义的算子，所以提供可扩展的查询优化器框架成为了必然。因此，优化器的可扩展性一开始就是Volcano的特性。并且Volcano最初被设想为“用于多种目的的实验工具”@Volcano---An-Extensible-and-Parallel-Query-Evaluation-System\。它允许架构师从专家系统（产生式系统）中获取灵感，设计可插拔一个新的_规则（rules）_，从而扩展优化器的功能。后来，Volcano/Cascades@The-Cascades-Framework-for-Query-Optimization@The-Volcano-Optimizer-Generator--Extensibility-and-Efficient-Search\和Starburst@Grammar-like-functional-rules-for-representing-query-optimization-alternatives@Grammar-like-functional-rules-for-representing-query-optimization-alternatives-2@A-Rule-Engine-for-Query-Transformation-in-Starburst-and--IBM---DB2\等可扩展的优化器框架将SQL查询优化作为了核心的应用场景，这满足了SQL查询优化对新架构的迫切要求。

在本文的大部分内容中，我们都将聚焦于Volcano/Cascades的可扩展优化器。这些可扩展的优化框架都围绕规则（rules）这个概念展开。_逻辑转换规则（logical
transformation
rule）_表示的是SQL（或者是关系代数）的等价关系。例如前面提到的Join的交换律以及结合率所蕴含的等价关系就可以通过规则来表达。类似，一条规则可以定义将Group-by下推到Join下的等价关系。对一个查询树应用逻辑转换规则可以生成一个等价的查询树。_实现规则（implementation
rule）_定义了逻辑算子（例如Join）到物理算子（例如Hash
Join）的映射。要为查询生成一个执行计划，就需要用到实现规则。合理的选择一系列规则的应用方式，就可以将查询树转换一个高效的执行计划。有一点需要注意，在这种架构下，每次引入一个新的算子、逻辑转换以及实现规则的时候，无须修改优化器的搜索算法。但是必须注意到，转换并不一定会降低成本，因此搜索算法必须以基于成本的方式在各种替代方案中选择。

SQL是一个声明式的查询语言，这允许查询优化器为SQL查询创建一个高效的执行计划。这些执行计划既保持了语义等价的逻辑转换，又能聪明的为逻辑算子选择高效的实现方式。查询优化的终极目标就是生成语义等价的、与用户/应用无关的，高效的，执行计划。可扩展的优化器通过引入规则，对查询树依次应用规则，并且在基于成本的搜索算法的驱动下，达成这个目标。

== 大纲
在本章节，我们聚焦来可扩展的查询优化器的技术，并且以Microsoft SQL
Server为例阐述了其中的关键概念。与本文的另一个作者的撰写的关于查询优化的概述文章@An-overview-of-query-optimization-in-relational-systems\相比，本书详细介绍了优化器的框架，以及在实际中常用的额外的转换规则。我们通过伪代码以及示例深入讲解了可扩展性框架以及规则。

*@可扩展的查询优化器：*我们回顾了以下可扩展的查询优化器框架Volcano以及其极具影响力的后来者，Cascades框架。我们描述了查询算法以及这两种框架所必须的一些关键数据结构，以及能有效提高查询效率的其他技术。此外，我们通过几个例子展示了Microsoft
SQL Server的查询优化器是如何利用Cascades框架的。最后，我们还说了一下查询优化器是如何应对并行以及分布式查询流程。

*@业界其他可扩展的查询优化器：*在这里我们简单的回顾了一下其他可扩展的查询优化器，包括IBM DB2使用的Starburst、Greenplum
DB使用的Orca、Apache
Hive使用的Calcite、SparkSQL使用的Catalyst。尽管PostgreSQL的查询优化器并不具备Volcano以及Cascades等框架的可扩展性，但是鉴于其受欢迎的程度，我们也对其查询优化器进行一些简要的概述。

*@执行计划的关键转化：*可扩展的优化器的有效性来自于其应用的规则。在这一章节，我们会回顾一些关键的逻辑转换规则实现规则。这些规则包括：基表的访问路径（access
paths to base tables）、内外连接（inner/outer
joins）、分组（group-by）、聚合（aggregation）以及嵌套查询的去相关化（decorrelation of nested
queries）。我们还会精选一些“高级”的规则，例如用于优化常见于数仓的星形以及雪花型查询的规则、侧向信息传递规则（sideways
information passing）、用户定义函数（UDFS, user-defined functions）以及物化视图（materialized views）。

*@代价估计：*优化器框架严重依赖代价模型以及基数估计，在本章节，我们将概述模型以及基数估计，聚焦在业界的实现上。我们将会讨论优化器使用的统计汇总方法，例如直方图，以及它们是如何利用在复杂的查询中。此外，我们还将探讨数据库系统中对采样（Sampling）和草图（Sketches）技术的应用。最后，我们将以Microsoft
SQL Server为例来说明这些概念以及技术。

*@执行计划的管理：*大多数的查询优化的文章都忽略了数据库的整个生命周期内对优化器生成的计划进行管理的问题。而计划的管理会对整体的工作负载的性能起到关键性的影响。在这样的背景下，我们讨论了几个重要的挑战：（a）计划的缓存以及失效（b）利用执行的反馈改进次优计划（c）查询提示，它允许用户影响优化器的计划选择（d）优化参数化查询。

*@开放性问题：*虽然本书主要围绕着实践中的可扩展的查询优化器展开，但是我们在本章节提及一些尚未解决的问题以及正在探索的几个研究方向。

*勘误与更新：* 我们提供了勘误与更新#footnote(
  link(
    "https://www.microsoft.com/en-us/research/project/extensible-query-optimizers-in-practice-errata-and-updates/",
    "https://www.microsoft.com/en-us/research/project/extensible-query-optimizers-in-practice-errata-and-updates/",
  ),
)，我们鼓励读者发现错误后通过邮件向我们报告错误。

== 建议阅读

- Access Path Selection in a Relational Database Management
  System@Access-Path-Selection-in-a-Relational-Database-Management-System\
- Query Evaluation Techniques for Large Databases@Query-Evaluation-Techniques-for-Large-Databases
- An Overview of Query Optimization in Relational Systems@An-overview-of-query-optimization-in-relational-systems