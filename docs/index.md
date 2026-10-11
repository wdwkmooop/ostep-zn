# 操作系统导论：三个简单部件

> *Operating Systems: Three Easy Pieces* 中文翻译 · **虚拟化、并发与持久化**

欢迎。这里是把 [OSTEP](https://www.ostep.org)（*Operating Systems: Three Easy Pieces*，
Remzi H. Arpaci-Dusseau 与 Andrea C. Arpaci-Dusseau 著）翻译成中文的在线版本。

书名的"三个简单部件"，是向费曼那本《六堂容易的物理课》致敬：操作系统这门课，
绕来绕去也就三件大事——

1. **虚拟化 (virtualization)** —— CPU 与内存
2. **并发 (concurrency)** —— 多个线程一起跑
3. **持久化 (persistence)** —— 数据怎么存得住

本译本已完成**第一部分：虚拟化**（前言 + 第 1~24 章）和**第二部分：并发**（第 25~34 章），
**第三部分：持久化**（第 35~51 章，包含分布式系统）正文也已全部完成，附录 A~H 亦已翻译。至此，前言、三个部分正文和全部附录均已收尾。作者写书的口吻相当贫嘴，
我们的目标是把它用同样好笑的口气讲成中文。请从左边目录开始，或直接跳到：

- [第 4 章 抽象：进程](04-the-process.md) —— 建议的入门样板章
- [第 2 章 操作系统导论](02-introduction.md)
- [第 26 章 并发：介绍](26-concurrency-introduction.md)
- [第 32 章 常见并发问题](32-common-concurrency-problems.md)
- [第 34 章 并发总结对话](34-summary-dialogue-concurrency.md)
- [第 36 章 I/O 设备](36-io-devices.md)
- [第 38 章 廉价冗余磁盘阵列（RAID）](38-raids.md)
- [第 39 章 插叙：文件与目录](39-files-and-directories.md)
- [第 42 章 崩溃一致性：FSCK 与日志](42-crash-consistency-fsck-and-journaling.md)
- [第 44 章 基于闪存的 SSD](44-flash-based-ssds.md)
- [第 46 章 持久化总结对话](46-summary-dialogue-persistence.md)
- [第 48 章 分布式系统](48-distributed-systems.md)
- [第 49 章 Sun 网络文件系统（NFS）](49-nfs.md)
- [第 50 章 Andrew 文件系统（AFS）](50-afs.md)
- [第 51 章 分布式总结对话](51-summary-dialogue-distribution.md)
- [附录 B 虚拟机监控器](appendix-b-virtual-machine-monitors.md)
- [附录 D 管程（已弃用）](appendix-d-monitors-deprecated.md)
- [附录 F 实验：教程](appendix-f-laboratory-tutorial.md)
- [附录 G 实验：系统项目](appendix-g-laboratory-systems-projects.md)
- [附录 H 实验：xv6 项目](appendix-h-laboratory-xv6-projects.md)

!!! note "关于版权"
    原书 © 2008–18 Arpaci-Dusseau 作者，可自由在线阅读。本译本仅供学习交流，
    版权归原作者所有；若你喜欢，请到 [ostep.org](https://www.ostep.org) 支持原书。

!!! tip "给译者 / 协作者"
    本工程用 Markdown 书写、MkDocs Material 生成静态站。开工前请阅读仓库根目录的
    `AGENTS.md`（工作指南）与[术语对照表](glossary.md)。
