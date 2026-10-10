# 第 28 章 锁

> 英文原题：*Locks*

在并发导论中，我们看到了并发编程的一个根本问题：我们想让一串指令原子地执行，可单处理器上的中断，或多处理器上同时执行的多条线程，让这件事无法自然实现。本章直接迎战这个问题，引入一种叫作**锁(lock)** 的东西。程序员用锁标注源代码，把它围在临界区四周，使临界区表现得像一条原子指令。

## 28.1 锁的基本思想

假设临界区是共享变量最经典的更新操作：

```c
balance = balance + 1;
```

当然，临界区也可能往链表里添加元素，或对共享结构做更复杂的更新；眼下先守着这个简单例子。使用锁时，在临界区外加一点代码：

```c linenums="1"
lock_t mutex; // 某把全局分配的锁 mutex
...
lock(&mutex);
balance = balance + 1;
unlock(&mutex);
```

锁只是一个变量，因此必须先声明某种锁变量，比如这里的 `mutex`。锁变量（简称“锁”）保存锁在任一时刻的状态：要么**可用**（未加锁、空闲），没有线程持有；要么**已获取**（已加锁、被持有），恰好一条线程持有它，而且大概正待在临界区里。锁的数据类型还可以记录其他信息，例如持锁线程是谁，或用来安排获取次序的队列；不过这些对锁的用户隐藏起来了。

`lock()` 和 `unlock()` 的语义很简单。`lock()` 尝试获取锁；若锁空闲，调用线程就拿到锁并进入临界区，此时它有时叫作锁的**所有者(owner)**。若另一条线程对同一把锁调用 `lock()`，只要锁还在别人手里，调用就不会返回，于是其他线程无法在第一条线程持锁期间进入临界区。

所有者调用 `unlock()` 后，锁重新可用。若没有线程在等待，只需把锁状态改为空闲；若有线程卡在 `lock()` 里，其中一条最终会察觉（或收到通知）状态已改变，拿到锁并进入临界区。

锁把一小部分调度控制权交给了程序员。通常，线程由程序员创建，却由操作系统按自己的方式调度；在代码段外放一把锁，程序员就能保证同时至多一条线程在其中活动。锁就这样把传统操作系统调度的混沌，稍稍驯服成了可控的活动。

## 28.2 Pthread 锁

POSIX 库把锁叫作**互斥量(mutex)**，因为它在线程之间提供互斥：一条线程进入临界区后，其他线程要等它完成才能进入。所以下面的 POSIX 线程代码与上例做的是同一件事（我们仍使用会检查错误的包装函数）：

```c linenums="1"
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

Pthread_mutex_lock(&lock); // 包装函数；失败时退出
balance = balance + 1;
Pthread_mutex_unlock(&lock);
```

POSIX 版本把锁变量传给加锁和解锁例程，因为不同变量可以由不同锁保护。这能提高并发度：若所有临界区都共用一把大锁，就是**粗粒度锁定(coarse-grained locking)**；若不同数据和数据结构分别用不同锁保护，就是更细粒度的做法，能让更多线程同时处在受锁保护的代码中。

## 28.3 构建一把锁

站在程序员角度，你应该已经理解锁怎样工作了。可锁本身该怎么造？需要什么硬件支持？操作系统又要提供什么？本章余下部分就来回答这些问题。

!!! danger "问题核心：怎样构建一把锁"
    怎样构建高效的锁？高效锁应以很低的成本提供互斥，还可能满足下文讨论的其他性质。硬件需要提供什么？操作系统又需要提供什么？

要造出能用的锁，需要老朋友硬件帮忙，也少不了好搭档操作系统。多年来，各种计算机体系结构的指令集加入了许多不同的硬件原语。我们不研究这些指令如何实现——那是体系结构课的题目——而研究怎样用它们构建锁这样的互斥原语，以及操作系统如何补齐最后一块拼图，让复杂的锁库成为可能。

## 28.4 评价锁

造锁之前，先得弄清目标，也就是怎样评价某种锁实现是否有效。最基本的标准有三条。

第一是**正确性**：锁是否完成了互斥这个本职工作，阻止多条线程同时进入临界区？

第二是**公平性(fairness)**：锁空闲时，每条竞争线程是否都有公平机会拿到它？从更极端的角度说，会不会有线程一直争锁却始终拿不到，从而发生**饥饿(starvation)**？

第三是**性能**，尤其是锁增加的时间开销。这里有几种情况值得分别考察：没有竞争时，单条线程拿锁再放锁要多少开销？多条线程在单 CPU 上竞争时表现怎样？多 CPU 上各有线程争同一把锁又如何？比较这些场景，才能理解不同锁技术的性能影响。

## 28.5 控制中断

最早的互斥方案之一，是在临界区关闭中断；它为单处理器系统而生：

```c linenums="1"
void lock() {
    DisableInterrupts();
}
void unlock() {
    EnableInterrupts();
}
```

在单处理器上，进入临界区前用特殊硬件指令关闭中断，区内代码就不会被打断，仿佛原子执行。结束后重新启用中断，程序继续照常运行。

优点是简单，几乎不用挠头就能看出为什么有效。没有中断，线程就能确信自己的代码一路跑完，不受其他线程干扰。

可惜缺点一大堆。第一，任何调用线程都得获准执行开关中断这种特权操作，还得相信它不会滥用。只要需要信任任意程序，麻烦多半就来了。贪心程序可以一启动就调用 `lock()`，独占处理器；出错或恶意程序更可能拿锁后陷入死循环，让操作系统永远夺不回控制权，只剩重启一条路。把关闭中断当通用同步方案，对应用程序的信任实在过头。

第二，它在多处理器上无效。不同 CPU 上的线程可以同时进入同一临界区；关掉一个 CPU 的中断，也拦不住别的 CPU。如今多处理器随处可见，通用解法必须更高明。

第三，长时间关中断可能丢失中断，引发严重系统问题。想象 CPU 错过了磁盘读请求完成的通知，操作系统又怎么知道该唤醒等待读取的进程？

最后，也许是最不重要的一点：它可能效率不高。现代 CPU 执行屏蔽或解除屏蔽中断的代码，往往比普通指令慢。

因此，关闭中断只在有限场景中充当互斥原语。例如，操作系统有时会用中断屏蔽保证访问自身数据结构时的原子性，或至少避免棘手的中断处理局面。在操作系统内部，这么做说得通：信任问题消失了，操作系统本来就信任自己执行特权操作。

## 28.6 失败的尝试：只用加载和存储

要超越中断方案，必须依靠 CPU 硬件及其指令构建正经的锁。先试试用一个标志变量：

```c linenums="1"
typedef struct __lock_t { int flag; } lock_t;

void init(lock_t *mutex) {
    // 0 -> 锁可用，1 -> 锁被持有
    mutex->flag = 0;
}

void lock(lock_t *mutex) {
    while (mutex->flag == 1) // 测试标志
        ;                    // 自旋等待（什么也不做）
    mutex->flag = 1;         // 现在设置它！
}

void unlock(lock_t *mutex) {
    mutex->flag = 0;
}
```

*图 28.1：第一次尝试——简单标志。*

思路很直白：`flag` 表示有没有线程持锁。第一条进入临界区的线程调用 `lock()`，看到 `flag` 不是 1，便把它设为 1；完成后调用 `unlock()` 清零。若另一条线程在此期间调用 `lock()`，它就在 `while` 中**自旋等待(spin-waiting)**；等第一条线程清零，等待者退出循环，把 `flag` 设为 1，再进入临界区。

不幸的是，这段代码既不正确，性能也差。设 `flag` 初值为 0，下面的交错就会出事：

| 线程 1 | 线程 2 |
|---|---|
| 调用 `lock()`；检查 `while (flag == 1)` |  |
| **中断：切换到线程 2** |  |
|  | 调用 `lock()`；检查 `while (flag == 1)`；执行 `flag = 1` |
| **中断：切回线程 1** |  |
| 执行 `flag = 1`（也设成 1！） |  |

*图 28.2：没有互斥的执行轨迹。*

一次来得正巧（还是说糟巧？）的中断，就让两条线程都把标志设为 1，都能进入临界区。专业人士管这叫“坏事”——最基本的互斥要求都没满足。

性能问题在于等待方式：线程不停检查 `flag`，白白消耗时间，等别人放锁。单处理器上尤其浪费，因为等待者想等的那条线程根本无法运行——至少得等到下一次上下文切换。因此，继续寻找更复杂的方案时，也得设法避免这种浪费。

## 28.7 用测试并设置构建可用的自旋锁

关闭中断无法用于多处理器，普通加载/存储也造不出正确的锁，系统设计者于是开始为锁设计硬件支持。20 世纪 60 年代初的 Burroughs B5000 等早期多处理器就已经有这类支持 [M82]；今天，哪怕单 CPU 系统也都提供它。

最容易理解的硬件支持叫**测试并设置(test-and-set)**，也叫**原子交换(atomic exchange)**[^1]。下面的 C 伪代码说明它做什么：

[^1]: 不同体系结构名字不同：SPARC 叫无符号字节加载/存储指令 `ldstub`；x86 则是带锁版本的原子交换 `xchg`。

```c linenums="1"
int TestAndSet(int *old_ptr, int new) {
    int old = *old_ptr; // 取出 old_ptr 处的旧值
    *old_ptr = new;     // 把 new 存入 old_ptr
    return old;         // 返回旧值
}
```

它返回 `old_ptr` 指向的旧值，同时把那里更新为 `new`；关键在于整个序列原子执行。“测试并设置”这个名字，正是因为它让你在“测试”返回的旧值时，同时把内存位置“设置”为新值。多出这么一点点能力，就足以造出简单自旋锁：

```c linenums="1"
typedef struct __lock_t {
    int flag;
} lock_t;

void init(lock_t *lock) {
    // 0：锁可用，1：锁被持有
    lock->flag = 0;
}

void lock(lock_t *lock) {
    while (TestAndSet(&lock->flag, 1) == 1)
        ; // 自旋等待（什么也不做）
}

void unlock(lock_t *lock) {
    lock->flag = 0;
}
```

*图 28.3：用测试并设置实现的简单自旋锁。*

无人持锁时，`flag=0`。线程调用 `TestAndSet(&flag, 1)`，得到旧值 0，因此不会困在循环里；与此同时，操作原子地把 `flag` 设为 1，表示锁已被持有。临界区结束后，`unlock()` 再把它清零。

若锁已被别人持有，`flag=1`。调用 `TestAndSet()` 会返回 1，同时又把它设成 1。只要别人不放锁，它就不断返回 1，调用线程不断自旋。等某条线程终于把 `flag` 清为 0，下一次测试并设置便返回 0、原子地写入 1，于是等待者拿锁进入临界区。

把对旧值的测试和对新值的设置合成一个原子操作，就能保证只有一条线程拿到锁。这就是一个真正能用的互斥原语！它叫**自旋锁(spin lock)**，因为拿不到锁的线程只会原地自旋，消耗 CPU 周期，直到锁可用。它要在单处理器上正确工作，必须有抢占式调度器，定期用时钟中断打断线程、换另一条运行；没有抢占，独占单 CPU 自旋的线程永远不会把 CPU 交出去。

!!! note "边栏：Dekker 与 Peterson 算法"
    20 世纪 60 年代，Dijkstra 把并发问题抛给朋友们，其中数学家 Theodorus Jozef Dekker 给出了一种解法 [D68]。与本章依赖特殊硬件指令乃至操作系统支持的方案不同，Dekker 算法只用加载和存储——假定这些操作彼此原子，这在早期硬件上成立。

    Peterson 后来改进了它 [P81]。同样只用加载和存储，目标是保证两条线程永不同时进入临界区：

    ```c
    int flag[2];
    int turn;

    void init() {
        // 用 flag 表示你打算持锁
        flag[0] = flag[1] = 0;
        // 轮到谁？线程 0 还是 1？
        turn = 0;
    }
    void lock() {
        // self 是调用者的线程 ID
        flag[self] = 1;
        // 把机会让给另一条线程
        turn = 1 - self;
        while ((flag[1-self] == 1) && (turn == 1 - self))
            ; // 还没轮到自己时自旋等待
    }
    void unlock() {
        // 只需撤销自己的意图
        flag[self] = 0;
    }
    ```

    不靠特殊硬件造锁，一度莫名成了潮流，理论家们因此有了大把题目可做。后来人们发现，假定一点硬件支持容易多了——而且多处理器诞生之初就有这种支持。更何况，受宽松内存一致性模型影响，上述算法在现代硬件上并不能直接工作。又一批研究被扫进历史的垃圾桶……

!!! tip "提示：把并发想成一个恶意调度器"
    理解并发执行时，不妨假装自己是个恶意调度器：专挑最要命的时刻中断线程，挫败它们构造同步原语的可怜尝试。你可真坏！某串中断次序也许概率极低，但只要它**可能**发生，就足以证明一种做法不正确。有时，心眼坏一点很有用。

## 28.8 评价自旋锁

按前面的三项标准来看，基本自旋锁如何？

正确性方面，答案是肯定的：它每次只允许一条线程进入临界区，因此是一把正确的锁。

公平性方面却是坏消息：自旋锁没有任何公平保证。竞争激烈时，一条线程可能永远自旋。到目前为止讨论的简单自旋锁并不公平，可能导致饥饿。

性能方面要分场景。单 CPU 上开销可能惨不忍睹：若持锁线程在临界区里被抢占，调度器接下来也许把其余 $N-1$ 条线程逐个跑一遍；每条都争锁失败，白白自旋整整一个时间片才交出 CPU。

多 CPU 上，自旋锁表现还算不错——前提是线程数与 CPU 数大致相当。假设 CPU 1 上的线程 A 拿到锁，CPU 2 上的线程 B 开始自旋。临界区通常很短，锁很快就会释放并被 B 拿到；为等待另一个处理器上的短临界区而自旋，浪费的周期不多，因此可能很有效。

## 28.9 比较并交换

一些系统提供另一种硬件原语：**比较并交换(compare-and-swap)**（SPARC 的叫法），在 x86 上叫 **compare-and-exchange**。它的 C 伪代码如下：

```c linenums="1"
int CompareAndSwap(int *ptr, int expected, int new) {
    int actual = *ptr;
    if (actual == expected)
        *ptr = new;
    return actual;
}
```

*图 28.4：比较并交换。*

它检查 `ptr` 指向的值是否等于 `expected`；若相等，就把该位置更新为 `new`，否则不动。无论如何都返回内存中的实际旧值，让调用者知道操作是否成功。

用它造锁与测试并设置很相似，只需替换 `lock()`：

```c linenums="1"
void lock(lock_t *lock) {
    while (CompareAndSwap(&lock->flag, 0, 1) == 1)
        ; // 自旋
}
```

它检查标志是否为 0；若是，就原子地换入 1 并拿到锁。持锁期间，其他线程会自旋到锁释放为止。真正可从 C 调用的 x86 比较并交换实现可见配套代码 [S05][^2]。

[^2]: <https://github.com/remzi-arpacidusseau/ostep-code/tree/master/threads-locks>

比较并交换比测试并设置更强大，后面浅尝**无锁同步(lock-free synchronization)** [H91] 时会用到这种能力。不过若只拿它实现简单自旋锁，行为和上面分析的完全一样。

## 28.10 链接式加载与条件式存储

某些平台提供一对协同工作的指令来构建临界区。例如 MIPS [H93] 的**链接式加载(load-linked, LL)** 与**条件式存储(store-conditional, SC)**，可以联手构造锁和其他并发结构；Alpha、PowerPC 和 ARM 也有类似指令 [W09]。

```c linenums="1"
int LoadLinked(int *ptr) {
    return *ptr;
}

int StoreConditional(int *ptr, int value) {
    if (自从对此地址执行 LoadLinked 后，*ptr 未被更新) {
        *ptr = value;
        return 1; // 成功！
    } else {
        return 0; // 更新失败
    }
}
```

*图 28.5：链接式加载与条件式存储。*

LL 和普通加载一样，从内存取值放进寄存器。关键区别在 SC：只有从上次对同一地址执行 LL 以来，没有其他存储修改过该地址，它才成功。成功时，SC 把 `ptr` 更新为 `value` 并返回 1；失败时不更新，返回 0。

先自己想想怎样用 LL/SC 造锁，再看答案：

```c linenums="1"
void lock(lock_t *lock) {
    while (1) {
        while (LoadLinked(&lock->flag) == 1)
            ; // 自旋，直到它变成 0
        if (StoreConditional(&lock->flag, 1) == 1)
            return; // 成功设为 1：大功告成
                    // 否则从头再来
    }
}

void unlock(lock_t *lock) {
    lock->flag = 0;
}
```

*图 28.6：用 LL/SC 构建锁。*

`lock()` 先等待标志变成 0，再用 SC 尝试获取锁。若成功，标志就原子地变为 1，线程可以进入临界区。

SC 为什么会失败？线程 A 执行 LL，看到锁空闲、得到 0；还没来得及执行 SC 就被打断。线程 B 也进入代码，执行 LL 得到 0。此刻两条线程都完成了 LL，正要执行 SC。关键在于，只有一条能把标志更新为 1；后一条的 SC 会发现 LL 与 SC 之间标志已被别人改动，于是失败，只能重试。

几年前，本科生 David Capel 为爱玩布尔短路求值的人提出了更精炼的版本。看看你能否说明它为何等价：

```c linenums="1"
void lock(lock_t *lock) {
    while (LoadLinked(&lock->flag) ||
           !StoreConditional(&lock->flag, 1))
        ; // 自旋
}
```

## 28.11 取并加

最后一种硬件原语叫**取并加(fetch-and-add)**：原子地递增某个地址的值，同时返回旧值。

```c linenums="1"
int FetchAndAdd(int *ptr) {
    int old = *ptr;
    *ptr = old + 1;
    return old;
}
```

我们用它构建 Mellor-Crummey 和 Scott 提出的、更有意思的**票号锁(ticket lock)** [MS91]：

```c linenums="1"
typedef struct __lock_t {
    int ticket;
    int turn;
} lock_t;

void lock_init(lock_t *lock) {
    lock->ticket = 0;
    lock->turn   = 0;
}

void lock(lock_t *lock) {
    int myturn = FetchAndAdd(&lock->ticket);
    while (lock->turn != myturn)
        ; // 自旋
}

void unlock(lock_t *lock) {
    lock->turn = lock->turn + 1;
}
```

*图 28.7：票号锁。*

它不用单一值，而用 `ticket` 和 `turn` 配合。线程想拿锁时，先对 `ticket` 原子取并加，把返回值当成自己的号 `myturn`。全局共享的 `lock->turn` 表示当前轮到谁；当 `myturn == turn`，就轮到该线程进入临界区。解锁只需递增 `turn`，让下一条等待线程进来。

这个方案与之前有一处重要差别：它保证所有线程都能取得进展。线程一旦领到票号，排在前面的线程依次通过临界区并放锁后，早晚会轮到它。先前的方案没有这种保证；比如测试并设置上的线程完全可能永远自旋，看着别人反复拿锁、放锁。

!!! tip "提示：代码越少越好（Lauer 定律）"
    程序员总爱吹嘘自己为了某件事写了多少代码，这根本就搞反了。真正值得吹嘘的是，用多么少的代码完成了任务。简短精炼的代码总是更好理解，bug 也往往更少。

    Hugh Lauer 在谈 Pilot 操作系统的构建时说：“如果同一群人有两倍时间，他们就能用一半代码造出同样好的系统。”[L81] 我们姑且把它叫作 Lauer 定律，值得牢牢记住。下次想炫耀自己为作业写了多少代码时，再想想；更好的是，回去重写，把代码改得尽量清晰简洁。

## 28.12 自旋太多，怎么办？

前面的硬件锁很简单，只有几行代码；而且确实能工作。这两点对任何系统或代码都很宝贵。可某些情况下，它们效率糟糕。

设两条线程运行在单处理器上。线程 0 持锁进入临界区，却不幸被中断；线程 1 试图拿锁，发现锁被占用，于是开始自旋、继续自旋、再多转几圈。终于时钟中断到来，线程 0 再次运行并放锁；等线程 1 下次得到 CPU，才终于能拿到锁。线程 1 整个时间片都在检查一个根本不会变化的值！若有 $N$ 条线程争锁，类似地会浪费 $N-1$ 个时间片，只为了等一条线程释放锁。

!!! danger "问题核心：怎样避免自旋"
    怎样构建一把锁，不让线程在 CPU 上无谓地自旋浪费时间？

单靠硬件解决不了；操作系统也得出手。

## 28.13 简单办法：让出 CPU 就完了

硬件已经帮我们走了很远：锁能工作，票号锁甚至保证获取公平。但还有一个问题：若持锁线程在临界区内被切走，其他线程开始无休止地自旋，怎么办？

第一次尝试很友善：既然要自旋，不如主动把 CPU 让给别的线程。借用 Al Davis 的话，“让出 CPU 就完了！”[D91]

```c linenums="1"
void init() {
    flag = 0;
}

void lock() {
    while (TestAndSet(&flag, 1) == 1)
        yield(); // 交出 CPU
}

void unlock() {
    flag = 0;
}
```

*图 28.8：测试并设置配合 `yield` 的锁。*

这里假设操作系统提供 `yield()` 原语。线程有运行、就绪和阻塞三种状态；`yield` 这个系统调用把调用者从运行态移到就绪态，让另一条线程进入运行态，也就是主动取消调度自己。

两条线程共享一个 CPU 时，这招相当好用：发现锁被占用，就交出 CPU，另一条线程得以运行并完成临界区。

可若 100 条线程反复争锁呢？一条线程拿锁后、释放前被抢占，另外 99 条会逐个调用 `lock()`，发现锁被占用，再 `yield()`。假设轮转调度，持锁线程重新运行之前，其余 99 条都要表演一遍“运行然后让出”。这比浪费 99 个时间片自旋强，却依旧昂贵：上下文切换本身开销可不小。

更糟的是，饥饿完全没解决。一条线程可能永远困在让出循环里，其他线程却不断进出临界区。我们需要直面这个问题的办法。

## 28.14 使用队列：睡眠代替自旋

先前方案的问题，是把太多交给运气。调度器选谁运行；选得不好，线程要么自旋等锁，要么立刻交出 CPU。两种都可能浪费，而且都挡不住饥饿。

所以，我们必须明确控制当前持有者放锁后，下一条由谁获取。为此需要操作系统再帮一点忙，并用队列记录等待线程。

为简单起见，使用 Solaris 的两个调用：`park()` 让调用线程睡眠；`unpark(threadID)` 唤醒指定线程。它们能构造这样的锁：线程争一把已被占用的锁时睡眠，锁空闲时再被唤醒。

```c linenums="1"
typedef struct __lock_t {
    int flag;
    int guard;
    queue_t *q;
} lock_t;

void lock_init(lock_t *m) {
    m->flag = 0;
    m->guard = 0;
    queue_init(m->q);
}

void lock(lock_t *m) {
    while (TestAndSet(&m->guard, 1) == 1)
        ; // 自旋以获取 guard 锁
    if (m->flag == 0) {
        m->flag = 1; // 已获取锁
        m->guard = 0;
    } else {
        queue_add(m->q, gettid());
        m->guard = 0;
        park();
    }
}

void unlock(lock_t *m) {
    while (TestAndSet(&m->guard, 1) == 1)
        ; // 自旋以获取 guard 锁
    if (queue_empty(m->q))
        m->flag = 0; // 没人想要，放锁
    else
        unpark(queue_remove(m->q)); // 保持持锁状态
                                    // （交给下一条线程！）
    m->guard = 0;
}
```

*图 28.9：使用队列、测试并设置、让出和唤醒的锁。*

这个例子做了两件有意思的事。第一，把测试并设置与显式等待队列结合，造出更高效的锁；第二，用队列控制下一位持锁者，从而避免饥饿。

`guard` 本质上是保护 `flag` 和队列操作的一把自旋锁。所以它没有彻底消灭自旋：线程在获取或释放锁时仍可能被中断，迫使别人等它再次运行。不过自旋时间被压到很短，只覆盖 `lock`/`unlock` 内的几条指令，而非用户定义的整个临界区，所以还算合理。

`lock()` 拿不到锁时，会先用 `gettid()` 取得当前线程 ID，把自己加入队列，再清除 `guard` 并交出 CPU。想一想：若把释放 `guard` 放到 `park()` **之后**，会怎样？提示：不是好事。

另一处有趣细节是：唤醒下一条线程时，`flag` 没有清零。这不是错误，而是必须如此。被唤醒的线程像是从 `park()` 返回，但它此刻没有 `guard`，甚至没法安全地把 `flag` 设为 1。因此，释放者直接把锁传给下一个获取者，中间不让 `flag` 变成 0。

最后，`park()` 前似乎有个竞争：线程即将睡眠，认为要等锁释放；偏偏此刻切到持锁线程，后者释放并唤醒它，而第一条线程随后才真正 `park()`，便可能永远睡下去。这叫**唤醒/等待竞争(wakeup/waiting race)**。

Solaris 增加第三个系统调用 `setpark()` 来解决。线程先声明自己正要 `park`；若中途被打断，另一条线程在实际 `park()` 前调用了 `unpark`，随后的 `park()` 会立即返回而不睡眠。改动很小：

```c linenums="1"
queue_add(m->q, gettid());
setpark(); // 新代码
m->guard = 0;
```

另一种解法是把 `guard` 传进内核，由内核原子地释放锁并把当前线程移出运行队列。

!!! note "边栏：避开自旋的又一个理由——优先级反转"
    避开自旋锁的一个好理由是性能；还有个更有趣的理由是正确性。需要提防的问题叫**优先级反转(priority inversion)**，这场星际瘟疫不但肆虐地球 [M15]，还蔓延到了火星 [R97]！

    假设 T2 调度优先级高，T1 低；两者都可运行时，调度器总选 T2。若 T2 起初因 I/O 阻塞，T1 得以运行、拿到自旋锁并进入临界区。此时 T2 解阻塞，立刻抢占 T1；接着它争锁失败并开始自旋。由于高优先级 T2 始终可运行，低优先级 T1 再也跑不到、也就永远不能放锁，整个系统挂起。

    不用自旋锁也不能彻底摆脱反转。设 T3 优先级最高，T1 最低，T2 居中。T1 拿锁后被 T3 抢占；T3 等待 T1 的锁而阻塞。若 T2 开始运行，它优先级高于 T1，于是 T1 可能永远得不到 CPU。堂堂最高优先级 T3 被最低优先级 T1 卡住，CPU 却归中不溜的 T2 掌控——高优先级早已不复当年之勇。

    一种通用解法是**优先级继承(priority inheritance)**：高优先级线程等待低优先级线程时，暂时提升后者的优先级，让它运行并解除反转。最简单的办法则是让所有线程优先级相同。

## 28.15 不同操作系统，不同支持

其他操作系统也提供类似支持，只是细节不同。Linux 提供 **futex**，与 Solaris 接口相近，但在内核里做得更多。每个 futex 关联一个具体物理内存位置和一条内核等待队列。

`futex_wait(address, expected)` 在 `address` 处的值等于 `expected` 时让调用线程睡眠；若不相等则立即返回。`futex_wake(address)` 唤醒队列中的一条等待线程。Linux 互斥锁的一种实现如下（原代码来自 GNU libc 的 NPTL 库 `lowlevellock.h`）[L09]：

```c linenums="1"
void mutex_lock(int *mutex) {
    int v;
    /* 第 31 位原本为 0，我们拿到了互斥锁（快速路径） */
    if (atomic_bit_test_set(mutex, 31) == 0)
        return;
    atomic_increment(mutex);
    while (1) {
        if (atomic_bit_test_set(mutex, 31) == 0) {
            atomic_decrement(mutex);
            return;
        }
        /* 必须等待。先确认正在监视的 futex 值
           确实为负（已加锁）。 */
        v = *mutex;
        if (v >= 0)
            continue;
        futex_wait(mutex, v);
    }
}

void mutex_unlock(int *mutex) {
    /* 给计数器加 0x80000000，当且仅当没有其他
       感兴趣的线程时，结果才为 0 */
    if (atomic_add_zero(mutex, 0x80000000))
        return;

    /* 还有其他线程在等待这把互斥锁，
       唤醒其中一条。 */
    futex_wake(mutex);
}
```

*图 28.10：基于 Linux futex 的锁。*

这段代码有几个看点。第一，只用一个整数同时记录锁是否被持有（最高位）和等待者数量（其余位）。最高位决定整数符号，因此负数表示锁被持有。

第二，它优化了最常见的无竞争情形：只有一条线程拿锁、放锁时，工作量极少——获取时做一次原子位测试并设置，释放时做一次原子加法。其余代码请亲自琢磨，弄明白就能晋升 Linux 锁大师；至少也能成为一个听书劝的人[^3]。

[^3]: 比如买一本纸质 OSTEP！网上虽能免费读，可你难道不想在桌上摆一本精装吗？最好买十本分送亲朋好友，再多来一本砸仇人——这书挺沉，扔起来意外地好用。

## 28.16 两阶段锁

Linux 的做法带有一种古老方法的味道：至少可追溯到 20 世纪 60 年代初的 Dahm Locks [M82]，如今叫作**两阶段锁(two-phase lock)**。

它意识到自旋有时很有用，特别是锁马上就要释放时。因此第一阶段先自旋一阵，希望拿到锁；若第一阶段仍未成功，就进入第二阶段，让调用者睡眠，等锁以后空闲再唤醒。上面的 Linux 锁就是一种两阶段锁，不过只自旋一次；更一般的版本可以循环自旋固定时间，再借助 futex 睡眠。

两阶段锁又是一种混合方案：把两个好点子组合起来，可能得到更好的点子。当然，到底好不好，强烈依赖硬件环境、线程数量和其他负载细节。照例，要造出一把适用于所有场景的通用锁，极具挑战。

## 28.17 小结

现代真实锁的构建方式大抵如此：一点硬件支持（更强的指令）加一点操作系统支持（Solaris 的 `park()`/`unpark()`，或 Linux 的 futex）。细节各不相同，实际锁代码通常经过高度调优。想深入了解，可阅读 Solaris 或 Linux 源码 [L09, S09]；那会是趟迷人的旅程。David 等人的优秀工作 [D+13] 还比较了现代多处理器上的多种锁策略。

## 参考文献

- [D91] *Just Win, Baby: Al Davis and His Raiders* by Glenn Dickey. Harcourt, 1991. 讲 Al Davis 和他那句名言的书。准确说来，大概更多是在讲他和突袭者队，而不是那句话。声明一下：我们不是在推荐，只是需要个引用。
- [D+13] “Everything You Always Wanted to Know about Synchronization but Were Afraid to Ask” by Tudor David, Rachid Guerraoui, Vasileios Trigonakis. SOSP '13, Nemacolin Woodlands Resort, Pennsylvania, November 2013. 比较了许多用硬件原语造锁的办法，很适合观察这些点子在现代硬件上的表现。
- [D68] “Cooperating sequential processes” by Edsger W. Dijkstra. 1968. <http://www.cs.utexas.edu/users/EWD/ewd01xx/EWD123.PDF>. 早期奠基论文之一，谈到 Dijkstra 怎样提出并发问题，以及 Dekker 的解法。
- [H93] *MIPS R4000 Microprocessor User's Manual* by Joe Heinrich. Prentice-Hall, June 1993. Available: <http://cag.csail.mit.edu/raw/documents/R4400_Uman_book_Ed2.pdf>. 老 MIPS 用户手册，趁它还在赶紧下载。
- [H91] “Wait-free Synchronization” by Maurice Herlihy. *ACM TOPLAS*, 13(1), January 1991. 引入并发数据结构另一种构建思路的里程碑论文。由于实现复杂，其中一些思想推广得较慢。
- [L81] “Observations on the Development of an Operating System” by Hugh Lauer. SOSP '81. 回顾早期 PC 操作系统 Pilot 的必读文章，有趣而且洞见满满。
- [L09] “glibc 2.9 (include Linux pthreads implementation)” by many authors. Available: <http://ftp.gnu.org/gnu/glibc>. 尤其可看 `nptl` 子目录，其中有 Linux 当前的大部分 pthread 支持。
- [M82] “The Architecture of the Burroughs B5000: 20 Years Later and Still Ahead of the Times?” by A. Mayer. 1982. Available: <http://www.ajwm.net/amayer/papers/B5000.html>. RDLK 是不可分割的内存读写操作，也就是测试并设置。Dave Dahm 创造了自旋锁（“Buzz Locks”）和一种叫 Dahm Locks 的两阶段锁。
- [M15] “OSSpinLock Is Unsafe” by J. McCall. Available: <https://mjtsai.com/blog/2015/12/16/osspinlock-is-unsafe/>. Mac 上给不同优先级线程使用 `OSSpinLock` 并不安全——可能永远自旋。Mac 信徒们小心了，你们伟大的系统也并非完美无瑕……
- [MS91] “Algorithms for Scalable Synchronization on Shared-Memory Multiprocessors” by John M. Mellor-Crummey and M. L. Scott. *ACM TOCS*, 9(1), February 1991. 全面调查不同锁算法的优秀论文，只用花哨硬件指令，不借助操作系统。
- [P81] “Myths About the Mutual Exclusion Problem” by G. L. Peterson. *Information Processing Letters*, 12(3):115–116, 1981. 本章 Peterson 算法的出处。
- [R97] “What Really Happened on Mars?” by Glenn E. Reeves. Available: <http://research.microsoft.com/en-us/um/people/mbj/Mars_Pathfinder/Authoritative_Account.html>. 对火星探路者优先级反转事件的说明。并发代码的正确性很重要，尤其是在太空！
- [S05] “Guide to porting from Solaris to Linux on x86” by Ajay Sood. April 29, 2005. Available: <http://www.ibm.com/developerworks/linux/library/l-solar/>.
- [S09] “OpenSolaris Thread Library” by Sun. Code: `src.opensolaris.org/source/xref/onnv/onnv-gate/usr/src/lib/libc/port/threads/synch.c`. 相当有意思，不过 Oracle 收购 Sun 后会怎样，谁说得准呢。感谢 Mike Swift 提供线索。
- [W09] “Load-Link, Store-Conditional” by many authors. <https://en.wikipedia.org/wiki/Load-Link/Store-Conditional>. 真不敢相信我们引用了维基百科！但信息确实来自那里，不引用反而不厚道。它列出了不同体系结构的指令：Alpha 的 `ldl_l/stl_c` 和 `ldq_l/stq_c`、PowerPC 的 `lwarx/stwcx`、MIPS 的 `ll/sc`、ARM 的 `ldrex/strex`。其实维基百科很了不起，别那么刻薄，好吗？
- [WG00] *The SPARC Architecture Manual: Version 9* by D. Weaver, T. Germond. SPARC International, 2000. <http://www.sparc.org/standards/SPARCV9.pdf>. SPARC 原子操作的进一步资料见 `developers.sun.com/solaris/articles/atomic_sparc/`。

## 作业（模拟器）

`x86.py` 可以展示不同线程交错怎样引发或避开竞争条件。先阅读 `README` 了解程序，再回答下列问题。

1. 检查 `flag.s`。它用单个内存标志“实现”锁。你能读懂汇编吗？
2. 使用默认参数运行时，`flag.s` 能工作吗？用 `-M` 和 `-R` 跟踪变量和寄存器，再用 `-c` 显示值。你能预测 `flag` 最终是多少吗？
3. 用 `-a` 改变 `%bx`（如两条线程时使用 `-a bx=2,bx=2`）。代码会做什么？这怎样改变上一题答案？
4. 给每条线程的 `bx` 设一个很大的值，再用 `-i` 产生不同中断频率。哪些值导致错误结果？哪些得到正确结果？
5. 查看 `test-and-set.s`。先理解代码怎样用 `xchg` 构建简单锁原语。获取锁怎样写？释放锁呢？
6. 运行代码，再次改变中断间隔 `-i`，并保证循环多次。代码是否始终按预期工作？有时会低效使用 CPU 吗？怎样量化？
7. 用 `-P` 为锁代码生成特定测试。例如安排第一条线程拿锁，第二条随后尝试获取。行为正确吗？还应测试什么？
8. 查看 `peterson.s`，它实现了边栏中的 Peterson 算法。研究代码，看看能否说通。
9. 用不同 `-i` 运行。能看到哪些不同行为？代码假定线程 ID 已正确设置，记得用 `-a bx=0,bx=1` 之类的参数。
10. 能否用 `-P` 控制调度，“证明”代码正确？应展示哪些不同情形？想想互斥和避免死锁。
11. 研究 `ticket.s` 的票号锁。它与本章代码一致吗？然后用 `-a bx=1000,bx=1000` 运行，让每条线程通过临界区 1000 次。观察发生了什么：线程是否花了大量时间自旋等锁？
12. 增加线程后，代码表现怎样？
13. 查看 `yield.s`，其中一条 `yield` 指令让线程交出 CPU（现实中它是操作系统原语，这里为简单起见当作指令）。找一个 `test-and-set.s` 浪费周期自旋、`yield.s` 却不会的场景。省了多少条指令？这些收益在什么情形出现？
14. 最后检查 `test-and-test-and-set.s`。这把锁做了什么？与 `test-and-set.s` 相比，它节省了什么？
