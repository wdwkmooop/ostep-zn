# 术语对照表 (Glossary)

> **动手翻译前先查此表。** 表中没有的术语：定下译名后**追加到本表**，再统一使用。
> 术语首现写 `中文(english)`，标识符永不翻译。

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
| crux | 问题核心 | 原书用于突出核心问题的特色框 |
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
| multi-threaded application | 多线程应用程序 | |
| thread control block (TCB) | 线程控制块 (TCB) | |
| thread-local storage | 线程局部存储 | 本书 ch26 语境下主要指各线程自己的栈 |
| parallelism / parallelization | 并行 / 并行化 | 与并发区分 |
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

## 并发 / 同步

| English | 中文 | 说明 |
|---|---|---|
| critical section | 临界区 | 访问共享资源且不能由多线程同时执行的代码 |
| race condition / data race | 竞争条件 / 数据竞争 | 后者特指共享数据上的竞争 |
| mutual exclusion | 互斥 | 同时只允许一条线程进入临界区 |
| synchronization primitive | 同步原语 | |
| atomic operation | 原子操作 | 全有或全无，不暴露中间状态 |
| transaction | 事务 | 一组被视作原子整体的操作 |
| mutex | 互斥量 | POSIX 锁类型 |
| fairness | 公平性 | 评价锁的标准之一 |
| spin-waiting / spin lock | 自旋等待 / 自旋锁 | |
| test-and-set | 测试并设置 | 亦称 atomic exchange（原子交换） |
| compare-and-swap (CAS) | 比较并交换 (CAS) | x86 亦称 compare-and-exchange |
| load-linked / store-conditional (LL/SC) | 链接式加载 / 条件式存储 (LL/SC) | |
| fetch-and-add | 取并加 | 原子递增并返回旧值 |
| ticket lock | 票号锁 | 按取号次序获取锁 |
| yield | 主动让出 | `yield()` 标识符保留英文 |
| park / unpark | 睡眠 / 唤醒 | API 名 `park()` / `unpark()` 保留英文 |
| wakeup/waiting race | 唤醒/等待竞争 | |
| priority inversion | 优先级反转 | |
| priority inheritance | 优先级继承 | |
| futex | futex | Linux 快速用户空间互斥机制，保留英文 |
| two-phase lock | 两阶段锁 | 先自旋，失败后睡眠 |
| spurious wakeup | 虚假唤醒 | 条件变量等待可能在条件未满足时返回 |
| deadlock | 死锁 | |
| thread-safe | 线程安全 | |
| condition variable | 条件变量 | |
| monitor | 管程 | 锁与条件变量组成的同步结构 |
| Mesa semantics | Mesa 语义 | 发信号只把等待者变为就绪；醒来后须重新检查条件 |
| Hoare semantics | Hoare 语义 | 发信号后立即把执行权交给被唤醒线程 |
| covering condition | 覆盖条件 | 用更宽泛的唤醒条件覆盖多个具体等待条件 |
| perfect scaling | 完美扩展 | 工作量随处理器数增长而完成时间不增 |
| approximate counter | 近似计数器 | 以一定精度换取可扩展性 |
| hand-over-hand locking / lock coupling | 逐手加锁 / 锁耦合 | 遍历结构时逐节点交接锁 |
| semaphore | 信号量 | 由整数值及 `wait`/`post` 操作组成 |
| binary semaphore | 二值信号量 | 可用作锁 |
| producer/consumer problem | 生产者—消费者问题 | 亦称有界缓冲区问题 |
| bounded buffer | 有界缓冲区 | |
| reader-writer lock | 读写锁 | 允许多个读者或一个写者 |
| dining philosophers problem | 哲学家就餐问题 | 经典同步问题 |
| atomicity violation | 原子性违反 | 本应原子执行的访问序列被打断 |
| order violation | 顺序违反 | 所需的跨线程执行顺序未被保证 |
| hold-and-wait | 持有并等待 | 死锁的必要条件之一 |
| no preemption | 不可抢占 | 死锁的必要条件之一 |
| circular wait | 循环等待 | 死锁的必要条件之一 |
| livelock | 活锁 | 线程持续活动却没有实质进展 |
| lock-free / wait-free | 无锁 / 无等待 | 不依赖显式锁的并发方法 |
| deadlock prevention / avoidance | 死锁预防 / 死锁避免 | 前者破坏必要条件，后者安排安全执行 |
| event-based concurrency | 基于事件的并发 | |
| event loop | 事件循环 | |
| event handler | 事件处理程序 | |
| blocking / non-blocking | 阻塞 / 非阻塞 | 描述调用是否等待工作完成后才返回 |
| synchronous / asynchronous | 同步 / 异步 | 本章用于 I/O 接口 |
| asynchronous I/O (AIO) | 异步 I/O (AIO) | |
| polling / interrupt | 轮询 / 中断 | 检查事件完成状态的两类方法 |
| signal / signal handler | 信号 / 信号处理程序 | UNIX 进程通知机制 |
| manual stack management | 手工栈管理 | 事件程序显式保存跨事件状态 |
| continuation | 续体 | 保存恢复计算所需状态的程序结构 |

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
| I/O device | I/O 设备 | 输入/输出设备 |
| bus / interconnect | 总线 / 互连 | 连接系统部件的数据通路 |
| peripheral bus | 外设总线 | 连接低速设备的总线 |
| hardware interface | 硬件接口 | 设备呈现给系统软件的接口 |
| device register | 设备寄存器 | 包括状态、命令和数据寄存器 |
| polling | 轮询 | 反复读取设备状态 |
| programmed I/O (PIO) | 程序控制 I/O (PIO) | 由 CPU 搬运设备数据 |
| interrupt service routine (ISR) | 中断服务程序 (ISR) | 亦称中断处理程序 |
| interrupt coalescing | 中断合并 | 将多次完成通知合并为一次中断 |
| Direct Memory Access (DMA) | 直接内存访问 (DMA) | 由 DMA 引擎在设备和内存间搬运数据 |
| memory-mapped I/O | 内存映射 I/O | 把设备寄存器映射到地址空间 |
| device driver | 设备驱动程序 | 封装具体设备操作细节 |
| generic block layer | 通用块层 | 向文件系统提供统一块接口 |
| raw interface | 裸接口 | 绕过文件抽象直接访问设备块 |
| firmware | 固件 | 运行在硬件设备内部的软件 |
| logical block address (LBA) | 逻辑块地址 (LBA) | 磁盘块的线性地址 |
| hard disk drive | 硬盘驱动器 | 简称硬盘 |
| sector / block | 扇区 / 块 | 本书磁盘语境中有时混用 |
| platter / surface | 盘片 / 盘面 | 盘片每一面称为盘面 |
| spindle | 主轴 | 带动盘片旋转 |
| track | 磁道 | 盘面上的同心圆数据区域 |
| disk head / disk arm | 磁头 / 磁臂 | 定位并读写盘面 |
| rotational delay | 旋转延迟 | 等待目标扇区转到磁头下方 |
| seek / seek time | 寻道 / 寻道时间 | 移动磁头到目标磁道 |
| transfer | 传输 | 从盘面实际读写数据 |
| track skew | 磁道偏斜 | 相邻磁道的扇区编号错开 |
| multi-zoned disk drive | 多区域磁盘驱动器 | 外圈区域每磁道可容纳更多扇区 |
| track buffer | 磁道缓冲区 | 硬盘内部缓存的旧称 |
| write-back / write-through | 回写 / 直写 | 两种写缓存完成语义 |
| disk scheduler | 磁盘调度器 | 决定 I/O 请求服务顺序 |
| shortest-seek-time-first (SSTF) | 最短寻道时间优先 (SSTF) | 优先选择最近磁道 |
| nearest-block-first (NBF) | 最近块优先 (NBF) | 以块地址近似 SSTF |
| SCAN / C-SCAN | 扫描 / 循环扫描 | 又称电梯算法及其变体 |
| shortest-positioning-time-first (SPTF) | 最短定位时间优先 (SPTF) | 同时考虑寻道与旋转 |
| I/O merging | I/O 合并 | 将相邻块请求合成较大请求 |
| work-conserving | 工作保守的 | 有待处理请求时不让设备空闲 |
| anticipatory scheduling | 预期调度 | 短暂等待可能到来的更优请求 |
| Redundant Array of Inexpensive Disks (RAID) | 廉价冗余磁盘阵列 (RAID) | 多盘组成的透明存储系统 |
| fail-stop fault model | 故障停止模型 | 设备只处于正常或永久失效两种状态 |
| latent sector error | 潜在扇区错误 | 工作磁盘上的单块不可访问故障 |
| striping / stripe | 条带化 / 条带 | 把连续数据分散到多块磁盘 |
| chunk | 分块 | 条带化中连续放在同一磁盘的数据单元 |
| mirroring | 镜像 | 在不同磁盘保存数据副本 |
| consistent-update problem | 一致更新问题 | 多盘更新被崩溃打断后副本不一致 |
| write-ahead log | 预写日志 | 修改前先记录待执行操作 |
| parity | 奇偶校验 | RAID 中用于恢复丢失数据的冗余信息 |
| exclusive OR (XOR) | 异或 (XOR) | 计算与重建奇偶校验的按位运算 |
| full-stripe write | 全条带写入 | 一次写入整条带并重算校验块 |
| small-write problem | 小写入问题 | 奇偶校验 RAID 的随机小写瓶颈 |
| hot spare | 热备盘 | 故障后可立即接替的备用磁盘 |
| persistent storage | 持久化存储 | 断电后仍保存数据的设备或抽象 |
| inode / inode number | inode / inode 号 | 保存文件元数据的索引节点及其底层编号 |
| directory hierarchy / directory tree | 目录层次结构 / 目录树 | 从根目录开始组织文件和目录 |
| open file table | 打开文件表 | 系统级结构，记录底层文件、偏移和访问模式 |
| current offset | 当前偏移 | 下一次文件读写开始的位置 |
| hard link / symbolic link | 硬链接 / 符号链接 | 指向同一 inode / 保存目标路径的两类链接 |
| dangling reference | 悬空引用 | 指向已不存在目标的引用 |
| permission bits | 权限位 | UNIX 所有者、组、其他用户的 rwx 控制位 |
| access control list (ACL) | 访问控制列表 (ACL) | 逐用户或组描述访问权的精细机制 |
| mount point | 挂载点 | 新文件系统接入统一目录树的位置 |
| inode table | inode 表 | 磁盘上的 inode 数组区域 |
| inode bitmap / data bitmap | inode 位图 / 数据位图 | 跟踪 inode 或数据块是否已分配 |
| superblock | 超级块 | 保存文件系统整体布局和参数的元数据块 |
| direct / indirect pointer | 直接指针 / 间接指针 | 直接指向数据块 / 指向更多块指针的 inode 字段 |
| multi-level index | 多级索引 | 用多级间接指针支持大文件的组织方式 |
| extent | 区段 | 由起始磁盘地址和连续块长度描述的数据区域 |
| free-space management | 空闲空间管理 | 跟踪并分配未使用 inode 与数据块 |
| page cache | 页缓存 | 统一缓存虚拟内存页和文件系统页的内存区域 |
| write buffering | 写缓冲 | 延迟、合并或调度持久化写入 |
| cylinder group / block group | 柱面组 / 块组 | FFS 用于聚集相关 inode 和数据的磁盘区域 |
| internal fragmentation | 内部碎片 | 已分配块内部未使用的空间 |
| pre-allocation | 预分配 | 提前保留一段空间以改善连续布局 |
| amortization | 摊销 | 以一次固定开销承载更多工作，降低平均成本 |
| crash consistency | 崩溃一致性 | 崩溃或断电后保持可恢复、合理的磁盘状态 |
| file system checker (fsck) | 文件系统检查器 (fsck) | 扫描并修复文件系统元数据不一致的工具 |
| checkpointing | 检查点 | 把日志中的已提交更新写到最终位置 |
| physical / logical logging | 物理日志 / 逻辑日志 | 记录块内容 / 记录高层操作的两种日志形式 |
| redo logging | 重做日志 | 恢复时重放已提交事务的日志方案 |
| ordered / metadata journaling | 有序日志 / 元数据日志 | 先写用户数据、只在日志中记录元数据 |
| write barrier | 写屏障 | 保证屏障前写入先于屏障后写入持久化 |
| circular log | 循环日志 | 检查点完成后可重复使用空间的有限日志 |
| revoke record | 撤销记录 | 阻止恢复过程重放已失效块更新的日志记录 |
| Soft Updates | Soft Updates | 通过精确安排写入顺序保持磁盘一致性 |
| backpointer-based consistency (BBC) | 基于反向指针的一致性 (BBC) | 用块的反向引用检测一致性 |
| optimistic crash consistency | 乐观崩溃一致性 | 减少同步等待并在事后检测不一致的协议 |
| log-structured file system (LFS) | 日志结构文件系统 (LFS) | 把更新聚合后顺序写入新位置的文件系统 |
| segment summary block | 段摘要块 | 记录 LFS 段中各块所属 inode 与偏移 |
| inode map (imap) | inode 映射 (imap) | 把 inode 号映射到最新磁盘地址 |
| checkpoint region (CR) | 检查点区域 (CR) | 保存最新 imap 片段位置的固定区域 |
| recursive update problem | 递归更新问题 | 移动对象导致上层引用一路连锁更新的问题 |
| roll forward | 前滚 | 从最近检查点扫描日志并重放后续有效更新 |
| shadow paging | 影子分页 | 把更新写到新位置后切换根指针的方案 |
| single-/multi-/triple-level cell (SLC/MLC/TLC) | 单层/多层/三层单元 (SLC/MLC/TLC) | 每闪存单元分别保存 1/2/3 位 |
| flash translation layer (FTL) | 闪存转换层 (FTL) | 把逻辑块接口转换为闪存物理操作 |
| program / erase cycle (P/E cycle) | 编程/擦除循环 (P/E 循环) | 衡量闪存块磨损的操作周期 |
| write amplification | 写放大 | 内部闪存写入量与客户端写入量之比 |
| wear leveling | 磨损均衡 | 把擦写负载分散到全部闪存块 |
| read / program disturb | 读干扰 / 编程干扰 | 访问一页导致邻页位翻转的故障 |
| out-of-band area (OOB) | 带外区域 (OOB) | 闪存页中保存映射或纠错信息的额外空间 |
| garbage collection (GC) | 垃圾回收 (GC) | 搬走活页并擦除含死亡页的闪存块 |
| TRIM | TRIM | 通知设备逻辑块已不再需要的命令 |
| overprovisioning | 超额配置 | SSD 内部提供多于对外容量的闪存空间 |
| hybrid mapping | 混合映射 | 日志块用页映射、数据块用块映射的 FTL |
| data integrity / data protection | 数据完整性 / 数据保护 | 确保存取内容一致并可检测损坏 |
| fail-partial disk model | 部分故障磁盘模型 | 磁盘整体可用但个别块失败或损坏 |
| checksum / collision | 校验和 / 碰撞 | 数据摘要及不同数据产生同一摘要的情况 |
| cyclic redundancy check (CRC) | 循环冗余校验 (CRC) | 基于多项式除法余数的校验技术 |
| misdirected write | 误定向写入 | 数据被正确写入错误物理位置 |
| lost write | 丢失写入 | 设备报告完成但写入未持久化 |
| disk scrubbing | 磁盘巡检 | 周期性读取并验证全部数据块 |
| distributed system | 分布式系统 | 由多台联网机器协作提供服务的系统 |
| unreliable / reliable communication | 不可靠 / 可靠通信 | 可能丢包的消息层 / 对上层隐藏丢失与重复的通信层 |
| acknowledgment (ack) | 确认 (ack) | 接收方向发送方报告消息已收到的短消息 |
| timeout / retry | 超时 / 重试 | 等待超过期限后重新发送请求的故障处理机制 |
| sequence counter | 序列计数器 | 用递增编号识别消息与过滤重复项的机制 |
| exponential back-off | 指数退避 | 连续失败后成倍延长重试等待时间的策略 |
| distributed shared memory (DSM) | 分布式共享内存 (DSM) | 让不同机器进程共享虚拟地址空间的抽象 |
| remote procedure call (RPC) | 远程过程调用 (RPC) | 把远程执行包装成类似本地函数调用的通信抽象 |
| stub / stub generator | 存根 / 存根生成器 | RPC 中代理远程调用的代码及其生成工具 |
| marshaling / unmarshaling | 编组 / 解组 | 把参数序列化进消息 / 从消息恢复参数 |
| end-to-end argument | 端到端原则 | 某些正确性保证最终必须由通信端点验证的设计原则 |
| stateless / stateful protocol | 无状态 / 有状态协议 | 服务器无需 / 需要保存跨请求客户端状态的协议 |
| file handle | 文件句柄 | 跨网络唯一标识文件或目录的协议对象 |
| generation number | 世代号 | 对重用标识符进行版本区分的递增编号 |
| idempotent operation | 幂等操作 | 执行多次与执行一次效果相同的操作 |
| cache consistency | 缓存一致性 | 多份客户端缓存与服务器内容保持合理一致的规则 |
| update visibility / stale cache | 更新可见性 / 陈旧缓存 | 更新何时可被他端看见 / 客户端仍持有旧副本的问题 |
| flush-on-close / close-to-open consistency | 关闭时刷新 / 关闭到打开一致性 | 关闭时写回，使其他客户端随后打开可见更新的语义 |
| attribute cache | 属性缓存 | 暂存文件元数据以减少远程有效性检查的缓存 |
| stable storage | 稳定存储 | 承诺成功后即使崩溃也不会丢失数据的持久介质抽象 |
| whole-file caching | 整文件缓存 | 以完整文件而不是数据块为缓存单位的策略 |
| callback | 回调 | 服务器承诺在缓存对象变化时主动通知客户端的机制 |
| file identifier (FID) | 文件标识符 (FID) | AFS 中由卷、文件 ID 和唯一化值组成的对象标识 |
| last writer / closer wins | 最后写者 / 关闭者胜 | 并发版本冲突时保留最后提交完整版本的规则 |
| heartbeat | 心跳 | 节点周期性发送、用于探测对端存活状态的消息 |
| global namespace | 全局命名空间 | 在所有客户端上保持一致路径名称的命名体系 |
| virtual machine monitor (VMM) / hypervisor | 虚拟机监控器 (VMM) / 管理程序 | 位于操作系统与硬件之间、复用并虚拟化整台机器的软件层 |
| transparency | 透明性 | 让上层无需感知底层实现或虚拟化存在的性质 |
| machine switch | 机器切换 | VMM 在虚拟机之间保存并恢复完整机器状态的切换 |
| supervisor mode | 监督者模式 | 权限介于用户模式与内核模式之间的处理器模式 |
| machine memory | 机器内存 | VMM 所见的真实物理内存，区别于客户 OS 所见的“物理内存” |
| shadow page table | 影子页表 | VMM 维护、直接把客户虚拟地址映射到机器页框的页表 |
| information gap | 信息鸿沟 | VMM 与客户 OS 等分层组件之间缺乏语义信息的问题 |
| inference / implicit information | 推断 / 隐式信息 | 不增加显式接口而从可观察行为推知另一层状态的方法 |
| para-virtualization | 半虚拟化 | 修改客户 OS 以配合 VMM、降低虚拟化开销的方案 |
| monitor lock | 管程锁 | 保证任意时刻只有一个线程活跃于管程内的隐式锁 |
| hint | 提示 | 通常正确但允许失效、使用者必须重新验证的信息 |
| broadcast | 广播 | 唤醒等待某条件的全部线程的条件变量操作 |
| thundering herd | 惊群 | 大量线程被同时唤醒却只有少数能继续、导致额外切换的现象 |
| systems programming | 系统编程 | 直接使用操作系统接口、运行时与底层资源进行的软件开发 |
| compiler driver | 编译器驱动程序 | 协调预处理、编译、汇编和链接各阶段的前端工具 |
| static / dynamic linking | 静态 / 动态链接 | 把库代码写入可执行文件 / 在装载运行时解析共享库的链接方式 |
| object file | 目标文件 | 已编译为机器级表示、尚未链接成可执行程序的文件 |
| target / prerequisite | 目标 / 前置条件 | Makefile 中要生成的对象 / 生成它所依赖的输入 |
| core file | core 文件 | 进程异常退出时保存内存与执行状态、供调试器检查的转储文件 |
| extent-based file system | 基于区段的文件系统 | 用起始块与长度对描述连续文件数据的文件系统 |

## 交叉引用约定

* 章节引用：`第 4 章`、`第 4.2 节`
* 图：`图 4.1`；表：`表 4.1`；代码：`代码 4.1`
* 作业：`作业（模拟器）`、`作业（代码）`、`作业（测量）`
