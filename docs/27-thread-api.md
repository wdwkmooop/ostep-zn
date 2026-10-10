# 第 27 章 插曲：线程 API

> 英文原题：*Interlude: Thread API*

本章简要介绍线程 API 的主要部分。后续章节会在展示 API 用法时进一步解释各个部分。更多细节可查阅书籍和在线资料 [B89, B97, B+96, K+96]。要说明的是，后面的章节会放慢脚步，用大量例子引入锁和条件变量；所以本章更适合当参考手册来用。

!!! danger "问题核心：如何创建并控制线程"
    操作系统应该提供哪些接口来创建和控制线程？这些接口该怎样设计，才能既好用又实用？

## 27.1 创建线程

编写多线程程序，首先得能创建新线程，因此必须有某种线程创建接口。在 POSIX 中，这很简单：

```c
#include <pthread.h>
int
pthread_create(      pthread_t *      thread,
              const pthread_attr_t * attr,
                    void *           (*start_routine)(void *),
                    void *           arg);
```

这个声明看起来有点复杂——尤其当你没用过 C 函数指针时——其实没有多吓人。它有四个参数：`thread`、`attr`、`start_routine` 和 `arg`。

第一个参数 `thread` 是指向 `pthread_t` 类型结构的指针。以后要靠这个结构与线程互动，所以把它传给 `pthread_create()`，由后者完成初始化。

第二个参数 `attr` 指定线程属性，例如栈大小、调度优先级等。属性要另行调用 `pthread_attr_init()` 初始化，细节请查手册页。不过，大多数时候默认属性就够了，这时直接传 `NULL`。

第三个参数最复杂，但它其实只是在问：这条线程应该从哪个函数开始运行？在 C 中，这叫函数指针。这里要求 `start_routine` 指向这样一个函数：接收一个 `void *` 参数，也返回一个 `void *`。

如果例程接收整数而不是 void 指针，声明会像这样：

```c
int pthread_create(..., // 前两个参数相同
                   void * (*start_routine)(int),
                   int      arg);
```

若例程接收 void 指针、返回整数，则像这样：

```c
int pthread_create(..., // 前两个参数相同
                   int    (*start_routine)(void *),
                   void * arg);
```

最后，第四个参数 `arg` 就是传给线程入口函数的参数。为什么要用 void 指针？答案很简单：入口函数接收 `void *`，就能传入任意类型的参数；它返回 `void *`，线程也就能返回任意类型的结果。

看看图 27.1。我们创建一条线程，把两个参数打包进自定义的 `myarg_t` 类型。线程启动后，只需把参数强制转换为预期类型，再按需拆包。

```c linenums="1"
#include <pthread.h>

typedef struct __myarg_t {
    int a;
    int b;
} myarg_t;

void *mythread(void *arg) {
    myarg_t *m = (myarg_t *) arg;
    printf("%d %d\n", m->a, m->b);
    return NULL;
}

int
main(int argc, char *argv[]) {
    pthread_t p;
    int rc;

    myarg_t args;
    args.a = 10;
    args.b = 20;
    rc = pthread_create(&p, NULL, mythread, &args);
    ...
}
```

*图 27.1：创建一条线程。*

这就成了！线程一创建，程序里便多出一个活生生的执行实体。它有自己的调用栈，却与程序中已有的所有线程运行在同一个地址空间里。好戏开场了！

## 27.2 线程结束

上例展示了怎样创建线程。可如果你想等它结束呢？这就得做点特别的事：调用 `pthread_join()`。

```c
int pthread_join(pthread_t thread, void **value_ptr);
```

这个例程接收两个参数。第一个参数类型为 `pthread_t`，指定要等待哪条线程。线程创建例程会初始化这个变量（因为调用 `pthread_create()` 时传入了它的地址）；只要把它留下，就能用来等待相应线程终止。

第二个参数指向你期待拿到的返回值。线程例程可能返回任何东西，因此它返回 void 指针；而 `pthread_join()` 要修改传入参数的值，所以必须传指向该值的指针，而非值本身。

再看一个例子：

```c linenums="1"
#include <stdio.h>
#include <pthread.h>
#include <assert.h>
#include <stdlib.h>

typedef struct __myarg_t {
    int a;
    int b;
} myarg_t;

typedef struct __myret_t {
    int x;
    int y;
} myret_t;

void *mythread(void *arg) {
    myarg_t *m = (myarg_t *) arg;
    printf("%d %d\n", m->a, m->b);
    myret_t *r = Malloc(sizeof(myret_t));
    r->x = 1;
    r->y = 2;
    return (void *) r;
}

int
main(int argc, char *argv[]) {
    pthread_t p;
    myret_t *m;

    myarg_t args = {10, 20};
    Pthread_create(&p, NULL, mythread, &args);
    Pthread_join(p, (void **) &m);
    printf("returned %d %d\n", m->x, m->y);
    free(m);
    return 0;
}
```

*图 27.2：等待线程结束。*

代码再次创建一条线程，通过 `myarg_t` 结构传入两个参数，并用 `myret_t` 返回结果。线程结束后，一直等在 `pthread_join()` 里的主线程返回，便能访问线程返回的 `myret_t` 内容[^1]。

[^1]: 这里使用了包装函数：`Malloc()`、`Pthread_join()` 和 `Pthread_create()`。它们只是调用名字相近的小写版本，并确保例程没有返回意外结果。

这个例子有几点值得注意。第一，通常不必如此费劲地打包、拆包。创建不带参数的线程时，可以给创建调用传 `NULL`；不关心返回值时，也可以给 `pthread_join()` 传 `NULL`。

第二，如果只传一个值（例如 `int`），也不必把它塞进结构。图 27.3 更简单，参数和返回值都不用结构打包：

```c
void *mythread(void *arg) {
    int m = (int) arg;
    printf("%d\n", m);
    return (void *) (arg + 1);
}

int main(int argc, char *argv[]) {
    pthread_t p;
    int rc, m;
    Pthread_create(&p, NULL, mythread, (void *) 100);
    Pthread_join(p, (void **) &m);
    printf("returned %d\n", m);
    return 0;
}
```

*图 27.3：向线程传递参数的简单方法。*

第三，线程返回值必须极其小心。尤其要牢记：**绝不要返回指向线程调用栈中某个对象的指针**。真这么干，会发生什么？想想看！下面就是一段危险代码：

```c linenums="1"
void *mythread(void *arg) {
    myarg_t *m = (myarg_t *) arg;
    printf("%d %d\n", m->a, m->b);
    myret_t r; // 分配在线程栈上：糟糕！
    r.x = 1;
    r.y = 2;
    return (void *) &r;
}
```

变量 `r` 分配在 `mythread` 的线程栈上。函数返回时，这块空间会自动回收——栈之所以好用，不正因为如此吗？所以返回一个指向已回收变量的指针，只会招来各种坏结果。等你打印自以为返回的值时，多半（但也不一定！）会大吃一惊。亲手试试就知道了[^2]。

[^2]: 幸好，写出这种代码时，`gcc` 很可能会发出警告。这也是为什么编译器警告千万别当耳旁风。

最后，你或许发现：调用 `pthread_create()` 创建线程，紧接着立刻 `pthread_join()`，实在是种古怪做法。完成一模一样的任务其实有个更简单的办法，叫“过程调用”。显然，我们通常会创建多条线程再等待它们完成；否则，用线程还有什么意义？

也不是所有多线程代码都使用 `join`。例如，多线程 Web 服务器可以创建一批工作线程，再让主线程无限期地接收请求、分发给它们；这种长寿程序可能根本不需要 `join`。但为某项具体任务创建线程并行处理的程序，多半会用 `join` 确保所有工作完成，再退出或进入下一计算阶段。

## 27.3 锁

除了线程创建和等待，POSIX 线程库里大概最有用的下一组函数，就是通过锁为临界区提供互斥。最基本的一对例程是：

```c
int pthread_mutex_lock(pthread_mutex_t *mutex);
int pthread_mutex_unlock(pthread_mutex_t *mutex);
```

它们应该很好懂。某段代码是临界区，需要保护才能正确工作时，锁就派上用场了：

```c
pthread_mutex_t lock;
pthread_mutex_lock(&lock);
x = x + 1; // 或任何其他临界区代码
pthread_mutex_unlock(&lock);
```

其意图是：调用 `pthread_mutex_lock()` 时，若没有其他线程持锁，当前线程就获取锁并进入临界区。若锁已被占用，试图获取锁的线程不会从调用返回，而会一直等到成功拿锁——也就意味着持锁线程已经调用 `unlock` 释放了它。任一时刻，可能有许多线程卡在获取锁的函数里等待；但只有真正拿到锁的线程才应该调用 `unlock`。

可惜，这段代码在两个重要方面是坏的。

第一个问题是没有正确初始化。所有锁都必须初始化，才能保证起始值正确，让 `lock` 和 `unlock` 按预期工作。POSIX 线程有两种初始化方式。一种使用静态初始化器：

```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
```

这会把锁设为默认值，使其可用。另一种是运行时动态初始化：

```c
int rc = pthread_mutex_init(&lock, NULL);
assert(rc == 0); // 永远检查是否成功！
```

第一个参数是锁本身的地址，第二个是可选属性集合；传 `NULL` 就使用默认值。两种方式都行，但我们通常使用后一种动态方式。用完锁后，还应对应调用 `pthread_mutex_destroy()`；全部细节请查手册页。

第二个问题是，代码调用加锁和解锁例程时没有检查错误码。就像 UNIX 上几乎所有库例程一样，它们也可能失败！不检查，失败就会悄无声息，甚至可能放任多条线程一起闯进临界区。最低限度，也要用包装函数断言调用成功（图 27.4）。更成熟的非玩具程序不能一出错就退出，则应检查失败，并在加锁或解锁失败时妥善处理。

```c
// 保持代码整洁，同时检查失败
// 仅适用于失败后可以直接退出的程序
void Pthread_mutex_lock(pthread_mutex_t *mutex) {
    int rc = pthread_mutex_lock(mutex);
    assert(rc == 0);
}
```

*图 27.4：包装函数示例。*

Pthreads 库还提供了另外两个可能有用的获取锁例程：

```c
int pthread_mutex_trylock(pthread_mutex_t *mutex);
int pthread_mutex_timedlock(pthread_mutex_t *mutex,
                            struct timespec *abs_timeout);
```

锁已被占用时，`trylock` 立即返回失败；`timedlock` 则在超时或拿到锁时返回，以先发生者为准。因此，超时时间设为 0 的 `timedlock` 就退化成了 `trylock`。通常应避免使用这两个版本；不过某些场景下，避免无限卡在获取锁的例程里确实有用，后面研究死锁时会看到例子。

## 27.4 条件变量

任何线程库的另一大组件——POSIX 线程也不例外——是**条件变量(condition variable)**。一条线程必须等另一条线程完成某件事才能继续时，就需要在线程之间发送信号，条件变量正适合这种场景。两个主要例程是：

```c
int pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex);
int pthread_cond_signal(pthread_cond_t *cond);
```

使用条件变量时，还必须有一把与条件关联的锁。调用上述任一例程时，都应持有这把锁。

`pthread_cond_wait()` 让调用线程睡眠，等待另一条线程发来信号；通常，信号表示程序中某种睡眠线程关心的状态发生了变化。典型写法如下：

```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;

Pthread_mutex_lock(&lock);
while (ready == 0)
    Pthread_cond_wait(&cond, &lock);
Pthread_mutex_unlock(&lock);
```

初始化锁和条件变量后[^3]，线程检查 `ready` 是否已经非零；若仍为 0，就调用等待例程睡眠，直到别的线程唤醒它。另一条线程中的唤醒代码如下：

[^3]: 也可以不用静态初始化器 `PTHREAD_COND_INITIALIZER`，改为调用 `pthread_cond_init()`，用完再对应调用 `pthread_cond_destroy()`。听起来更费事？没错，就是更费事。

```c
Pthread_mutex_lock(&lock);
ready = 1;
Pthread_cond_signal(&cond);
Pthread_mutex_unlock(&lock);
```

这段代码有几点需要留意。第一，发送信号（以及修改全局变量 `ready`）时，我们始终确保自己持有锁，以免不小心引入竞争条件。

第二，`wait` 接收锁作为第二个参数，`signal` 却只接收条件。这是因为 `wait` 不但让调用线程睡眠，还会在睡眠时释放锁。若它不放锁，另一条线程怎么拿到锁并发信号唤醒它？而线程醒来、`pthread_cond_wait()` 返回之前，例程会重新获取锁。因此，从等待序列开头拿锁，到末尾放锁，只要等待线程正在运行，它就始终持锁。

最后一个怪点：等待线程用 `while` 循环重新检查条件，而不是简单的 `if`。后面学习条件变量时会细讲；总体而言，用 `while` 最简单也最安全。重复检查或许有一点开销，但某些 pthread 实现可能让等待线程**虚假唤醒(spurious wakeup)**；若不复查，线程会误以为条件已改变。把唤醒当作“某些东西**也许**变了”的提示，而非板上钉钉的事实，更安全。

有时，人们会忍不住用简单标志代替条件变量和关联锁，让线程这样等待：

```c
while (ready == 0)
    ; // 自旋
```

发送信号只写一句：

```c
ready = 1;
```

千万别这么做。第一，许多情况下性能很差——长时间自旋纯属浪费 CPU 周期。第二，它很容易出错。研究表明 [X+10]，用这类标志在线程间同步，犯错容易得惊人；那项研究中，大约一半临时拼凑的同步代码都有 bug！别偷懒，即使觉得不用条件变量也能混过去，也请老老实实使用它。

如果条件变量听起来让人犯晕，暂时别太担心。后面有整章内容详细讨论它。眼下，知道它存在，并大致理解为何、怎样使用，就够了。

## 27.5 编译和运行

本章所有代码都很容易跑起来。编译时，代码必须包含头文件 `pthread.h`；链接时还要添加 `-pthread`，明确链接 pthreads 库。例如：

```console
prompt> gcc -o main main.c -Wall -pthread
```

只要 `main.c` 包含 pthreads 头文件，你现在就成功编译出了一个并发程序。至于它能不能正确工作——照例，那完全是另一回事。

## 27.6 小结

我们介绍了 pthread 库的基础：创建线程、用锁实现互斥，以及用条件变量发信号和等待。要写出健壮、高效的多线程代码，除此之外并不需要多少东西——只要再加上耐心，以及十二万分的小心！

如果还想了解 API 的其他有趣角落，在 Linux 上输入 `man -k pthread`，就能看到构成完整接口的一百多个 API。不过，本章这些基础已经足够让你构建复杂——希望也正确、高效——的多线程程序。线程真正难的并不是 API，而是构造并发程序那弯弯绕绕的逻辑。继续读吧。

!!! note "边栏：线程 API 指南"
    用 POSIX 线程库（其实任何线程库都一样）构建多线程程序时，要记住几件看似细小却很重要的事：

    - **保持简单。** 最重要的是，线程间加锁或发信号的代码越简单越好。炫技容易翻车。
    - **尽量减少线程互动。** 让线程互动的方式越少越好。每次互动都必须仔细推敲，并用久经考验的成熟方法构造——后面几章会学到其中许多。
    - **初始化锁和条件变量。** 忘了这件事，代码就会时灵时不灵，还坏得莫名其妙。
    - **检查返回码。** 写任何 C 和 UNIX 程序都应该检查每一个返回码，这里也一样。否则，代码会踏上奇幻漂流，让你很可能（a）尖叫，（b）薅掉几缕头发，或（c）两者都来。
    - **小心线程参数和返回值。** 尤其是，只要你在传递一个栈上变量的引用，就很可能已经写出了 bug。
    - **每条线程都有自己的栈。** 一条线程所执行函数中的局部变量，本质上归它私有，其他线程没法轻易访问。要在线程间共享数据，必须把值放在堆上或其他全局可访问的位置。
    - **线程间发信号始终使用条件变量。** 用简单标志似乎很诱人，但别那么干。
    - **阅读手册页。** 尤其在 Linux 上，pthread 手册页信息极丰富，往往比这里还细。认真读！

## 参考文献

- [B89] “An Introduction to Programming with Threads” by Andrew D. Birrell. DEC Technical Report, January 1989. Available: <https://birrell.org/andrew/papers/035-Threads.pdf>. 一篇经典但稍显年长的线程编程入门，至今值得一读，而且免费。
- [B97] *Programming with POSIX Threads* by David R. Butenhof. Addison-Wesley, May 1997. 又一本讲线程的书。
- [B+96] *PThreads Programming: A POSIX Standard for Better Multiprocessing* by Dick Buttlar, Jacqueline Farrell, Bradford Nichols. O'Reilly, September 1996. 出自优秀、务实的 O'Reilly，内容靠谱。我们的书架上当然也摆满了这家出版社的书，包括一些很棒的 Perl、Python 和 JavaScript 著作（尤其 Crockford 的 *JavaScript: The Good Parts*）。
- [K+96] *Programming With Threads* by Steve Kleiman, Devang Shah, Bart Smaalders. Prentice Hall, January 1996. 大概是这一领域更好的书之一。去本地图书馆借一本吧，或者从你妈那儿偷一本。说正经的，直接开口问她——放心，她会借给你的。
- [X+10] “Ad Hoc Synchronization Considered Harmful” by Weiwei Xiong, Soyeon Park, Jiaqi Zhang, Yuanyuan Zhou, Zhiqiang Ma. OSDI 2010, Vancouver, Canada. 这篇论文展示了貌似简单的同步代码能引发多么惊人的 bug 数量。请使用条件变量，并正确发送信号！

## 作业（代码）

本作业会编写一些简单的多线程程序，并用名为 `helgrind` 的工具查找其中的问题。构建程序和运行 `helgrind` 的细节，请阅读作业下载包里的 `README`。

1. 先构建 `main-race.c`。检查代码，找出其中（希望相当明显）的数据竞争。运行 `valgrind --tool=helgrind main-race`，看看 `helgrind` 怎样报告竞争。它指出了正确的代码行吗？还提供了哪些信息？
2. 删除其中一行肇事代码会怎样？接着，只给共享变量的一处更新加锁，再给两处都加锁。每种情况下 `helgrind` 分别报告什么？
3. 查看 `main-deadlock.c`。代码存在一种叫**死锁(deadlock)** 的问题（后面有一章深入讨论）。你能看出可能出什么问题吗？
4. 对这段代码运行 `helgrind`。它报告了什么？
5. 对 `main-deadlock-global.c` 运行 `helgrind`。检查代码：它和 `main-deadlock.c` 有同样的问题吗？`helgrind` 应该报告同一种错误吗？这告诉了你 `helgrind` 之类的工具有什么局限？
6. 查看 `main-signal.c`。代码用变量 `done` 表示子线程已经结束、父线程可以继续。为什么它效率很低？尤其当子线程要很久才能完成时，父线程把时间花在了什么上？
7. 对该程序运行 `helgrind`。它报告什么？代码正确吗？
8. 再看稍加修改的 `main-signal-cv.c`。这个版本用条件变量（和关联锁）发送信号。为什么它比前一版好？是正确性、性能，还是两者都更好？
9. 再次对 `main-signal-cv` 运行 `helgrind`。它报告了错误吗？
