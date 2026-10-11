# 附录 D 管程（已弃用）

> 英文原题：*Monitors (Deprecated)*

并发编程逐渐成为大事的同时，面向对象编程也在崛起。人们自然开始思考：能不能把同步融入一种结构更清晰的编程环境？

由此产生的一种方案是**管程(monitor)**。Per Brinch Hansen 首先描述了它 [BH73]，Tony Hoare 后来加以完善 [H74]。思想其实很简单，先看这个用 C++ 记法写成的假想管程：

```cpp
monitor class account {
private:
    int balance = 0;
public:
    void deposit(int amount) {
        balance = balance + amount;
    }
    void withdraw(int amount) {
        balance = balance - amount;
    }
};
```

*图 D.1：一个假想的管程类。*

之所以说“假想”，是因为 C++ 不支持管程，根本没有 `monitor` 关键字；Java 则通过所谓**同步方法(synchronized method)**支持类似机制。稍后既会看到怎样在 C/C++ 中造出近似管程，也会看看 Java 的同步方法。

这个例子里又见到了老朋友：银行账户，以及存款和取款函数。它们都是临界区；多个线程并发调用会产生竞态，结果可能错误。

管程类不会陷入这种麻烦，因为它保证任意时刻最多只有一个线程活跃在管程内部。多个线程可以放心调用 `deposit()` 或 `withdraw()`，互斥自动得到保证。

它怎样做到？很简单：锁。线程调用管程例程时，会隐式尝试获得**管程锁(monitor lock)**；成功才进入方法，失败就阻塞，直到管程内线程结束工作。用普通 C++ 显式写出来，大致就是：

```cpp
class account {
private:
    int balance = 0;
    pthread_mutex_t monitor;
public:
    void deposit(int amount) {
        pthread_mutex_lock(&monitor);
        balance = balance + amount;
        pthread_mutex_unlock(&monitor);
    }
    void withdraw(int amount) {
        pthread_mutex_lock(&monitor);
        balance = balance - amount;
        pthread_mutex_unlock(&monitor);
    }
};
```

*图 D.2：表现得像管程的 C++ 类。*

所以管程自动完成的事情并不多，基本只是获得和释放锁；但这足以保证 `deposit()` 与 `withdraw()` 内最多只有一个活跃线程。

## D.1 为什么还要管程？

你也许会问：既然显式加锁就能做到，为何还要发明管程？当时面向对象编程刚开始流行，人们想把并发编程的关键概念优雅地融合进面向对象的基本方法。就这么多，没有神秘祭坛，也没有隐藏桃子。

## D.2 除了自动加锁，还有别的吗？

只有锁并不够。实现生产者/消费者时，我们还需要让等待某条件变化的线程睡眠，例如生产者等待缓冲区腾空；条件改变后又要唤醒线程，例如消费者通知缓冲区已经腾空。

管程通过显式的**条件变量(condition variable)**支持这些功能。下面是带条件变量的生产者/消费者方案：

```cpp
monitor class BoundedBuffer {
private:
    int buffer[MAX];
    int fill, use;
    int fullEntries = 0;
    cond_t empty;
    cond_t full;
public:
    void produce(int element) {
        if (fullEntries == MAX)  // P0
            wait(&empty);        // P1
        buffer[fill] = element;  // P2
        fill = (fill + 1) % MAX; // P3
        fullEntries++;           // P4
        signal(&full);           // P5
    }

    int consume() {
        if (fullEntries == 0)    // C0
            wait(&full);         // C1
        int tmp = buffer[use];   // C2
        use = (use + 1) % MAX;   // C3
        fullEntries--;           // C4
        signal(&empty);          // C5
        return tmp;              // C6
    }
};
```

*图 D.3：采用管程与 Hoare 语义的生产者/消费者。*

生产者反复调用 `produce()` 放入数据，消费者反复调用 `consume()`。这是 Hoare 原方案的现代改写 [H74]。

它与信号量方案相似，但条件变量必须配合显式状态变量。这里由 `fullEntries` 判断生产者或消费者是否需要等待；信号量内部已有数值可承担相同角色。因此，条件变量总要和某种外部状态配对。

两个条件变量 `empty`、`full` 分别由 `wait()` 和 `signal()` 操作：`wait()` 把调用线程阻塞在指定条件上，`signal()` 唤醒等待该条件的一个线程。不过，这些调用的精确语义非常微妙，直接决定代码是否正确。

在所谓**Hoare 语义(Hoare semantics)**中，`signal()` 会立即唤醒并运行一个等待线程。当前线程隐式持有的管程锁立刻转交给被唤醒者；后者持续运行，直到再次阻塞或退出管程。如果有多个等待者，一次 `signal()` 只唤醒一个，其余仍等后续信号。

举例：一个消费者先运行，发现 `fullEntries == 0`（C0），于是执行 `wait(&full)`（C1）。生产者随后运行，无需等待（P0），放入元素（P2），更新 `fill`（P3）与 `fullEntries`（P4），再执行 `signal(&full)`（P5）。在 Hoare 语义下，生产者不会继续；控制权立即移交消费者。消费者从 C1 返回并马上消费元素（C2）。消费者退出后，生产者才再次运行并从 `produce()` 返回。

## D.3 理论遇见实践

Tony Hoare 提出了上述方案和 `signal()`、`wait()` 的精确语义。他是理论家，而且显然聪明得很——快速排序也是他发明的 [H61]。但事实证明，这套等待与通知语义并不适合实际实现。老话说得好：理论上，理论与实践没有差别；实践中，有。

!!! note "老话：理论与实践"
    “理论上，理论与实践没有差别；实践中，有。”当然，只有实践派才会这么告诉你；理论派无疑能证明它不成立。

几年后，Xerox PARC 的 Butler Lampson 与 David Redell 构建并发语言 Mesa，选择管程作为基本并发原语 [LR80]。这两位著名系统研究者很快发现，Hoare 语义虽然更方便证明，却很难在真实系统中实现——理由很多，多到这里大概装不下。

他们对 `signal()` 作出细微但关键的修改：`signal()` 只是一条**提示(hint)** [L83]。它把一个等待线程从阻塞态移到可运行态，却不立刻运行它；发信号的线程继续控制 CPU，直到退出管程并被调度出去。这就是**Mesa 语义(Mesa semantics)**。

## D.4 糟糕，竞态来了

重新检查前面的代码。消费者 1 进入管程，发现缓冲区为空，于是在 C1 等待。生产者填入缓冲区并发信号，把消费者 1 从条件变量 `full` 的阻塞队列移到就绪态；生产者继续运行一阵，最终交出 CPU。

但是，休斯敦，我们有麻烦了。若消费者 2 此时进入 `consume()`，它会发现缓冲区有数据，把元素消费掉再返回，同时将 `fullEntries` 设回 0。之后消费者 1 才终于运行，从 `wait()` 返回时还以为缓冲区是满的；可消费者 2 已抢先吃掉内容。

```text
生产者                 消费者 1                    消费者 2
                       C0: fullEntries=0
                       C1: 阻塞
P0: fullEntries=0
P2: 写入元素
P3: 推进 fill
P4: fullEntries=1
P5: 消费者 1 就绪
                                                   C0: fullEntries=1
                                                   C2/C3
                                                   C4: fullEntries=0
                                                   C5/C6，返回
                       C2: 试图使用缓冲区
                           但 fullEntries=0！
```

*图 D.4：这段代码为何不能在 Mesa 语义下工作。*

> 原图标题写成“为何不能在 Hoare 语义下工作”，但正文讨论的是切换到 Mesa 语义后出现的竞态；译文按正文实际含义说明。

幸运的是，只需很小的改动：线程被唤醒后必须重新检查等待条件。既然 `signal()` 只是一条提示，等线程真正运行时条件可能已变化，甚至变化了好几次。把 P0 和 C0 的 `if` 改成 `while`：

```cpp
public:
    void produce(int element) {
        while (fullEntries == MAX) // P0：由 if 改为 while
            wait(&empty);          // P1
        buffer[fill] = element;    // P2
        fill = (fill + 1) % MAX;   // P3
        fullEntries++;             // P4
        signal(&full);             // P5
    }

    int consume() {
        while (fullEntries == 0)   // C0：由 if 改为 while
            wait(&full);           // C1
        int tmp = buffer[use];     // C2
        use = (use + 1) % MAX;     // C3
        fullEntries--;             // C4
        signal(&empty);            // C5
        return tmp;                // C6
    }
```

*图 D.5：采用管程与 Mesa 语义的生产者/消费者。*

并不难。由于实现容易，如今几乎所有带等待/通知条件变量的系统都使用 Mesa 语义。因此，如果这门课你什么都没记住，至少记住：**醒来以后永远重新检查条件！** 更直白地说，检查条件时用 `while`，别用 `if`。即便某系统真使用 Hoare 语义，`while` 也正确，只是多检查一次而已。

## D.5 稍微看看幕后

Lampson 与 Redell 描述了线程在某一时刻可能所在的三类队列：**就绪队列(ready queue)**、**管程锁队列(monitor lock queue)**和**条件变量队列(condition variable queue)**。程序可以有多个管程类和多个条件变量实例，每个实例各有自己的队列。

一个有界缓冲区管程共有四个相关队列：就绪队列、一个管程队列，以及 `full`、`empty` 两个条件变量队列。下面跟踪两个消费者 Con1、Con2 和一个生产者 Prod。`FE` 是 `fullEntries`；空白队列表示无人等待。

| t | Con1 | Con2 | Prod | `full` 队列 | FE | 说明 |
|---:|---|---|---|---|---:|---|
| 0 | C0 | | | | 0 | 检查缓冲区 |
| 1 | C1 | | | Con1 | 0 | Con1 等待 `full` |
| 2 | | | | Con1 | 0 | 上下文切换：Con1→Prod |
| 3 | | | P0 | Con1 | 0 | |
| 4 | | | P2 | Con1 | 0 | Prod 不必等待 |
| 5 | | | P3 | Con1 | 0 | |
| 6 | | | P4 | Con1 | 1 | Prod 更新 FE |
| 7 | | | P5 | | 1 | Prod 发信号，Con1 就绪 |
| 8 | | | | | 1 | 上下文切换：Prod→Con2 |
| 9 | | C0 | | | 1 | Con2 开始运行 |
| 10 | | C2 | | | 1 | Con2 不必等待 |
| 11 | | C3 | | | 1 | |
| 12 | | C4 | | | 0 | Con2 把 FE 改为 0 |
| 13 | | C5 | | | 0 | 通知 `empty`，无人等待 |
| 14 | | C6 | | | 0 | Con2 完成 |
| 15 | | | | | 0 | 上下文切换：Con2→Con1 |
| 16 | C0 | | | | 0 | 重新检查，发现 FE=0 |
| 17 | C1 | | | Con1 | 0 | 再次等待 `full` |

*图 D.6：一次生产者/消费者运行中的队列轨迹。*

Con2 在 t=9～14 偷偷插进来，先于自 t=1 起等待的 Con1 消费了数据。Con1 虽在 t=7 被唤醒，真正运行时缓冲区却已空。若它不在 t=16 重新检查，就会错误地消费不存在的数据。正是这种自然实现导致 Mesa 而非 Hoare 语义。

## D.6 管程的其他用途

Lampson 与 Redell 还指出，有时需要另一种通知方式。考虑简单内存分配器：

```cpp
monitor class allocator {
    int available; // 还有多少内存可用？
    cond_t c;

    void *allocate(int size) {
        while (size > available)
            wait(&c);
        available -= size;
        // 完成分配器该做的其他工作，返回一块内存
    }

    void free(void *pointer, int size) {
        // 释放一部分内存
        available += size;
        signal(&c);
    }
};
```

*图 D.7：简单内存分配器。*

细节被刻意省略，以便聚焦唤醒条件。这里的 `signal()`/`wait()` 并不完全正确。假设两个线程分别申请 20 和 10 字节，当前无内存可用，于是都等待。后来另一个线程释放 15 字节并发信号；若恰好唤醒等待 20 字节的线程，它重新检查后发现仍不够，又睡回去。真正能使用这 15 字节、等待 10 字节的线程却没醒。

简单解法是用**广播(broadcast)**代替 `signal()`，唤醒全部等待者。两者都醒后，申请 10 字节的线程发现有 15 字节，成功继续。

在 Mesa 语义下广播永远正确，因为每个线程醒后本来就该重查条件；但它可能带来性能问题。广播也许唤醒几百个线程，最后只有一个成功，其余立刻又阻塞。额外上下文切换造成的昂贵现象称为**惊群(thundering herd)**，所以广播只该在必要时使用。

## D.7 用管程实现信号量

管程与信号量相似，可以互相实现。下面用管程实现信号量类：

```cpp
monitor class Semaphore {
    int s; // 信号量的值

    Semaphore(int value) {
        s = value;
    }

    void wait() {
        while (s <= 0)
            wait();
        s--;
    }

    void post() {
        s++;
        signal();
    }
};
```

*图 D.8：用管程实现信号量。*

`wait()` 等到值大于 0 再递减，`post()` 递增并唤醒一个等待线程。把初值设为 1，并在临界区前后调用 `wait()`/`post()`，它就是二值信号量，也就是锁。就这么简单：管程成功把信号量实现了出来。

## D.8 现实世界中的管程

前面使用的是“假想”管程，C++ 没有这一概念。下面看看怎样用 C++ 构造类似管程的类，以及 Java 怎样通过同步方法实现类似目标。

### 某种意义上的 C++ 管程

```cpp
class BoundedBuffer {
private:
    int buffer[MAX];
    int fill, use;
    int fullEntries;
    pthread_mutex_t monitor; // 管程锁
    pthread_cond_t empty;
    pthread_cond_t full;
public:
    BoundedBuffer() {
        use = fill = fullEntries = 0;
    }

    void produce(int element) {
        pthread_mutex_lock(&monitor);
        while (fullEntries == MAX)
            pthread_cond_wait(&empty, &monitor);
        buffer[fill] = element;
        fill = (fill + 1) % MAX;
        fullEntries++;
        pthread_cond_signal(&full);
        pthread_mutex_unlock(&monitor);
    }

    int consume() {
        pthread_mutex_lock(&monitor);
        while (fullEntries == 0)
            pthread_cond_wait(&full, &monitor);
        int tmp = buffer[use];
        use = (use + 1) % MAX;
        fullEntries--;
        pthread_cond_signal(&empty);
        pthread_mutex_unlock(&monitor);
        return tmp;
    }
};
```

*图 D.9：带“管程”的 C++ 生产者/消费者。*

它与假想管程差别不大，最明显的是显式使用锁 `monitor`，以及换成 POSIX 标准的 `pthread_cond_signal()` 与 `pthread_cond_wait()`。调用 `pthread_cond_wait()` 时必须传入当前持有的锁，因为函数在让线程睡眠时要释放它，在返回调用者前又要重新获得它。这与管程内部行为相同，只是锁不再隐形。

### Java 管程

Java 设计者认为管程是把同步原语优雅加入语言的方式。只需给希望属于管程的方法加 `synchronized`：

```java
public class SynchronizedCounter {
    private int c = 0;

    public synchronized void increment() {
        c++;
    }

    public synchronized void decrement() {
        c--;
    }

    public synchronized int value() {
        return c;
    }
}
```

*图 D.10：带同步方法的简单 Java 类。*

它提供线程安全计数器。任意时刻只允许一个线程进入管程，因此只有一个线程能更新 `c`，竞态被挡在门外。

### Java 与单个条件变量

早期 Java 为每个同步类只提供一个条件变量，通过 `wait()` 和 `notify()` 使用；`notify` 与 `signal` 只是不同叫法。奇怪的是，它无法创建两个或更多条件变量，而生产者/消费者通常需要两个：一个表示缓冲区已腾空，一个表示已经填入数据。

设只有一个条件变量：两个消费者先运行并等待；生产者填满容量为 1 的缓冲区，唤醒一个消费者，然后再次尝试生产，却因缓冲区已满而等待。此时有一个生产者等待空缓冲区，一个消费者等待满缓冲区，另一个被唤醒的消费者准备运行。

后者消费缓冲区，再调用 `notify()`。由于只有一个条件变量，它可能唤醒等待中的消费者，而非真正需要唤醒的生产者。于是方案失效。

补救办法仍是广播：Java 中调用 `notifyAll()` 唤醒全部线程。消费者与生产者都醒来；消费者发现 `fullEntries == 0` 后重新睡眠，生产者继续。当然，全部唤醒也会带来惊群问题。

为弥补缺陷，Java 后来加入显式 `Condition` 类，使这类并发问题能有更高效的解法。

## D.9 总结

管程由 Brinch Hansen 在 20 世纪 70 年代初提出，随后由 Hoare 完善。线程在管程内运行时隐式持有管程锁，阻止其他线程同时进入，因此很容易构造互斥。

管程还引入显式条件变量，让线程像使用信号量一样 `signal()` 和 `wait()`。二者语义极其关键：现代系统都实现 Mesa 语义，所以线程醒来后必须重新检查让它睡眠的条件。`signal()` 只提示“某些东西变了”；醒来的线程有责任确认当前条件确实适合继续执行。

C++ 没有原生管程，但可用显式 pthread 锁与条件变量模拟；Java 则以 `synchronized` 方法支持管程，同时早期“每个对象只有一个条件变量”的设计也暴露了局限。

## 参考资料

- **[BH73]** Per Brinch Hansen, *Operating System Principles*, Prentice-Hall, 1973. 最早的操作系统书籍之一，远远领先于时代；把管程作为并发原语引入。
- **[H74]** C. A. R. Hoare, “Monitors: An Operating System Structuring Concept,” *CACM*, 17(10), 1974. 管程的早期经典资料，不过真正的发明者很可能是 Brinch Hansen。
- **[H61]** C. A. R. Hoare, “Quicksort: Algorithm 64,” *CACM*, 4(7), 1961. 著名的快速排序算法。
- **[LR80]** B. W. Lampson, D. R. Redell, “Experience with Processes and Monitors in Mesa,” *CACM*, 23(2), 1980. 强调理论与实践差异的一篇早期重要论文。
- **[L83]** Butler Lampson, “Hints for Computer Systems Design,” *ACM Operating Systems Review*, 15(5), 1983. Lampson 喜欢在系统设计中使用提示。提示通常正确，却也可能出错；这里 `signal()` 告诉等待线程条件改变了，却不能保证它醒来时仍满足。Lampson 在一篇讲系统设计提示的论文里给出的通用提示之一，就是“使用提示”。没听起来那么绕，真的。
- **[S12a]** Sun documentation, “Synchronized Methods.” Java 同步方法文档。
- **[S12b]** Sun documentation, “Condition Interface.” Java `Condition` 接口文档。
