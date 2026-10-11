# 附录 F 实验：教程

> 英文原题：*Laboratory: Tutorial*

这是一篇很短的教程，帮助你熟悉 UNIX 系统上 C 编程环境的基础。它既不全面，也不特别详细，只求给你足够的知识，好让你先跑起来。

关于编程，先送上几条通用建议。想成为专家，光掌握语言语法不够；你还得了解工具、库和文档。与 C 编译有关的工具包括 `gcc`、`gdb`，也许还有 `ld`。可用的库例程多得惊人，好在大量功能都位于默认链接到每个 C 程序的 `libc`，通常只需包含正确的头文件。最后，学会寻找所需库例程——例如查找、阅读 man 手册页——也是值得掌握的技能。

就像人生中（几乎）所有值得做的事一样，精通这些领域需要时间。提前花时间熟悉工具和环境，绝对物有所值。

## F.1 一个简单的 C 程序

从一个简单程序开始，把它保存为 `hw.c`。与 Java 不同，C 的文件名不一定与文件内容存在强制联系；请动用常识，给文件起个合适名字。

```c
/* 头文件放在这里 */
/* C 注释包围在斜杠和星号之间，
   可以跨越多行 */
// 使用 gcc 时，双斜杠也有效，而且也许更方便
#include <stdio.h>

/* main 返回一个整数 */
int main(int argc, char *argv[]) {
    /* printf 是输出函数，默认写到标准输出 */
    /* printf 会返回整数，不过这里忽略它 */
    printf("hello, world\n");

    /* 返回 0，表示一切正常 */
    return(0);
}
```

第一行包含 `stdio.h`，其中声明了许多常用输入/输出例程，这里需要的是 `printf()`。`#include` 指示 C 预处理器 `cpp` 找到指定文件，并把内容原样插入指令所在位置。默认情况下，`cpp` 会到 `/usr/include/` 查找。

`main()` 返回 `int`，接收两个参数：整数 `argc` 是命令行参数数量；字符指针数组 `argv` 的每一项保存命令行中的一个词，最后一项为 `null`。指针和数组以后再谈。

程序打印 `hello, world`；字符串末尾的反斜杠加 `n` 让输出换到下一行。随后返回一个值给启动它的 shell。脚本或终端用户可检查该值，判断程序正常退出还是出错；在 `csh`、`tcsh` 中，它保存在 `status` 变量里。

## F.2 编译与执行

下面编译程序。这里以 `gcc` 为例，有些平台也可使用原生编译器 `cc`：

```console
prompt> gcc hw.c
```

严格说，`gcc` 不是编译器本体，而是**编译器驱动程序(compiler driver)**，负责协调四五个编译步骤：

1. 运行 C 预处理器 `cpp`，处理 `#define`、`#include` 等指令。它只是源到源转换器，输出仍是 C 源代码。
2. 真正的编译器（通常叫 `cc1`）把 C 转换为针对宿主机器的低级汇编。
3. 汇编器 `as` 生成目标代码，也就是机器真正能懂的那些位与零碎东西。
4. 链接编辑器 `ld` 把一切组合成最终可执行程序。

幸好，对多数用途，你完全可以快活地不知道 `gcc` 内部怎样工作，只要给它正确参数即可。

上述命令默认生成可执行文件 `a.out`，运行它：

```console
prompt> ./a.out
```

操作系统会设置 `argc` 与 `argv`。这里 `argc` 等于 1，`argv[0]` 是字符串 `"./a.out"`，`argv[1]` 为 `null`，表示数组结束。

## F.3 实用参数

在继续学习 C 之前，先认识一些有用的 `gcc` 参数：

```console
prompt> gcc -o hw hw.c     # -o：指定可执行文件名
prompt> gcc -Wall hw.c     # -Wall：给出更完善的警告
prompt> gcc -g hw.c        # -g：加入供 gdb 使用的调试信息
prompt> gcc -O hw.c        # -O：开启优化
```

这些参数可以组合，例如：

```console
prompt> gcc -o hw -g -Wall hw.c
```

其中应始终使用 `-Wall`，它会对潜在错误发出大量额外警告。别无视警告！修掉它们，让它们幸福地消失。

## F.4 链接库

程序有时需要库例程。很多例程位于每个程序都会自动链接的 C 库中，通常只需找到正确的 `#include` 文件。最好的办法是查看手册页(man page)。

例如要使用 `fork()` 系统调用，在 shell 输入 `man fork`，便会看到工作方式说明。页面顶部的简短代码会告诉你要包含哪些文件。`fork()` 需要：

```c
#include <sys/types.h>
#include <unistd.h>
```

> `fork()` 是系统调用，不只是普通库例程。不过，C 库为所有系统调用提供 C 包装函数，它们只负责 trap 进入操作系统。

有些例程不在 C 库里，需要多做一步。例如数学库包含正弦、余弦、正切等函数。Linux 的 `tan()` 手册页顶部会写：

```text
#include <math.h>
...
Link with -lm.
```

第一行表示包含 `/usr/include/math.h`。第二行说明程序还必须与数学库链接。许多库位于 `/usr/lib`。

库有两类：

- **静态链接库**以 `.a` 结尾，链接器把库的低级代码直接塞进可执行文件，二进制因而变大。
- **动态链接库**以 `.so` 结尾，可执行文件只保存引用，程序运行时由操作系统加载器动态链接。

动态链接通常更受欢迎，因为它节省磁盘空间，也让应用在内存中共享库代码和静态数据。数学库两种版本都有：`/usr/lib/libm.a` 与 `/usr/lib/libm.so`。

链接数学库：

```console
prompt> gcc -o hw hw.c -Wall -lm
```

`-lXXX` 告诉链接器查找 `libXXX.so` 或 `libXXX.a`，大概按这个顺序。若你坚持静态链接，也有参数可用——看看能否自己找出来。有人偏爱静态库，是因为动态库有一点性能成本。

若希望编译器在其他目录查找头文件，用 `-I/foo/bar`；在其他目录查找库，用 `-L/foo/bar`。常见目录 `.`（读作 dot）是 UNIX 对当前目录的简写。`-I` 应放在编译命令行，`-L` 放在链接命令行。

## F.5 分别编译

程序变大后，可以拆成多个文件，分别编译，再链接。例如有 `hw.c` 和 `helper.c`：

```console
# 用 -Wall 显示警告，用 -O 优化
prompt> gcc -Wall -O -c hw.c
prompt> gcc -Wall -O -c helper.c
prompt> gcc -o hw hw.o helper.o -lm
```

`-c` 只生成目标文件，这里是 `hw.o` 和 `helper.o`。它们不是可执行程序，只是各源文件的机器级表示。第三行把目标文件链接成可执行程序。`gcc` 看见输入是 `.o` 而非 `.c`，便跳过前面步骤，直接调用 `ld`。

第三行通常称为**链接行(link line)**，`-lm` 等链接参数放在这里；`-Wall`、`-O` 只作用于编译阶段，因此只需出现在编译行。

当然，也能一行完成：

```console
prompt> gcc -Wall -O -o hw hw.c helper.c
```

但这样每次都会重新编译全部源文件，大项目会很耗时。分别编译只需重编修改过的文件，能提高生产率。管理这一过程的最佳工具是 `make`。

## F.6 Makefile

`make` 自动完成大部分构建过程，是严肃程序——以及严肃程序员——不可缺少的工具。先看名为 `Makefile` 的简单例子：

```make
hw: hw.o helper.o
	gcc -o hw hw.o helper.o -lm

hw.o: hw.c
	gcc -O -Wall -c hw.c

helper.o: helper.c
	gcc -O -Wall -c helper.c

clean:
	rm -f hw.o helper.o hw
```

构建程序只需：

```console
prompt> make
```

它默认查找 `Makefile` 或 `makefile`；也可以用参数指定别的文件，请自行翻手册。GNU 版 `gmake` 比传统 `make` 功能更全，下面以它为准，但混用两个名称。在 Linux 上，`gmake` 与 `make` 本就是同一个程序。

Makefile 由**规则(rule)**组成，一般形式为：

```make
target: prerequisite1 prerequisite2 ...
	command1
	command2
	...
```

- **目标(target)**通常是程序生成的文件，例如可执行文件或目标文件，也可以是 `clean` 这样的动作名。
- **前置条件(prerequisite)**是生成目标所需的输入文件；一个目标可以依赖多个文件。
- **命令(command)**是 `make` 要执行的动作，每条单独一行。

重要：每条命令开头必须是一个真正的制表符！若只放空格，`make` 会吐出某条晦涩错误然后离场，留下你和键盘面面相觑。

命令通常在前置条件变化时重新生成目标，但规则也可以没有前置条件，例如 `clean`。

运行 `make` 时，它先看到目标 `hw` 依赖 `hw.o`、`helper.o`，于是检查二者。`hw.o` 又依赖 `hw.c`；若 `hw.c` 修改时间晚于 `hw.o`，目标已过期，`make` 便执行 `gcc -O -Wall -c hw.c` 重新生成。若 `hw.o` 根本不存在，也会创建它。`helper.o` 同理。两个目标文件准备好后，再执行 `gcc -o hw hw.o helper.o -lm` 生成最终程序。

要执行没有前置条件的清理目标，必须明确指定：

```console
prompt> make clean
```

这会删除目标文件和可执行程序，方便从头重建。

你也许会想：“还行，不过 Makefile 写起来真麻烦！”没错——如果永远只能这么写的话。幸好 `make` 有大量简写。下面的版本功能相同，却更方便扩展：

```make
# 在此列出全部源文件
SRCS = hw.c helper.c
# 目标，也就是可执行文件名
TARG = hw
# 编译器、编译参数和所需库
CC   = gcc
OPTS = -Wall -O
LIBS = -lm
# 把源文件列表中的 .c 转换成 .o
OBJS = $(SRCS:.c=.o)

# all 并非必需，但可用来生成目标
all: $(TARG)

# 生成目标可执行文件
$(TARG): $(OBJS)
	$(CC) -o $(TARG) $(OBJS) $(LIBS)

# 生成 .o 文件的通用规则
%.o: %.c
	$(CC) $(OPTS) -c $< -o $@

# 最后是清理规则
clean:
	rm -f $(OBJS) $(TARG)
```

虽然这里不深入 `make` 语法，但好处已经可见：向 `SRCS` 添加文件即可纳入构建；修改 `TARG` 就能换可执行文件名；编译器、参数和库也很容易调整。

最后，判断目标的全部前置条件在大型程序中并不容易。果不其然，还有一个工具专门帮忙：`makedepend`。请自行了解，并试着把它加入 Makefile。

## F.7 调试

构建环境已经不错，程序也正确编译，可它仍可能有 bug。一种修复办法是使劲思考——偶尔成功，往往不行。问题在于信息不足：你不知道程序内部究竟发生了什么。幸好还有 GNU 调试器 `gdb`。

把下面的错误代码保存为 `buggy.c`，编译为 `buggy`：

```c
#include <stdio.h>

struct Data {
    int x;
};

int main(int argc, char *argv[]) {
    struct Data *p = NULL;
    printf("%d\n", p->x);
}
```

程序在 `p` 为 `NULL` 时解引用它，会导致段错误。这个例子肉眼就能修，复杂程序中却未必这么明显。

调试前重新编译，并在每条编译命令上加入 `-g`，把额外调试信息写进程序。不要开启 `-O`；优化后也许仍能调试，却容易让现象与源码对不上。

启动调试器：

```console
prompt> gdb buggy
```

这会进入交互会话。`gdb` 还可以检查错误运行生成的 core 文件，或附加到已经运行的程序；详情请读文档。

```console
prompt> gdb buggy
GNU gdb ...
Copyright 2008 Free Software Foundation, Inc.
(gdb)
```

在 `(gdb)` 提示符输入 `run`：

```console
(gdb) run
Starting program: buggy
Program received signal SIGSEGV, Segmentation fault.
0x8048433 in main (argc=1, argv=0xbffff844) at buggy.cc:19
19      printf("%d\n", p->x);
```

`gdb` 立即指出问题发生位置：解引用 `p` 的一行触发了段错误，也就是程序访问了不该访问的内存。敏锐的程序员此时会说：“啊哈！`p` 没指向有效对象，不能解引用！”然后修掉问题。

如果仍不明白，可以交互式查看变量：

```console
(gdb) print p
$1 = (Data *) 0x0
```

`print` 显示 `p` 是指向 `Data` 结构的指针，当前为 `NULL`，即十六进制的 `0x0`。

还可以设置断点，让程序在某个例程停止，再逐行执行：

```console
(gdb) break main
Breakpoint 1 at 0x8048426: file buggy.cc, line 17.
(gdb) run
Starting program: /homes/hacker/buggy

Breakpoint 1, main (argc=1, argv=0xbffff844) at buggy.cc:17
17      struct Data *p = NULL;
(gdb) next
19      printf("%d\n", p->x);
(gdb)
Program received signal SIGSEGV, Segmentation fault.
0x8048433 in main (argc=1, argv=0xbffff844) at buggy.cc:19
19      printf("%d\n", p->x);
```

断点设在 `main()`，运行后几乎立刻停住；`next` 执行下一条源码级命令。`next` 与 `step` 都可推进程序，区别请查文档。调试时还可使用交互式 `help`。

短短几段远远不足以体现 `gdb` 的实力。它功能丰富而灵活；请用你那多得用不完的空闲时间继续阅读，成为专家。

## F.8 文档

要深入掌握这些工具，必须做两件事：亲手使用，以及自己继续阅读。

### Man 手册页

输入 `man gcc`、`man gmake`、`man gdb` 查看手册。`man -k` 可按关键词搜索，不过效果未必总让人满意；如今搜索网页往往更好。

一个陷阱是：若同名条目不止一个，`man XXX` 可能给你错误的那个。例如查 `kill()` 系统调用，只输入 `man kill` 会先得到名为 `kill` 的命令行程序。手册分成不同章节，默认返回编号最小的匹配项。页顶显示 `kill(2)` 才表示位于存放系统调用的第 2 节。输入 `man man` 可了解各节内容；`man -a kill` 能依次浏览全部同名页面。

手册会说明库调用的参数、所需头文件等。例如 `open()`：

```text
SYNOPSIS
    #include <sys/types.h>
    #include <sys/stat.h>
    #include <fcntl.h>

    int open(const char *path, int oflag, /* mode_t mode */...);
```

它告诉你包含三个头文件，也列出路径字符串 `path`、整数标志 `oflag` 和可选文件模式参数。若还需链接某个库，手册也会注明。

手册需要一点练习才能高效使用。主体会说明不同参数怎样改变函数行为。特别有用的是 `RETURN VALUES`，它说明成功与失败时的返回值。`open()` 的相关内容是：

```text
RETURN VALUES
    成功时，open() 打开文件，并返回一个非负整数，
    它是编号最小的未使用文件描述符。否则返回 -1，
    设置 errno 指明错误，并且不会创建或修改文件。
```

检查返回值即可判断 `open()` 是否成功。失败时，`open()` 和许多标准库例程会设置全局变量 `errno`；详情见手册的 `ERRORS` 部分。

有时结构定义没有完整写在手册中。`gettimeofday()` 的概要是：

```c
#include <sys/time.h>

int gettimeofday(struct timeval *restrict tp,
                 void *restrict tzp);
```

时间被写入 `struct timeval`，但手册未必告诉你结构有哪些字段——这个例子里有，你未必次次这么走运。头文件都位于 `/usr/include`，可以用 `grep` 寻找：

```console
prompt> grep 'struct timeval' /usr/include/sys/*.h
```

它在 `/usr/include/sys` 下全部 `.h` 文件中搜索定义。不过目标头文件也许包含位于别处的其他文件，搜索可能失败。

更好的办法是让编译器帮忙。写一个包含 `time.h` 的 `main.c`，然后只运行预处理器：

```console
prompt> gcc -E main.c
```

输出是展开全部 `#define`、`#include` 后的 C 文件，其中包括 `timeval` 定义。

也许更好的查找办法是搜索网络。不懂的东西就去搜；仅仅查一下，能学到的东西多得惊人。

### Info 页面

GNU 工具的 info 页面通常比 man 更详细。运行 `info`，或在黑客钟爱的编辑器 Emacs 中执行 `Meta-x info` 即可访问。

`gcc` 有几百个参数，其中一些出人意料地有用；`gmake` 还有许多能改善构建环境的功能；`gdb` 更是一套相当老练的调试器。阅读 man 和 info，尝试没用过的功能，成为编程工具的高级用户。

## F.9 推荐阅读

除 man 与 info 页面外，还有一些实用书籍。很多资料可免费在线获得，但有时拿着一本书确实更容易学习。也可以优先寻找感兴趣主题的 O’Reilly 图书，它们几乎总是质量上乘。

- Brian Kernighan、Dennis Ritchie，*The C Programming Language*。C 语言必备的权威之作。
- Andrew Oram、Steve Talbott，*Managing Projects with make*。一本篇幅合理、简短的 `make` 书。
- Richard M. Stallman、Roland H. Pesch，*Debugging with GDB: The GNU Source-Level Debugger*。介绍 GDB 的小书。
- W. Richard Stevens、Steve Rago，*Advanced Programming in the UNIX Environment*。Stevens 写过多本杰作，这是 UNIX 黑客必读；他关于 TCP/IP 与套接字编程的系列也非常优秀。
- Peter Van der Linden，*Expert C Programming*。前面许多编译器技巧都直接从这里“偷”来的。读它！虽然稍显过时，仍是一本精彩而令人开眼的书。
