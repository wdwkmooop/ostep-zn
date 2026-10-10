# 第 33 章 基于事件的并发（高级）

> 英文原题：*Event-based Concurrency (Advanced)*

到目前为止，我们一直把线程写得仿佛是构建并发应用的唯一办法。人生中很多事都这样——听起来像真的，其实没那么绝对。GUI 应用 [O96] 和某些互联网服务器 [PDZ99] 经常使用另一种并发编程风格，叫作**基于事件的并发(event-based concurrency)**。它在 Node.js [N13] 等现代服务端框架里颇受欢迎，不过其根源还是下面要讨论的 C/UNIX 系统。

它要解决两个问题。第一，正确管理多线程应用的并发很难：漏锁、死锁及各种糟心问题都可能出现。第二，多线程程序的开发者几乎无法控制某一时刻究竟调度什么，只能创建线程，然后祈祷操作系统在可用 CPU 上安排得够合理。通用调度器不可能对所有负载都做到完美，有时操作系统的选择并非最优。

!!! danger "问题核心：怎样不用线程构建并发服务器"
    怎样构建不用线程的并发服务器，从而保留对并发的控制，同时避开困扰多线程应用的一些问题？

## 33.1 基本思想：事件循环

基于事件的并发非常简单：等待某件事——也就是一个**事件(event)**——发生；事件来了，就判断其类型并完成它要求的一小段工作，例如发出 I/O 请求，或安排以后要处理的其他事件。就这些。

典型的事件服务器围绕一个简单结构展开，称为**事件循环(event loop)**：

```c
while (1) {
    events = getEvents();
    for (e in events)
        processEvent(e);
}
```

主循环调用 `getEvents()` 等待任务，再逐个处理返回的事件。处理事件的代码叫作**事件处理程序(event handler)**。关键在于：处理程序工作时，系统里没有其他活动；因此选择下一个事件，就等同于调度。对调度拥有显式控制，是事件模型最根本的优势之一。

但问题也随之而来：事件服务器怎样知道发生了哪些事件，尤其是网络和磁盘 I/O？服务器怎么知道消息已经抵达？

## 33.2 重要 API：`select()`（或 `poll()`）

大多数系统通过 `select()` 或 `poll()` 系统调用提供接收事件的基本 API。它们让程序检查是否有需要处理的入站 I/O。例如 Web 服务器可以检查网络分组是否抵达。

以 macOS 手册中的 `select()` 为例：

```c
int select(int nfds,
           fd_set *restrict readfds,
           fd_set *restrict writefds,
           fd_set *restrict errorfds,
           struct timeval *restrict timeout);
```

`select()` 检查 `readfds`、`writefds` 和 `errorfds` 指向的 I/O 描述符集合，判断描述符是否可读、可写或存在异常情况。每个集合会检查编号 0 到 `nfds-1` 的描述符。返回时，传入的集合被替换成满足对应条件的描述符子集；返回值则是所有集合中就绪描述符的总数。

它既能检查可读，也能检查可写。前者告诉服务器新数据已经抵达，后者告诉服务器现在可以回复——例如出站队列没有塞满。

`timeout` 参数也值得留意。把它设为 `NULL`，`select()` 会无限阻塞，直到某个描述符就绪。更健壮的服务器往往指定超时；一种常见做法是设为 0，让调用立即返回。`poll()` 与它非常相似，详情可查手册或 Stevens 与 Rago 的著作 [SR05]。

这些原语足以构造非阻塞事件循环：检查入站分组，从有消息的套接字读取，并按需回复。

!!! note "边栏：阻塞接口与非阻塞接口"
    **阻塞(blocking)** 或**同步(synchronous)** 接口完成全部工作后才返回；**非阻塞(non-blocking)** 或**异步(asynchronous)** 接口启动工作后立即返回，让实际工作在后台完成。

    I/O 通常是阻塞的罪魁祸首。若调用必须从磁盘读取才能完成，它就可能等待发给磁盘的请求返回。

    非阻塞接口可以用于任何编程风格，包括线程；但它对事件模型不可或缺，因为一个阻塞调用会让所有进展停摆。

## 33.3 使用 `select()`

下面用 `select()` 判断哪些网络描述符收到了消息：

```c linenums="1"
#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

int main(void) {
    // 打开并设置一批套接字（未展示）
    // 主循环
    while (1) {
        // 把 fd_set 初始化为全 0
        fd_set readFDs;
        FD_ZERO(&readFDs);

        // 为服务器关心的描述符设置相应位
        // （为简单起见，使用从最小值到最大值的所有描述符）
        int fd;
        for (fd = minFD; fd < maxFD; fd++)
            FD_SET(fd, &readFDs);

        // 执行 select
        int rc = select(maxFD + 1, &readFDs, NULL, NULL, NULL);

        // 用 FD_ISSET() 检查哪些描述符确实有数据
        int fd;
        for (fd = minFD; fd < maxFD; fd++)
            if (FD_ISSET(fd, &readFDs))
                processFD(fd);
    }
}
```

*图 33.1：使用 `select()` 的简单代码。*

初始化后，服务器进入无限循环。它先用 `FD_ZERO()` 清空文件描述符集合，再用 `FD_SET()` 把 `minFD` 到 `maxFD` 之间的描述符加入集合。这些描述符可以代表服务器关注的全部网络套接字。随后调用 `select()` 查看哪些连接上有数据，再循环调用 `FD_ISSET()` 找出就绪描述符并处理入站数据。

真正的服务器当然会复杂得多：发送消息、发出磁盘 I/O 等都要有相应逻辑。API 细节见 [SR05]，事件服务器的整体流程可参考 [PDZ99, WCB01]。

## 33.4 为什么更简单？因为不需要锁

在单 CPU 的事件应用里，一次只处理一个事件。事件服务器是彻底的单线程，事件处理程序不会被另一条线程打断，因此无需获取或释放锁。线程程序常见的并发 bug 不会出现在最基本的事件模型中。

## 33.5 一个问题：阻塞系统调用

到这里，事件编程听起来很美：写个循环，事件来了就处理，连锁都不用想。可若某个事件必须发出可能阻塞的系统调用呢？

假设客户端请求服务器读取磁盘文件并返回内容，就像简单的 HTTP 请求。事件处理程序最终要调用 `open()` 打开文件，再调用一系列 `read()` 读取。文件进入内存后，服务器才开始把结果发给客户端。

所需元数据或数据不在内存时，`open()` 和 `read()` 都可能向存储系统发出 I/O 请求，耗时很久。在线程服务器中这不是问题：发出 I/O 的线程挂起时，其他线程仍可运行。I/O 与计算自然重叠，正是线程编程显得顺手的原因。

事件模型却没有其他线程可运行，只有主事件循环。一个事件处理程序阻塞，整个服务器就跟着阻塞，系统只能闲着，资源浪费巨大。因此事件系统必须遵守一条铁律：**不允许阻塞调用**。

!!! tip "提示：不要在事件服务器中阻塞"
    事件服务器让你细粒度控制任务调度，但要保住这种控制，就绝不能调用会阻塞调用者的例程。违背这条规矩，得到的会是卡死的服务器、抓狂的客户端，以及别人对你究竟有没有读过本章的严肃怀疑。

## 33.6 一种解法：异步 I/O

为突破这个限制，许多现代操作系统提供了发出磁盘 I/O 的新接口，统称**异步 I/O(asynchronous I/O, AIO)**。应用发出请求后会在 I/O 完成前立刻拿回控制权，另有接口用来判断各个 I/O 是否已经结束。

以 macOS 为例，API 围绕 AIO 控制块 `struct aiocb` 展开。简化结构如下：

```c
struct aiocb {
    int           aio_fildes; // 文件描述符
    off_t         aio_offset; // 文件偏移
    volatile void *aio_buf;   // 缓冲区位置
    size_t        aio_nbytes; // 传输长度
};
```

发起异步读取前，应用填写文件描述符 `aio_fildes`、文件偏移 `aio_offset`、请求长度 `aio_nbytes`，以及接收结果的内存地址 `aio_buf`。随后调用：

```c
int aio_read(struct aiocb *aiocbp);
```

若成功发出 I/O，该调用立即返回，事件服务器可以继续工作。要判断缓冲区里是否已有请求的数据，还需要：

```c
int aio_error(const struct aiocb *aiocbp);
```

它检查 `aiocbp` 指代的请求是否完成。完成时返回 0；尚未完成时返回 `EINPROGRESS`。应用可以周期性调用它，**轮询(polling)** 每项未完成的异步 I/O。

但如果同时有几十乃至几百个 I/O，反复逐项检查显然很折腾。某些系统因而提供基于**中断(interrupt)** 的方案：异步 I/O 完成时用 UNIX 信号通知应用，无需不停追问。设备管理中也会遇到同样的“轮询还是中断”问题。

!!! note "边栏：UNIX 信号"
    所有现代 UNIX 变体都有一套庞大而有趣的**信号(signal)** 机制。最简单地说，信号是与进程通信的方式。信号送达应用时，会暂停它当前的工作，转去执行**信号处理程序(signal handler)**；处理完毕后，进程恢复先前的行为。

    每种信号都有名字，例如 HUP（挂断）、INT（中断）、SEGV（段违规）。有时内核自己发信号：程序发生段违规时，操作系统发送 `SIGSEGV`。程序若配置为捕获它，就能执行响应代码，这对调试很有用；没有配置处理程序时则采取默认行为，对 SEGV 而言就是终止进程。

    下面的程序先安装 `SIGHUP` 处理程序，再进入无限循环：

    ```c
    #include <stdio.h>
    #include <signal.h>

    void handle(int arg) {
        printf("stop wakin’ me up...\n");
    }

    int main(int argc, char *argv[]) {
        signal(SIGHUP, handle);
        while (1)
            ; // 除了捕获几个信号，啥也不干
        return 0;
    }
    ```

    可以用命令行工具 `kill` 给它发送信号——没错，这名字听起来又怪又凶：

    ```console
    prompt> ./main &
    [3] 36705
    prompt> kill -HUP 36705
    stop wakin’ me up...
    prompt> kill -HUP 36705
    stop wakin’ me up...
    prompt> kill -HUP 36705
    stop wakin’ me up...
    ```

    信号这套东西多到一章也讲不完。想继续深挖，仍可看经典资料 [SR05]。

没有异步 I/O 的系统无法实现纯粹的事件模型。不过研究人员找到了效果不错的替代办法。例如 Pai 等人 [PDZ99] 提出混合方案：用事件处理网络分组，用线程池管理尚未完成的 I/O。

## 33.7 另一个问题：状态管理

事件代码通常比传统线程代码更难写。当事件处理程序发出异步 I/O 时，必须把部分程序状态打包保存，供 I/O 最终完成时的下一个处理程序使用。线程程序不需要这项额外工作，因为所需状态就在线程栈上。Adya 等人把它称为**手工栈管理(manual stack management)** [A+02]。

例如线程服务器从文件描述符 `fd` 读取，完成后把数据写入网络套接字描述符 `sd`：

```c
int rc = read(fd, buffer, size);
rc = write(sd, buffer, size);
```

在多线程程序里，`read()` 返回后，代码从线程栈中的变量 `sd` 便知道该写向哪个套接字。

事件系统没这么轻松。它先用 AIO 发起异步读取，再通过 `aio_error()` 检查完成状态；可读取完成时，新的事件处理程序怎么知道下一步该做什么？

解法是使用老牌编程语言结构——**续体(continuation)** [FHK84]。名字听着唬人，思想倒很简单：把完成事件所需的信息记录在某个数据结构中；事件发生时查回这些信息，再继续处理。

在这个例子里，可以把套接字描述符 `sd` 存入以文件描述符 `fd` 为键的哈希表。磁盘 I/O 完成后，事件处理程序用 `fd` 查找续体，取回 `sd`，终于可以把数据写进正确的套接字。

## 33.8 事件模型还有哪些难处

事件模型还有几道坎。

第一，从单 CPU 转向多 CPU 后，它不再那么简单。要利用多颗 CPU，服务器必须并行运行多个事件处理程序；临界区等老问题随即回归，锁等传统方案也得重新请回来。现代多核系统上，完全无锁的简单事件处理已不可能。

第二，它与分页等某些系统活动配合不佳。事件处理程序发生缺页时会阻塞，服务器只能等缺页完成。即使代码避开了显式阻塞，也很难避免这种隐式阻塞；缺页频繁时，性能会受到重创。

第三，随着例程语义变化，事件代码很难长期维护 [A+02]。若某个例程从非阻塞变成阻塞，调用它的事件处理程序也必须拆成两段。阻塞对事件服务器太致命，程序员必须时刻盯着每个 API 的语义变化。

最后，尽管大多数平台如今都支持异步磁盘 I/O，这条路走了很久 [PDZ99]；它与异步网络 I/O 的整合也没有想象中统一。理想状态是用 `select()` 管理所有未完成 I/O，现实却往往是网络用 `select()`，磁盘再配一套 AIO 调用。

## 33.9 小结

本章粗略介绍了基于事件的另一种并发风格。事件服务器把调度控制交给应用，却以代码复杂、难与分页等现代系统机制整合为代价。没有哪种方法一统天下；未来很多年里，线程与事件很可能继续作为解决同一并发问题的两条不同道路。

想继续学习，可以阅读 [A+02, PDZ99, vB+03, WCB01]，更好的办法则是亲手写些事件代码。

## 参考文献

- [A+02] “Cooperative Task Management Without Manual Stack Management” by Atul Adya, Jon Howell, Marvin Theimer, William J. Bolosky, and John R. Douceur. USENIX ATC '02, Monterey, June 2002. 这篇宝藏论文首次清楚阐明了事件并发的若干难题，提出简单解法，还探索了在同一应用中混合两种并发管理方式这个更疯狂的主意。
- [FHK84] “Programming With Continuations” by Daniel P. Friedman, Christopher T. Haynes, and Eugene E. Kohlbecker. In *Program Transformation and Programming Environments*, Springer Verlag, 1984. 编程语言领域中续体这一老概念的经典资料；它在一些现代语言里越来越流行。
- [N13] “Node.js Documentation” by the folks who built Node.js. <https://nodejs.org/api/>. Node.js 是许多便于构建 Web 服务与应用的新框架之一。现代系统黑客应该精通至少一种，最好不止一种。
- [O96] “Why Threads Are A Bad Idea (for most purposes)” by John Ousterhout. Invited Talk at USENIX '96, San Diego, January 1996. 一场精彩演讲，讨论线程为何不适合 GUI 应用，其思想也更为普适。
- [PDZ99] “Flash: An Efficient and Portable Web Server” by Vivek S. Pai, Peter Druschel, and Willy Zwaenepoel. USENIX '99, Monterey, June 1999. 互联网蓬勃发展初期关于 Web 服务器结构的开创性论文，还讨论了缺少异步 I/O 支持时怎样构建混合方案。
- [SR05] *Advanced Programming in the UNIX Environment* by W. Richard Stevens and Stephen A. Rago. Addison-Wesley, 2005. UNIX 系统编程书架上不能缺席的经典。
- [vB+03] “Capriccio: Scalable Threads for Internet Services” by Rob von Behren et al. SOSP '03, Lake George, October 2003. 研究如何让线程扩展到极大规模，是对当时事件模型热潮的一种回应。
- [WCB01] “SEDA: An Architecture for Well-Conditioned, Scalable Internet Services” by Matt Welsh, David Culler, and Eric Brewer. SOSP '01, Banff, October 2001. 把线程、队列与事件处理整合成一体；部分思想后来进入 Google、Amazon 等公司的基础设施。

## 作业（代码）

这份短作业让你体验基于事件的代码及其核心概念。祝好运！

1. 编写能接受并服务 TCP 连接的简单服务器。若还不会，得上网翻翻资料。先让它一次只服务一个请求；请求内容可以很简单，例如取得当前时间。
2. 加入 `select()` 接口。主程序要能接受多个连接；事件循环检查哪些文件描述符有数据，再读取并处理请求。仔细测试，确认 `select()` 用得正确。
3. 让请求更像简单的 Web 或文件服务器：每个请求指定一个文件，服务器把文件读入缓冲区，再把内容返回客户端。使用标准系统调用 `open()`、`read()` 和 `close()`。小心点：若让它长时间运行，没准有人会琢磨出办法读光你电脑上的文件！
4. 改用本章介绍的异步 I/O 接口，而非标准 I/O 系统调用。把异步接口接入程序有多难？
5. 为代码加入信号处理。信号常用来戳一下服务器，让它重新加载配置文件或执行其他管理动作。可以给服务器加入存放最近访问文件的用户级缓存，再实现一个信号处理程序：服务器进程收到信号时清空缓存。
6. 最后是困难部分：怎样判断构建异步事件方案的努力是否值得？能否设计实验展示其优势？你的方案增加了多少实现复杂度？
