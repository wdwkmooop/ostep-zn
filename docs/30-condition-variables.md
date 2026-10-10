# 第 30 章 条件变量

> 英文原题：*Condition Variables*

到目前为止，我们建立了锁的概念，也看到硬件与操作系统怎样联手造出正确的锁。可惜，构建并发程序不能只靠锁。

很多时候，线程继续执行前要检查某个条件是否成立。例如，父线程可能要等子线程结束后再继续——这通常叫 `join()`。这样的等待该怎样实现？

```c linenums="1"
void *child(void *arg) {
    printf("child\n");
    // XXX 怎样表示我们已经结束？
    return NULL;
}

int main(int argc, char *argv[]) {
    printf("parent: begin\n");
    pthread_t c;
    Pthread_create(&c, NULL, child, NULL); // 创建子线程
    // XXX 怎样等待子线程？
    printf("parent: end\n");
    return 0;
}
```

*图 30.1：父线程等待子线程。*

我们想看到：

```text
parent: begin
child
parent: end
```

可以用共享变量硬凑：

```c linenums="1"
volatile int done = 0;

void *child(void *arg) {
    printf("child\n");
    done = 1;
    return NULL;
}

int main(int argc, char *argv[]) {
    printf("parent: begin\n");
    pthread_t c;
    Pthread_create(&c, NULL, child, NULL); // 创建子线程
    while (done == 0)
        ; // 自旋
    printf("parent: end\n");
    return 0;
}
```

*图 30.2：父线程等待子线程——基于自旋的方案。*

它通常能工作，却效率低得吓人：父线程自旋，白白烧掉 CPU 时间。真正想要的是让父线程睡眠，直到等待的条件——比如子线程结束——成为真。

!!! danger "问题核心：怎样等待一个条件"
    多线程程序经常需要等某个条件成立才继续。简单自旋效率极差、浪费 CPU 周期，有时甚至不正确。线程究竟该怎样等待条件？

## 30.1 定义与例程

线程可以用**条件变量(condition variable)** 等待条件成立。条件变量是一条显式队列：程序状态不符合要求时，线程可以在这个条件上等待，把自己放进队列；另一条线程改变状态后，可以在条件上发信号，唤醒一个或多个等待者。这个思想可追溯到 Dijkstra 的“私有信号量”[D68]，Hoare 后来在管程研究中把类似概念命名为“条件变量”[H74]。

声明方式是 `pthread_cond_t c;`，当然还要正确初始化。条件变量有两个操作：`wait()` 让线程睡眠，`signal()` 表示程序状态发生变化、唤醒等待者。POSIX 接口是：

```c
pthread_cond_wait(pthread_cond_t *c, pthread_mutex_t *m);
pthread_cond_signal(pthread_cond_t *c);
```

为简洁起见，后文常简称 `wait()` 和 `signal()`。注意 `wait()` 还接收一把互斥锁，并假定调用时锁已被持有。它负责**原子地**释放锁并让调用线程睡眠；线程被别人发信号唤醒后，`wait()` 返回前必须重新拿锁。这种复杂性是为了避免线程正要睡下时发生竞争。

```c linenums="1"
int done = 0;
pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t c = PTHREAD_COND_INITIALIZER;

void thr_exit() {
    Pthread_mutex_lock(&m);
    done = 1;
    Pthread_cond_signal(&c);
    Pthread_mutex_unlock(&m);
}

void *child(void *arg) {
    printf("child\n");
    thr_exit();
    return NULL;
}

void thr_join() {
    Pthread_mutex_lock(&m);
    while (done == 0)
        Pthread_cond_wait(&c, &m);
    Pthread_mutex_unlock(&m);
}

int main(int argc, char *argv[]) {
    printf("parent: begin\n");
    pthread_t p;
    Pthread_create(&p, NULL, child, NULL);
    thr_join();
    printf("parent: end\n");
    return 0;
}
```

*图 30.3：父线程用条件变量等待子线程。*

有两种执行次序。第一种，父线程创建孩子后继续运行，马上进入 `thr_join()`：拿锁，发现 `done=0`，调用 `wait()` 原子地放锁并睡眠。孩子最终运行，打印 `child`，在 `thr_exit()` 中拿锁、把 `done` 设为 1、发信号唤醒父线程。父线程从 `wait()` 返回时已经重新持锁，随后解锁并打印 `parent: end`。

第二种，孩子一创建就先运行，把 `done` 设为 1；它调用 `signal` 时还没有睡眠者，所以直接返回。父线程随后进入 `thr_join()`，看到 `done=1`，不等待便返回。

父线程为何用 `while` 而不是 `if`？这段程序里看似没必要，但始终是好习惯，后面马上就会看到原因。

如果去掉状态变量 `done`，只剩下发信号和等待，会怎样？

```c
void thr_exit() {
    Pthread_mutex_lock(&m);
    Pthread_cond_signal(&c);
    Pthread_mutex_unlock(&m);
}

void thr_join() {
    Pthread_mutex_lock(&m);
    Pthread_cond_wait(&c, &m);
    Pthread_mutex_unlock(&m);
}
```

这是坏的。若孩子先运行，信号发出时无人睡眠；父线程后来调用 `wait()`，便会永远卡住。`done` 记录的是线程真正关心的状态，睡眠、唤醒与锁都围绕它运转。

若又自作聪明，认为等待和发信号不必持锁：

```c
void thr_exit() {
    done = 1;
    Pthread_cond_signal(&c);
}

void thr_join() {
    if (done == 0)
        Pthread_cond_wait(&c);
}
```

这里有个微妙竞争：父线程看到 `done=0`，正要睡眠时被中断；孩子把 `done` 设为 1 并发信号，可此刻无人等待；父线程恢复后睡下，从此再也没人叫醒它。真悲伤。

!!! tip "提示：发信号时始终持锁"
    严格说来，某些情况下不持锁发信号也没错；但最简单、最稳妥的规则是：调用 `signal` 时持锁。上面的例子就展示了正确性依赖锁的情形。

    调用 `wait` 时持锁则不是建议，而是语义要求：`wait` 假定锁已持有，睡眠时释放它，返回前重新获取。总之，调用 `signal` 或 `wait` 时都持锁，你就稳了。

## 30.2 生产者/消费者（有界缓冲区）问题

下一个同步问题叫**生产者/消费者问题(producer/consumer problem)**，也叫**有界缓冲区问题(bounded-buffer problem)**，最早由 Dijkstra 提出 [D72]。正是这个问题促使 Dijkstra 和同事发明了广义信号量——它既能当锁，也能当条件变量 [D01]。

一个或多个生产者生成数据项，放入缓冲区；一个或多个消费者从缓冲区取走并消费。现实系统随处可见这种结构：多线程 Web 服务器把 HTTP 请求放进工作队列，工作线程从队列取出处理；运行 `grep foo file.txt | wc -l` 时，`grep` 是生产者，`wc` 是消费者，内核中的 UNIX 管道就是有界缓冲区，而你只是快乐的用户。

先用一个整数作为单槽缓冲区：

```c linenums="1"
int buffer;
int count = 0; // 初始为空

void put(int value) {
    assert(count == 0);
    count = 1;
    buffer = value;
}

int get() {
    assert(count == 1);
    count = 0;
    return buffer;
}
```

*图 30.4：`put()` 和 `get()`（版本 1）。*

`put()` 假定缓冲区为空，放入值后把 `count` 设为 1；`get()` 反过来，把 `count` 清零并返回值。之后会推广到多槽队列。

```c linenums="1"
void *producer(void *arg) {
    int i;
    int loops = (int) arg;
    for (i = 0; i < loops; i++) {
        put(i);
    }
}

void *consumer(void *arg) {
    int i;
    while (1) {
        int tmp = get();
        printf("%d\n", tmp);
    }
}
```

*图 30.5：生产者/消费者线程（版本 1）。*

条件很明显：`count=0`、缓冲区为空时才能放；`count=1`、缓冲区已满时才能取。若生产者往满缓冲区写，或消费者从空缓冲区取，就是同步代码写错了，断言也会炸。

### 坏掉的方案

先设只有一个生产者和一个消费者。`put()` 与 `get()` 都包含临界区，可只加锁仍不够，还需要条件变量。第一次尝试只用一个条件变量 `cond`：

```c linenums="1"
int loops; // 必须在某处初始化……
cond_t cond;
mutex_t mutex;

void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);           // p1
        if (count == 1)                       // p2
            Pthread_cond_wait(&cond, &mutex); // p3
        put(i);                               // p4
        Pthread_cond_signal(&cond);           // p5
        Pthread_mutex_unlock(&mutex);         // p6
    }
}

void *consumer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);           // c1
        if (count == 0)                       // c2
            Pthread_cond_wait(&cond, &mutex); // c3
        int tmp = get();                      // c4
        Pthread_cond_signal(&cond);           // c5
        Pthread_mutex_unlock(&mutex);         // c6
        printf("%d\n", tmp);
    }
}
```

*图 30.6：生产者/消费者——一个条件变量加 `if`。*

一个生产者、一个消费者时它能工作；增加到两个消费者就有两个致命问题。

第一个与 `wait` 前的 `if` 有关。消费者 Tc1 发现没有数据而睡眠；生产者 Tp 放入一个值并唤醒 Tc1，使其进入就绪队列，但 Tc1 尚未真正运行。此时消费者 Tc2 偷偷插队，取走唯一的数据。Tc1 随后从 `wait()` 返回，重新持锁后直接调用 `get()`，可缓冲区已经空了，断言触发。

| 步骤 | Tc1 | Tc2 | Tp | `count` | 说明 |
|---:|---|---|---|---:|---|
| 1 | c1→c3，睡眠 | 就绪 | 就绪 | 0 | 没东西可取 |
| 2 | 就绪 | 就绪 | p1→p5 | 1 | Tp 放入值并唤醒 Tc1 |
| 3 | 就绪 | 就绪 | p6→p3，睡眠 | 1 | 缓冲区已满 |
| 4 | 就绪 | c1→c6 | 睡眠 | 0 | Tc2 抢先取走数据 |
| 5 | c4 | 就绪 | 就绪 | 0 | 糟糕！Tc1 无数据可取 |

*图 30.7：坏方案执行轨迹（版本 1）。*

生产者唤醒 Tc1 后、Tc1 真正运行前，Tc2 改变了缓冲区状态。信号只是“世界状态可能变了”的提示，并不保证被唤醒线程运行时条件仍满足。这叫 **Mesa 语义(Mesa semantics)** [LR80]。相对的 **Hoare 语义(Hoare semantics)** [H74] 保证被唤醒线程立刻运行，更难实现。几乎所有现实系统都采用 Mesa 语义。

### 好一点，但仍然坏：用 `while`，不用 `if`

第一个问题很好修：把 `if` 改成 `while`。

```c linenums="1"
int loops;
cond_t cond;
mutex_t mutex;

void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);           // p1
        while (count == 1)                    // p2
            Pthread_cond_wait(&cond, &mutex); // p3
        put(i);                               // p4
        Pthread_cond_signal(&cond);           // p5
        Pthread_mutex_unlock(&mutex);         // p6
    }
}

void *consumer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);           // c1
        while (count == 0)                    // c2
            Pthread_cond_wait(&cond, &mutex); // c3
        int tmp = get();                      // c4
        Pthread_cond_signal(&cond);           // c5
        Pthread_mutex_unlock(&mutex);         // c6
        printf("%d\n", tmp);
    }
}
```

*图 30.8：生产者/消费者——一个条件变量加 `while`。*

Tc1 醒来并持锁后会重新检查共享状态；若缓冲区已空，就再次睡眠。Mesa 语义下，记住一条简单规则：条件变量总是配 `while`。有时复查并非必需，但总是安全，照做就开心了。

然而代码还有第二个 bug：只有一个条件变量。假设两个消费者先后睡眠；生产者放入一个值，唤醒 Tc1，然后发现缓冲区满而睡眠。Tc1 取走数据后调用 `signal()`，本该唤醒生产者，却可能唤醒 Tc2。Tc2 醒来发现缓冲区为空，又睡下；生产者仍在睡，Tc1 随后也睡。三条线程全睡着了。

| 阶段 | Tc1 | Tc2 | Tp | `count` | 结果 |
|---|---|---|---|---:|---|
| 两消费者等待 | 睡眠 | 睡眠 | 就绪 | 0 | 都没东西可取 |
| 生产者放入 | 就绪 | 睡眠 | 随后睡眠 | 1 | Tp 唤醒 Tc1 |
| Tc1 取出 | 运行 | 睡眠→就绪 | 睡眠 | 0 | 错误地唤醒 Tc2 |
| 最终 | 睡眠 | 睡眠 | 睡眠 | 0 | 所有人都睡了 |

*图 30.9：坏方案执行轨迹（版本 2）。*

信号必须更有针对性：消费者只该唤醒生产者，生产者只该唤醒消费者。

### 单槽生产者/消费者的解法

改动仍很小：使用两个条件变量。

```c linenums="1"
cond_t empty, fill;
mutex_t mutex;

void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);
        while (count == 1)
            Pthread_cond_wait(&empty, &mutex);
        put(i);
        Pthread_cond_signal(&fill);
        Pthread_mutex_unlock(&mutex);
    }
}

void *consumer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);
        while (count == 0)
            Pthread_cond_wait(&fill, &mutex);
        int tmp = get();
        Pthread_cond_signal(&empty);
        Pthread_mutex_unlock(&mutex);
        printf("%d\n", tmp);
    }
}
```

*图 30.10：生产者/消费者——两个条件变量加 `while`。*

生产者等待 `empty`、发信号给 `fill`；消费者等待 `fill`、发信号给 `empty`。这样，消费者不会误唤醒消费者，生产者也不会误唤醒生产者。

### 正确的生产者/消费者解法

最后把单槽缓冲区扩展成多槽队列，让多个值可以在生产者睡眠前放入，也让消费者能连续取出多个值。这既减少单生产者/消费者场景中的上下文切换，也能让多个生产者或消费者获得更高并发度。

```c linenums="1"
int buffer[MAX];
int fill_ptr = 0;
int use_ptr = 0;
int count    = 0;

void put(int value) {
    buffer[fill_ptr] = value;
    fill_ptr = (fill_ptr + 1) % MAX;
    count++;
}

int get() {
    int tmp = buffer[use_ptr];
    use_ptr = (use_ptr + 1) % MAX;
    count--;
    return tmp;
}
```

*图 30.11：正确的 `put()` 和 `get()`。*

```c linenums="1"
cond_t empty, fill;
mutex_t mutex;

void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);            // p1
        while (count == MAX)                   // p2
            Pthread_cond_wait(&empty, &mutex); // p3
        put(i);                                // p4
        Pthread_cond_signal(&fill);            // p5
        Pthread_mutex_unlock(&mutex);          // p6
    }
}

void *consumer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        Pthread_mutex_lock(&mutex);            // c1
        while (count == 0)                     // c2
            Pthread_cond_wait(&fill, &mutex);  // c3
        int tmp = get();                       // c4
        Pthread_cond_signal(&empty);           // c5
        Pthread_mutex_unlock(&mutex);          // c6
        printf("%d\n", tmp);
    }
}
```

*图 30.12：正确的生产者/消费者同步。*

生产者仅在所有槽都满时睡眠，消费者仅在全部槽都空时睡眠。至此，问题解决；可以坐下来喝杯冰的了。

!!! tip "提示：条件判断用 `while`，别用 `if`"
    多线程程序检查条件时，`while` 始终正确；`if` 是否正确则取决于信号语义。因此一律使用 `while`，代码才会按预期工作。

    `while` 还能应对**虚假唤醒(spurious wakeup)**。某些线程包受实现细节影响，一次 `signal` 也可能唤醒两条线程 [L11]；这更说明必须重新检查等待条件。

## 30.3 覆盖条件

最后看一个来自 Lampson 和 Redell 的 Pilot 论文 [LR80] 的例子：多线程内存分配库。

```c linenums="1"
// 堆中还有多少空闲字节？
int bytesLeft = MAX_HEAP_SIZE;

// 还需要锁和条件变量
cond_t c;
mutex_t m;

void *
allocate(int size) {
    Pthread_mutex_lock(&m);
    while (bytesLeft < size)
        Pthread_cond_wait(&c, &m);
    void *ptr = ...; // 从堆中取得内存
    bytesLeft -= size;
    Pthread_mutex_unlock(&m);
    return ptr;
}

void free(void *ptr, int size) {
    Pthread_mutex_lock(&m);
    bytesLeft += size;
    Pthread_cond_signal(&c); // 该唤醒谁？？
    Pthread_mutex_unlock(&m);
}
```

*图 30.13：覆盖条件示例。*

线程申请内存时，空闲量不足便等待；线程释放内存时，发信号表示有更多空间。问题是：多个线程等待时，究竟该唤醒谁？

假设空闲字节为 0。Ta 调用 `allocate(100)`，Tb 随后调用 `allocate(10)`，两者都睡眠。Tc 释放 50 字节并发信号；它可能唤醒 Ta，但 Ta 仍得不到 100 字节，而真正能继续的 Tb 却还在睡。发信号者不知道该唤醒哪一条。

Lampson 和 Redell 的解法很直接：把 `pthread_cond_signal()` 换成 `pthread_cond_broadcast()`，唤醒所有等待线程。这样需要醒的线程保证能醒；代价是还不该醒的线程也被吵起来，只好复查条件后立刻睡回去。

他们把这种条件叫**覆盖条件(covering condition)**，因为它保守地覆盖所有需要唤醒的情形。早先单条件变量的生产者/消费者问题也可以广播解决，但那里有更好的双条件变量方案。一般来说，如果程序只有把 `signal` 改成 `broadcast` 才能工作，而你觉得本不该如此，那多半藏着 bug，修它！不过像这个分配器一样的场景里，广播可能就是最直接的解法。

## 30.4 小结

本章引入了锁之外另一种重要同步原语：条件变量。程序状态不合要求时，线程可以睡眠，因此我们能干净地解决著名且仍然重要的生产者/消费者问题，以及覆盖条件问题。这里本该来一句更有戏剧性的结尾，比如：“他热爱老大哥。”[O49]

## 参考文献

- [D68] “Cooperating Sequential Processes” by Edsger W. Dijkstra. 1968. <http://www.cs.utexas.edu/users/EWD/ewd01xx/EWD123.PDF>. 又一篇 Dijkstra 经典；读他的并发早期著作，就能学到这个领域的大半基础。
- [D72] “Information Streams Sharing a Finite Buffer” by E. W. Dijkstra. *Information Processing Letters* 1:179–180, 1972. <http://www.cs.utexas.edu/users/EWD/ewd03xx/EWD329.PDF>. 提出生产者/消费者问题的名篇。
- [D01] “My Recollections of Operating System Design” by E. W. Dijkstra. April 2001. <http://www.cs.utexas.edu/users/EWD/ewd13xx/EWD1303.PDF>. 想知道先驱怎样想出中断乃至“栈”这些基础概念，这是篇迷人的读物。
- [H74] “Monitors: An Operating System Structuring Concept” by C. A. R. Hoare. *Communications of the ACM*, 17(10):549–557, October 1974. Hoare 做了不少并发理论工作，不过最出名的大概仍是快速排序——至少本书作者认为，那是世上最酷的排序算法。
- [L11] “Pthread cond signal Man Page” by mysterious author. March 2011. <http://linux.die.net/man/3/pthread_cond_signal>. Linux 手册页用简单例子说明了信号/唤醒代码内部竞争怎样造成虚假唤醒。
- [LR80] “Experience with Processes and Monitors in Mesa” by B. W. Lampson and D. R. Redell. *Communications of the ACM*, 23(2):105–117, February 1980. 讲真实系统如何实现信号与条件变量的佳作，“Mesa 语义”由此得名；更早的 Hoare 语义则很难在课堂上板着脸念出来。
- [O49] *1984* by George Orwell. Secker and Warburg, 1949. 有点沉重，却当然必读。我们引用最后一句，似乎把结局剧透了，对不起！若政府正在读，就容我们说一句：政府真是“双加好”。NSA 的朋友，听见了吗？

## 作业（代码）

本作业用真实代码探索锁和条件变量实现的多种生产者/消费者队列。阅读下载包中的 `README` 了解细节。

1. 研究正确方案 `main-two-cvs-while.c`。运行前，你能说明应该发生什么吗？
2. 用一个生产者、一个消费者产生少量值。先设缓冲区大小为 1，再逐渐增大，行为怎样变化？把消费者睡眠串从默认值改为 `-C 0,0,0,0,0,0,1`，再改变缓冲区大小（如 `-m 10`）和产出数量（如 `-l 100`），预测 `num_full`。
3. 若条件允许，在不同系统（如 Mac 和 Linux）运行。行为有差异吗？
4. 一个生产者、三个消费者、单槽缓冲区，并让每个消费者在 c3 暂停一秒：`./main-two-cvs-while -p 1 -c 3 -m 1 -C 0,0,0,1,0,0,0:0,0,0,1,0,0,0:0,0,0,1,0,0,0 -l 10 -v -t`。你估计要多久？
5. 把缓冲区大小改为 3（`-m 3`），总时间会变化吗？
6. 把睡眠位置改到 c6，模拟消费者取出数据后处理它；仍用单槽缓冲区。预测 `./main-two-cvs-while -p 1 -c 3 -m 1 -C 0,0,0,0,0,0,1:0,0,0,0,0,0,1:0,0,0,0,0,0,1 -l 10 -v -t` 的时间。
7. 再把缓冲区改为 3，预测时间。
8. 查看 `main-one-cv-while.c`。一个生产者、一个消费者、单槽缓冲区时，能否配置睡眠串让代码出问题？
9. 把消费者增加到两个。能否构造生产者和消费者的睡眠串，让代码出问题？
10. 查看 `main-two-cvs-if.c`。能否让它出问题？分别考虑一个和多个消费者。
11. 最后查看 `main-two-cvs-while-extra-unlock.c`。在 `put` 或 `get` 前放锁会有什么问题？能否用睡眠串稳定复现？最坏会发生什么？
