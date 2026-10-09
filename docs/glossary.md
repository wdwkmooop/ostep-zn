# 术语对照表 (Glossary)

> **动手翻译前先查此表。** 表中没有的术语：定下译名后**追加到本表**，再统一使用。
> 规则见 `style-guide.md` §3：首现写 `中文(english)`，标识符永不翻译。

## 通用 / 概述

| English | 中文 | 说明 |
|---|---|---|
| operating system | 操作系统 | |
| virtualization | 虚拟化 | |
| concurrency | 并发 | 与"并行(parallelism)"区分 |
| persistence | 持久化 | |
| abstraction | 抽象 | |
| mechanism | 机制 | 与策略相对 |
| policy | 策略 | |
| crux | 问题核心 | 书的特色框，见 style-guide §4 |
| aside | 边栏 | `!!! note "边栏"` |
| tip | 提示 | `!!! tip "提示"` |
| dialogue | 对话 | 对话章 |
| virtual machine | 虚拟机 | 操作系统也可看作一台虚拟机 |
| resource manager | 资源管理器 | 操作系统的角色之一 |
| application programming interface (API) | 应用程序编程接口 (API) | 正文通常简称接口 (API) |
| standard library | 标准库 | |
| overhead | 开销 | 时间或空间上的额外成本 |
| protection | 保护 | |
| isolation | 隔离 | 保护所依赖的基本原则 |
| reliability | 可靠性 | |
| privilege level | 特权级 | |
| atomic / atomically | 原子的 / 原子地 | 不可分割地一次完成 |
| volatile | 易失性的 | 断电后数据丢失 |
| batch processing | 批处理 | |
| minicomputer | 小型机 | 历史术语 |
| performance | 性能 | |
| control | 控制 | 操作系统对 CPU/系统的控制 |
| nondeterministic / nondeterminism | 不确定的 / 不确定性 | 运行顺序或结果不可预先确定 |
| manual page (man page) | 手册页 | UNIX 原生文档形式 |
| user | 用户 | 系统身份与权限概念 |

## CPU 虚拟化 / 进程

| English | 中文 | 说明 |
|---|---|---|
| process | 进程 | |
| program | 程序 | |
| machine state | 机器状态 | |
| process control block (PCB) | 进程控制块 (PCB) | |
| process list / task list | 进程列表 / 任务列表 | |
| process descriptor | 进程描述符 | |
| context switch | 上下文切换 | |
| register context | 寄存器上下文 | |
| program counter (PC) | 程序计数器 (PC) | 亦作指令指针 (IP) |
| instruction pointer (IP) | 指令指针 (IP) | |
| stack pointer | 栈指针 | |
| frame pointer | 帧指针 | |
| running / ready / blocked | 运行 / 就绪 / 阻塞 | 进程三态 |
| scheduled / descheduled | 被调度 / 被取消调度 | |
| zombie | 僵尸进程 | 原文 zombie state = 僵尸状态 |
| initial state / final state | 初始状态 / 终止状态 | |
| time sharing | 时间共享 | |
| space sharing | 空间共享 | |
| loading | 加载 | |
| eager / lazy | 急切地 / 惰性地 | 加载方式 |
| executable format | 可执行格式 | |
| file descriptor | 文件描述符 | |
| suspend / resume | 挂起 / 恢复 | |
| limited direct execution | 受限制的直接执行 | ch6 标题 |
| kernel mode | 内核态 | |
| user mode | 用户态 | |
| system call | 系统调用 | |
| trap / return-from-trap | 陷入 / 从陷入返回 | |
| interrupt | 中断 | |
| timer interrupt | 时钟中断 | |
| register | 寄存器 | |
| stack | 栈 | |
| heap | 堆 | 保持英文 heap 亦可 |
| fork() | fork() | 标识符不译 |
| exec() | exec() | |
| wait() | wait() | |
| signal | 信号 | |
| superuser (root) | 超级用户 (root) | |
| process identifier (PID) | 进程标识符 (PID) | |
| parent process / child process | 父进程 / 子进程 | |
| process group | 进程组 | |
| thread | 线程 | |
| multi-threaded | 多线程的 | |
| multiprogramming | 多道程序设计 | |
| restricted operation | 受限操作 | |
| privileged operation | 特权操作 | |
| kernel stack | 内核栈 | 每个进程进入内核时使用的栈 |
| calling convention | 调用约定 | |
| system-call number | 系统调用号 | |
| trap table | 陷阱表 | 保存陷阱处理程序入口 |
| trap handler | 陷阱处理程序 | |
| cooperative scheduling | 协作式调度 | 依赖进程主动交还 CPU |
| yield | 主动让出 | `yield` 系统调用保留英文标识符 |
| disable interrupts | 禁用中断 | |
| locking | 加锁 | 保护并发访问 |

## 调度

| English | 中文 | 说明 |
|---|---|---|
| scheduler | 调度器 | |
| scheduling | 调度 | |
| workload | 负载 | |
| turnaround time | 周转时间 | |
| response time | 响应时间 | |
| First In, First Out (FIFO) | 先来先服务 (FIFO) | |
| Shortest Job First (SJF) | 最短作业优先 (SJF) | |
| Shortest Time-to-Completion First (STCF) | 最短完成时间优先 (STCF) | |
| Round Robin (RR) | 轮转 (RR) | |
| Multi-Level Feedback Queue (MLFQ) | 多级反馈队列 (MLFQ) | |
| priority | 优先级 | |
| priority boost | 优先级提升 | |
| starvation | 饥饿 | |
| lottery scheduling | 彩票调度 | |
| ticket | 彩票 | |
| proportional share | 比例份额 | |
| stride scheduling | 步长调度 | |
| Completely Fair Scheduler (CFS) | 完全公平调度器 (CFS) | |
| multiprocessor | 多处理器 | |
| cache affinity | 缓存亲和性 | |
| load balancing | 负载均衡 | |

## 内存虚拟化

| English | 中文 | 说明 |
|---|---|---|
| address space | 地址空间 | |
| virtual address | 虚拟地址 | |
| physical address | 物理地址 | |
| address translation | 地址转换 | |
| relocation | 重定位 | |
| base / bounds | 基址 / 界限 | |
| segmentation | 分段 | |
| segment | 段 | |
| frame | 帧（物理页框） | 物理内存中的页 |
| paging | 分页 | |
| page | 页 | |
| page table | 页表 | |
| page table entry (PTE) | 页表项 (PTE) | |
| page frame number (PFN) | 物理帧号 (PFN) | |
| valid bit / present bit | 有效位 / 存在位 | |
| protection bit | 保护位 | |
| reference bit | 引用位 | |
| dirty bit | 脏位 | |
| Translation Lookaside Buffer (TLB) | 快表 (TLB) | 保留 TLB 更常见 |
| TLB miss / TLB hit | TLB 缺失 / TLB 命中 | |
| multi-level page table | 多级页表 | |
| inverted page table | 反向页表 | |
| page fault | 缺页 | |
| page replacement | 页替换 | |
| swap space | 交换空间 | |
| swap | 交换 | |
| demand paging | 按需分页 | |
| thrashing | 抖动 | |
| working set | 工作集 | |
| Least Recently Used (LRU) | 最近最少使用 (LRU) | |
| optimal replacement | 最优替换 | |
| memory trace | 内存访问序列 | "track" 亦作"轨迹"，统一为"内存访问序列" |
| malloc() / free() | malloc() / free() | 标识符不译 |
| copy-on-write | 写时复制 | |
| Address Space Layout Randomization (ASLR) | 地址空间布局随机化 (ASLR) | |
| physical memory | 物理内存 | |
| virtual address space | 虚拟地址空间 | 亦可简称地址空间 |

## 持久化 / I/O

| English | 中文 | 说明 |
|---|---|---|
| input/output (I/O) device | 输入/输出 (I/O) 设备 | |
| solid-state drive (SSD) | 固态硬盘 (SSD) | |
| file system | 文件系统 | |
| journaling | 日志 | 文件系统崩溃一致性技术 |
| device driver | 设备驱动程序 | |
| redirection | 重定向 | shell 输入/输出重定向 |
| pipe | 管道 | 进程间通信机制 |

## 交叉引用约定

* 章节引用：`第 4 章`、`第 4.2 节`
* 图：`图 4.1`；表：`表 4.1`；代码：`代码 4.1`
* 作业：`作业（模拟器）`、`作业（代码）`、`作业（测量）`
