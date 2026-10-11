# 第 43 章 日志结构文件系统

> 英文原题：*Log-structured File Systems*

20 世纪 90 年代初，Berkeley 的 John Ousterhout 教授与研究生 Mendel Rosenblum 带领团队开发了**日志结构文件系统(Log-structured File System, LFS)** [RO91]。动机来自几项观察：

- **系统内存越来越大**：更多数据能留在缓存中，读取越来越常由缓存满足，磁盘流量便以写入为主；文件系统性能因而更取决于写性能。
- **随机 I/O 与顺序 I/O 差距巨大**：硬盘把越来越多位塞进盘面，传输带宽增长很快 [P98]；寻道和旋转延迟却改善缓慢，因为让便宜小马达更快转盘、挪磁臂并不容易。顺序使用磁盘因此优势显著。
- **现有文件系统在常见负载下表现不佳**：FFS [MJLF84] 创建一个单块文件，可能要写新 inode、inode 位图、父目录数据、父目录 inode、新数据块和数据位图。虽在同一块组，许多短寻道与旋转等待仍让性能远低于顺序峰值。
- **文件系统不理解 RAID**：RAID-4/5 的单块逻辑写会造成 4 次物理 I/O；传统文件系统没有主动回避这种最坏的小写入模式。

理想文件系统应重视写性能，充分利用磁盘顺序带宽；常见负载不但写数据，还频繁更新元数据，它也应表现良好；最后，它在单盘与 RAID 上都得好用。

LFS 把所有更新——包括元数据——先缓存在内存**段(segment)**中；段装满后，以一次长顺序传输写到磁盘未使用区域。它从不原地覆盖数据，总向空闲位置写新段。段足够大时，磁盘或 RAID 得到高效利用，性能便接近巅峰。

!!! tip "细节很重要"
    有趣的系统通常由少数总体思想和许多细节组成。学习时很容易想：“大意懂了，剩下只是细节”，于是只学到一半。别这么干！细节常常决定系统能否真正工作。LFS 的总想法很简单，但要造出可用系统，必须逐一想透那些棘手边角。

!!! danger "问题核心：怎样让所有写入都变成顺序写"
    文件系统怎样把所有写入转换为顺序写？读取做不到，因为目标块可能在磁盘任何位置；写入却总有选择，而我们正要利用这种选择。

## 43.1 顺序写入磁盘

假设向文件写数据块 `D`，它落在磁盘地址 `A0`：

```text
A0
┌───┐
│ D │
└───┘
```

用户写数据时，还要更新元数据。若把文件 inode `I` 紧随其后写下，并让它指向 `D`：

```text
A0                    A1
┌───┐  ┌───────────────┐
│ D │  │ I: blk[0]=A0  │
└───┘  └───────────────┘
```

图中 inode 与数据块一样大只是为了画得清楚；实际数据块通常为 4 KB，inode 约 128 字节。把数据块、inode 等一切更新顺序写下，就是 LFS 的核心。基本思想到此已经掌握，魔鬼则照例住在细节里。

## 43.2 高效地顺序写入

按顺序写并不自动等于高效。若在时刻 $T$ 写地址 $A$ 的一块，隔了 $\delta$ 时间才写 $A+1$，磁盘在间隔中已经转过去了；第二次写可能要再等 $T_{rotation}-\delta$。要得到良好性能，必须一次发出许多连续写，或干脆发一个大写入。

LFS 使用古老的**写缓冲(write buffering)**。它先在内存记录更新，积累到足够多时一次写盘。LFS 把这大批更新称为段；计算机系统里“segment”已经身兼数职，这里只表示用来聚合写入的较大数据块，通常有数 MB。

例如先把文件 `j` 的四块更新和文件 `k` 的一块更新聚入一个七块小段，再一次提交：

```text
A0       A1       A2       A3       A4           A5       A6
D[j,0] | D[j,1] | D[j,2] | D[j,3] | Inode[j] | D[k,0] | Inode[k]
                                       ↓0..3                   ↓0
                                      A0..A3                  A5
```

## 43.3 应该缓冲多少

缓冲量取决于磁盘定位开销和传输速率。假设每次写前的寻道加旋转耗时为 $T_{position}$ 秒，峰值传输率为 $R_{peak}$ MB/s；一次写出 $D$ MB 的总时间为：

$$
T_{write}=T_{position}+\frac{D}{R_{peak}}. \tag{43.1}
$$

有效写入速率为：

$$
R_{effective}=\frac{D}{T_{write}}
=\frac{D}{T_{position}+D/R_{peak}}. \tag{43.2}
$$

希望有效速率达到峰值的比例 $F$（$0<F<1$），即：

$$
\frac{D}{T_{position}+D/R_{peak}}=F\times R_{peak}. \tag{43.3}
$$

逐步整理：

$$
D=F\times R_{peak}\times\left(T_{position}+\frac{D}{R_{peak}}\right), \tag{43.4}
$$

$$
D=(F\times R_{peak}\times T_{position})+
  \left(F\times R_{peak}\times\frac{D}{R_{peak}}\right), \tag{43.5}
$$

最终得到：

$$
D=\frac{F}{1-F}\times R_{peak}\times T_{position}. \tag{43.6}
$$

若定位时间 10 ms、峰值 100 MB/s，希望达到 90% 峰值（$F=0.9$），则需缓冲：

$$
D=\frac{0.9}{0.1}\times100\text{ MB/s}\times0.01\text{ s}=9\text{ MB}.
$$

不妨算算达到 95% 和 99% 时需要多少；越想贴近峰值，胃口越大。

## 43.4 问题：寻找 inode

传统 UNIX 文件系统把 inode 放在固定数组中。已知 inode 号与数组起始地址，把编号乘 inode 大小再加起点，就能算出精确磁盘地址。FFS 只是把 inode 表拆成若干块放入柱面组；知道每块大小与起点后，计算仍然容易。

LFS 就没这么省心了：inode 散落全盘，而且从不原地覆盖，所以最新版 inode 还会不断搬家。

## 43.5 用间接层解决：inode 映射

LFS 在 inode 号与 inode 之间加入 **inode 映射(inode map, imap)**。输入 inode 号，imap 返回其最新版本的磁盘地址。它通常可实现为简单数组，每项用 4 字节磁盘指针；每当 inode 写到新位置，相应映射就更新。

!!! tip "使用一层间接"
    人们常说，计算机科学的一切问题都能用一层间接解决。显然不对——它只是解决了大多数问题。虚拟内存、文件抽象和 LFS 的 imap 都是间接层；它让页面或 inode 自由搬家，而无需修改所有引用。

    间接也有额外开销。下次遇到问题，不妨先试一层间接，但记得算账。Wheeler 的名言是：“计算机科学中的所有问题都能再加一层间接解决——当然，间接层太多的问题除外。”

imap 必须持久化，才能在崩溃后找回 inode。若把它放在磁盘固定位置，每次更新文件后都要跳过去写 imap，顺序性能便毁了。LFS 因此把 imap 的片段紧邻其他新信息一同写下：

```text
A0      A1                A2
┌───┐  ┌──────────────┐  ┌─────────────┐
│ D │  │ I[k]: blk0=A0│  │ imap[k]=A1  │
└───┘  └──────────────┘  └─────────────┘
```

imap 片段说 inode `k` 位于 `A1`；inode 又说数据块 `D` 位于 `A0`。

## 43.6 补齐方案：检查点区域

机敏的读者（是你吧？）会继续问：imap 片段也散布全盘，又从哪里找到它们？终究没有魔法，文件系统必须有一个固定且已知的查找起点。

LFS 使用**检查点区域(checkpoint region, CR)**。CR 保存最新 imap 各片段的地址；先读 CR，就能找到 imap。CR 只周期性更新，例如每 30 秒一次，不会严重伤害性能。

```text
地址 0          A0      A1               A2
┌──────────┐    ┌───┐  ┌──────────────┐ ┌─────────────┐
│ CR       │───>│ D │  │ I[k]:blk0=A0 │ │ imap[k]=A1  │
│ imap→A2  │    └───┘  └──────────────┘ └─────────────┘
└──────────┘
```

真实系统有更大的 CR——实际上有两份，稍后会解释——以及许多 imap 片段、inode 和数据块。

## 43.7 从磁盘读取文件：回顾

假设内存一片空白。LFS 先读取 CR，由其中指针找到整个 imap，并把它缓存到内存。此后给定文件 inode 号，只需在 imap 查出最新版 inode 的磁盘地址并读取它。再读文件块时，便像传统 UNIX 文件系统一样使用直接、间接或二级间接指针。

常见情况下，LFS 读取文件所需 I/O 数与传统系统相同；imap 已缓存，额外工作只是一次内存映射查询。

## 43.8 目录怎么办

目录结构与经典 UNIX 基本相同：目录仍是一组“名称—inode 号”映射。创建目录 `dir` 中的文件 `foo`（inode 号 `k`）时，LFS 顺序写下新文件数据及 inode、目录数据及 inode，还有 imap 片段：

```text
A0      A1             A2                A3              A4
D[k] | I[k]          | D[dir]          | I[dir]        | imap
       blk0=A0         (foo,k)            blk0=A2         k→A1, dir→A3
```

访问 `foo` 时，先从内存 imap 找到 `dir` 的 inode 地址 `A3`；读目录 inode，得到目录数据地址 `A2`；读目录项得到 `(foo,k)`；再查 imap 找到 inode `k` 位于 `A1`，最后从 `A0` 读取数据。

imap 还解决了**递归更新问题(recursive update problem)** [Z+12]。不原地更新的系统每次移动 inode，若目录直接记录其地址，就必须更新目录；目录移动又要求更新父目录，如此一路冲到根。LFS 的目录只保存稳定的 inode 号，位置变化只改 imap，因此这场递归雪崩被一层间接挡住了。

## 43.9 新问题：垃圾回收

LFS 不断把文件最新版写到新位置，于是旧版 inode 和数据块散落全盘。我们毫不客气地称它们为**垃圾(garbage)**。

若 inode `k` 最初指向 `A0` 的 `D0`，后来覆盖该块，会留下旧、新两套：

```text
A0     A1             A4     A5
D0   | I[k]         | D0'  | I[k]'
旧数据  旧 inode      新数据  新 inode
└──────垃圾──────┘
```

若不是覆盖，而是追加 `D1`，旧 inode 成为垃圾，原 `D0` 仍被新版 inode 引用，依然存活：

```text
A0     A1          A4     A5
D0   | I[k]旧    | D1   | I[k]新: blk0=A0, blk1=A4
       垃圾        存活    存活
```

一种选择是保留旧版本，让用户恢复误删或误覆盖文件；这叫**版本化文件系统(versioning file system)**。LFS 只保留最新活版本，因此后台必须定期找出死亡版本并清理，重新释放块。这与编程语言自动释放无用内存的垃圾回收相似。

若清理器逐块释放，磁盘会布满夹在已用区域间的小洞，LFS 再也找不到大块连续空间，写性能大跌。因此清理以段为单位：读入 $M$ 个部分使用的旧段，判断哪些块仍活着，把活块压缩进 $N$ 个新段（$N<M$）并写到新位置，再释放旧的 $M$ 段。

于是还有两个问题：机制上怎样判断块死活？策略上何时清理、清理哪些段？

## 43.10 判断块是否存活

每个段头部有**段摘要块(segment summary block)**，为每个数据块记录所属 inode 号和文件内偏移。

已知地址 `A` 的数据块 `D`，从段摘要得到 inode 号 `N` 和偏移 `T`；查 imap 找到并读取 inode `N`；再查看 inode（或间接块）认为文件第 `T` 块位于哪里。若恰为 `A`，`D` 仍活；否则它已死：

```text
(N, T) = SegmentSummary[A];
inode = Read(imap[N]);
if (inode[T] == A)
    // D 仍存活
else
    // D 是垃圾
```

```text
段摘要 SS: A0=(k,0)    A0:D    A1:I[k, blk0=A0]    imap[k]=A1
```

LFS 还有捷径。文件被截短或删除时，提高其版本号，并把新版本号记入 imap；段中也记录版本号。清理器比较二者即可迅速淘汰旧版本，避免额外读取 inode。

## 43.11 策略问题：清理哪些块、何时清理

何时清理比较容易：周期性运行、空闲时运行，或磁盘满得不得不运行。

清理哪些段更难，也是许多论文的主题。原始 LFS [RO91] 区分冷热段。**热段(hot segment)**内容频繁覆盖，最好久等，让更多块自然死亡；**冷段(cold segment)**只有少量死块，其余内容稳定，反而应较早清理。作者据此设计启发式算法。不过策略从来少有完美，后续工作提出了更好的办法 [MR+97]。

## 43.12 崩溃恢复与日志

正常运行时，LFS 缓冲一个段，段满或超时后写盘。CR 指向日志的头尾段，每段再指向下一个；CR 也周期性更新。崩溃可能发生在写段或写 CR 时。

为了原子更新 CR，LFS 在磁盘两端各保存一份并交替写入。更新时先写带时间戳的头部，再写 CR 主体，最后写同样带时间戳的尾块。若中途崩溃，两处时间戳不一致；启动时选择时间戳匹配且最新的 CR。

CR 约每 30 秒才更新，若恢复只读取最后一致的 CR，最近几十秒更新会丢失。LFS 因此使用数据库里的**前滚(roll forward)**：从最后检查点开始，根据 CR 中的日志末端位置继续扫描后续段；发现有效更新便纳入文件系统，从而找回检查点之后的大部分数据与元数据。细节见 Rosenblum 的获奖博士论文 [R92]。

## 43.13 小结

LFS 不原地覆盖，而把更新写入未使用区域，之后通过清理回收旧空间。数据库把这类技术称为**影子分页(shadow paging)** [L77]，文件系统中也常称写时复制。聚合内存更新后一次顺序写段，带来极高写入效率。

大写入对多种设备都有好处：硬盘上减少定位时间；RAID-4/5 上完全避开小写入问题；研究还表明，闪存 SSD 也需要大 I/O 才能获得高性能 [H+17]。出人意料地，LFS 风格甚至很适合新介质。

代价是垃圾。旧副本散落磁盘，必须周期性清理。清理成本引起过不少争论 [SS+95]，也可能限制了 LFS 的早期影响。不过 NetApp WAFL [HLM94]、Sun ZFS [B07]、Linux btrfs [R+13] 乃至现代 SSD [AD14] 都采用了类似的写时复制思想，LFS 的精神仍活得很好。WAFL 还把旧版本变成快照功能，让误删用户取回旧文件，同时减少清理压力。

!!! tip "把缺陷变成优点"
    系统若有根本缺陷，试着把它变成特性。WAFL 把旧文件内容开放为快照，既提供酷功能，又缓解 LFS 清理问题。

    系统里还有别的例子吗？肯定有，但得你自己想，因为本章真的结束了——大写的“结、束”。完了。收工。没了。拜拜！

## 参考文献

- [AD14] “Operating Systems: Three Easy Pieces” (Chapter: Flash-based Solid State Drives) by Remzi and Andrea Arpaci-Dusseau. 把你转介到本书另一章有点俗气，但我们哪有资格评判？
- [B07] “ZFS: The Last Word in File Systems” by Jeff Bonwick and Bill Moore. ZFS 幻灯片；可惜还没有一篇伟大的 ZFS 论文。也许由你来写，好让我们引用？
- [H+17] “The Unwritten Contract of Solid State Drives” by Jun He et al. EuroSys '17. SSD 想跑得快必须遵守哪些不成文规则？请求规模与局部性在 SSD 上仍很重要。越是变化……
- [HLM94] “File System Design for an NFS File Server Appliance” by Dave Hitz et al. USENIX '94. WAFL 汇集 LFS 与 RAID 思想，成为 NetApp 高速 NFS 设备的基础。
- [L77] “Physical Integrity in a Large Segmented Database” by R. Lorie. *ACM TODS* 2:1, 1977. 影子分页思想的早期来源。
- [MJLF84] “A Fast File System for UNIX” by Marshall K. McKusick et al. *ACM TOCS* 2:3, 1984. 原始 FFS 论文。
- [MR+97] “Improving the Performance of Log-structured File Systems with Adaptive Methods” by Jeanna Neefe Matthews et al. SOSP '97. 更好的 LFS 清理策略。
- [M94] “A Better Update Policy” by Jeffrey C. Mogul. USENIX ATC '94. 写缓冲太久再突发写盘可能伤害读负载，因此建议更频繁、更小批地写。
- [P98] “Hardware Technology Trends and Database Opportunities” by David A. Patterson. SIGMOD '98 keynote. 关于系统技术趋势的优秀幻灯片；希望 Patterson 不久再做一份。
- [R+13] “BTRFS: The Linux B-Tree Filesystem” by Ohad Rodeh et al. *ACM TOS* 9(3), 2013. 终于有篇好论文介绍现代写时复制文件系统 BTRFS。
- [RO91] “Design and Implementation of the Log-structured File System” by Mendel Rosenblum and John Ousterhout. SOSP '91. LFS 原始论文，启发数百篇论文和许多真实系统。
- [R92] “Design and Implementation of the Log-structured File System” by Mendel Rosenblum. 获奖博士论文，补足会议论文省略的大量细节。
- [SS+95] “File system logging versus clustering: a performance comparison” by Margo Seltzer et al. USENIX 1995. 指出 LFS 在频繁 `fsync()` 等负载下会出问题，当年颇有争议。
- [SO90] “Write-Only Disk Caches” by Jon A. Solworth and Cyril U. Orji. SIGMOD '90. 写缓冲及其收益的早期研究。
- [Z+12] “De-indirection for Flash-based SSDs with Nameless Writes” by Yiying Zhang et al. FAST '13. 让设备选择写入物理位置并把地址返回文件系统，以避免文件系统和 FTL 中重复映射。

## 作业（模拟器）

使用 `lfs.py` 理解 LFS。详情见 README。

1. 运行 `./lfs.py -n 3`，改变 `-s` 种子。推断生成最终状态的命令、命令顺序以及各块是否存活；用 `-o` 显示命令、`-c` 显示存活性。把 `-n 3` 增至 `-n 5` 后难多少？
2. 若上题很痛苦，用 `./lfs.py -n 3 -i` 显示每条命令造成的更新，再换种子练习。
3. 运行 `./lfs.py -o -F -s 100`。它只显示命令，不显示最终状态；推导最终文件系统。
4. 运行 `./lfs.py -n 20 -s 1`，判断哪些路径有效；用 `-c -v` 检查，用 `-o` 对照命令，再换种子。
5. 用 `-L c,/foo:w,/foo,0,1:w,/foo,1,1:w,/foo,2,1:w,/foo,3,1 -o` 创建 `/foo` 并分四次写四块。判断最终块的存活性，用 `-c` 检查。
6. 改为一次写四块：`./lfs.py -o -L c,/foo:w,/foo,0,4`。与逐块写有何主要区别？这说明真实 LFS 在内存缓冲更新有多重要？
7. 比较 `./lfs.py -L c,/foo:w,/foo,0,1` 与 `./lfs.py -L c,/foo:w,/foo,7,1`。二者做什么、哪里不同？inode 的大小字段说明什么？
8. 比较 `./lfs.py -L c,/foo` 和 `./lfs.py -L d,/foo`，观察创建文件与目录的异同。
9. 运行 `./lfs.py -L c,/foo:l,/foo,/bar:l,/foo,/goo -o -i` 研究硬链接。创建链接会写哪些块？与创建新文件有何异同？引用计数怎样变化？
10. 比较顺序 inode 分配 `./lfs.py -p c100 -n 10 -o -a s` 与随机分配 `-a r`。磁盘布局有何差异？真实 LFS 选择 inode 号为什么重要？
11. 模拟器通常每次更新后都写 CR，真实 LFS 只周期性更新。运行 `./lfs.py -N -i -o -s 1000`。CR 永不更新会怎样？周期更新又如何？能否沿日志前滚恢复到最新状态？
