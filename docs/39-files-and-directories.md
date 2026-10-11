# 第 39 章 插叙：文件与目录

> 英文原题：*Interlude: Files and Directories*

到目前为止，我们已经见过操作系统的两种关键抽象：**进程(process)** 是 CPU 的虚拟化，**地址空间(address space)** 是内存的虚拟化。二者联手，让程序仿佛独占自己的处理器和内存，在一个私密、隔离的小世界里运行。这种幻觉大幅降低了编程难度，因此不仅桌面机和服务器爱用，手机等几乎所有可编程平台也都离不开它。

现在还要给虚拟化拼图补上关键一块：**持久化存储(persistent storage)**。传统硬盘或现代固态存储设备能永久——至少是很久——保存信息。内存一断电便失忆，持久化设备却会把数据留下；用户真正放在心尖上的数据通常就在这里，所以操作系统必须格外小心。

!!! danger "问题核心：怎样管理持久化设备"
    操作系统应怎样管理持久化设备？它应提供什么 API？实现中有哪些重要问题？

接下来几章将研究管理持久数据的关键技术，重点讨论性能与可靠性。不过先从 API 开始：看看与 UNIX 文件系统打交道时会遇到哪些接口。

## 39.1 文件与目录

存储虚拟化逐渐形成了两种核心抽象。第一种是**文件(file)**：它只是一段线性字节数组，其中每个字节都能读取或写入。每个文件都有某种底层名称，通常是一个数字，用户往往感觉不到它的存在。出于历史原因，这个底层名称常叫作 **inode 号(inode number)**。后面会深入研究 inode；眼下只需记住，每个文件都关联一个 inode 号。

多数系统并不知道文件内部是什么结构——图片、文本还是 C 代码，它通常不管。文件系统的职责只是把数据持久地存到磁盘上，并保证你日后取回的东西与当初放进去的一样。话说得轻巧，做起来可没那么轻巧。

第二种抽象是**目录(directory)**。目录也有底层名称（inode 号），但内容格式十分明确：一组“用户可读名称—底层名称”二元组。假设某文件的底层名称是 `10`，用户称它为 `foo`，那么 `foo` 所在目录中便有条目 `("foo", "10")`。目录项可以指向文件，也可以指向其他目录；目录层层嵌套，便形成任意的**目录树(directory tree)**或**目录层次结构(directory hierarchy)**。

```text
/
├── foo
│   └── bar.txt
└── bar
    ├── bar
    └── foo
        └── bar.txt
```

*图 39.1：一个目录树示例。*

目录层次从**根目录(root directory)**开始；在 UNIX 系统中，根目录就是 `/`。路径用分隔符逐级写出子目录，直到目标文件或目录。例如在 `/` 下创建目录 `foo`，再在其中创建 `bar.txt`，文件的**绝对路径名(absolute pathname)**便是 `/foo/bar.txt`。

图 39.1 中，有效目录是 `/`、`/foo`、`/bar`、`/bar/bar` 和 `/bar/foo`；有效文件是 `/foo/bar.txt` 与 `/bar/foo/bar.txt`。只要位置不同，文件和目录完全可以重名——图中就有两个 `bar.txt`，文件系统不会因此精神分裂。

!!! tip "认真考虑命名"
    命名是计算机系统的重要组成部分 [SK09]。在 UNIX 中，几乎一切都通过文件系统命名：除了普通文件，设备、管道，甚至进程 [K84] 都能出现在看似平平无奇的文件系统里。统一命名让系统的概念模型更简单、模块化程度更高。设计系统或接口时，请认真想想名字；名字不是最后随手贴上的便利贴。

示例文件名 `bar.txt` 看起来分为 `bar` 与 `txt` 两部分。前者是任意名称，后者通常表示文件类型，例如 `.c` 表示 C 源码、`.jpg` 表示图片、`.mp3` 表示音乐。但这一般只是约定：文件名叫 `main.c`，系统通常不会检查里面是不是 C 代码；你硬塞一首歌进去，它也只会默默看着。

因此，文件系统提供的一大好处，是以方便且统一的方式命名我们关心的资源。要访问资源，第一步总得先叫得出它的名字。在 UNIX 中，磁盘、U 盘、CD-ROM 和许多其他设备上的对象，都统一安放在一棵目录树下。

## 39.2 文件系统接口

下面更仔细地研究文件系统接口，从创建、访问和删除文件这些基本操作开始。你可能觉得它们平淡无奇，但途中会遇到一个名字神秘的删除调用 `unlink()`。到本章结束时，希望它不再像故意卖关子。

## 39.3 创建文件

最基本的操作是创建文件。程序调用 `open()` 并传入 `O_CREAT` 标志即可完成：

```c
int fd = open("foo", O_CREAT|O_WRONLY|O_TRUNC,
              S_IRUSR|S_IWUSR);
```

`open()` 接受多种标志。这里第二个参数表示：文件不存在时创建它（`O_CREAT`）；只允许写入（`O_WRONLY`）；文件已经存在时把长度截为 0，清除原有内容（`O_TRUNC`）。第三个参数指定权限，这里允许所有者读写。

!!! note "边栏：creat() 系统调用"
    较老的创建方式是：

    ```c
    int fd = creat("foo"); // 可再给第二个参数设置权限
    ```

    可以把 `creat()` 看成带有 `O_CREAT | O_WRONLY | O_TRUNC` 标志的 `open()`。既然 `open()` 自己也能创建文件，`creat()` 已经不大受宠，甚至完全可以做成一个调用 `open()` 的库函数。不过它在 UNIX 掌故中占有特殊位置。有人问 Ken Thompson：若重新设计 UNIX，他会改什么？他的回答是：“我会给 `creat` 补上那个 `e`。”

`open()` 最重要的返回值是**文件描述符(file descriptor)**。它只是一个进程私有的整数；打开文件后，只要权限允许，进程就用这个整数读写文件。文件描述符因此是一种**能力(capability)** [L84]：一个不透明句柄，持有它便获得执行特定操作的权力。也可以把它想成指向 `file` 对象的指针；拿到对象后，就能调用 `read()`、`write()` 等“方法”。

操作系统按进程管理文件描述符，因此 UNIX 的进程结构中会有数组之类的简单结构。下面是 xv6 内核中的相关片段 [CK+08]：

```c
struct proc {
    ...
    struct file *ofile[NOFILE]; // 打开的文件
    ...
};
```

这个最多容纳 `NOFILE` 个条目的数组，记录该进程打开了哪些文件。每项实际是指向 `struct file` 的指针，其中保存正在读写的文件信息。

## 39.4 读写文件

有了文件，自然要读写它。命令行上可以用 `cat` 把文件内容倾倒到屏幕：

```console
prompt> echo hello > foo
prompt> cat foo
hello
```

`echo` 的输出被重定向到 `foo`，于是文件中有了 `hello`。可 `cat` 究竟怎样访问它？Linux 上可以用极其好用的 `strace` 跟踪程序发出的系统调用；macOS 有 `dtruss`，一些老 UNIX 变体则有 `truss`。

!!! tip "使用 strace（以及类似工具）"
    `strace` 能让程序正在干什么无所遁形：它列出系统调用、参数和返回码。`-f` 会继续跟踪 `fork()` 出的子进程，`-t` 会记录调用时间，`-e trace=open,close,read,write` 则只跟踪列出的调用。它还有许多强大选项——去读手册页，好好利用这件神器。

删掉不相关的调用后，跟踪结果大致如下：

```console
prompt> strace cat foo
open("foo", O_RDONLY|O_LARGEFILE) = 3
read(3, "hello\n", 4096)           = 6
write(1, "hello\n", 6)            = 6
hello
read(3, "", 4096)                  = 0
close(3)                            = 0
```

`cat` 先以只读方式打开文件；`O_LARGEFILE` 表示使用 64 位偏移。调用成功并返回文件描述符 3。为什么不是 0 或 1？因为运行中的进程通常已经打开了三个文件：标准输入、标准输出和标准错误，描述符分别为 0、1、2。因此再打开的第一个文件十有八九拿到 3。

接着，`cat` 反复调用 `read()`。第一个参数是文件描述符，告诉系统要读哪一个文件；第二个参数指向存放结果的缓冲区；第三个参数是缓冲区大小，这里为 4 KB。返回值是实际读取的字节数：`hello` 五个字母加一个换行符，共 6 字节。

随后出现 `write(1, ...)`。描述符 1 是标准输出，所以文字出现在屏幕上。`cat` 可能直接调用 `write()`，也可能先调用 `printf()`；后者处理格式，最终仍会向标准输出写数据。

再次读取时已经到达文件末尾，`read()` 返回 0，`cat` 据此知道文件读完了，最后调用 `close(3)`。写文件的步骤类似：以写方式打开，调用一次或多次 `write()`，再 `close()`。可以用 `strace` 跟踪自己写的程序，或者观察 `dd if=foo of=bar`，亲眼看看。

## 39.5 非顺序读写

前面的访问都是从头到尾顺序进行。有时程序需要从文件中特定偏移处读写，例如为文本文档建立索引后，查找某个词可能要跳到随机位置。为此可用 `lseek()`：

```c
off_t lseek(int fildes, off_t offset, int whence);
```

第一个参数是文件描述符；第二个是偏移量；第三个参数因为历史原因叫 `whence`，决定偏移基准：

- `SEEK_SET`：当前偏移设为 `offset`。
- `SEEK_CUR`：当前偏移设为当前位置加 `offset`。
- `SEEK_END`：当前偏移设为文件长度加 `offset`。

每个打开的文件都有一个**当前偏移(current offset)**，决定下一次读写从哪里开始。它会以两种方式改变：读写 $N$ 字节后自动增加 $N$；或者由 `lseek()` 显式修改。

!!! note "数据结构：打开文件表"
    每个进程都有一张文件描述符数组，每个描述符指向系统级**打开文件表(open file table)**中的一项。该项记录它指向哪个底层文件、当前偏移，以及是否可读写等信息。

xv6 中简化后的 `struct file` 如下：

```c
struct file {
    int ref;
    char readable;
    char writable;
    struct inode *ip;
    uint off;
};
```

操作系统由此知道文件是否可读写、底层 inode 是谁、当前偏移是多少。`ref` 是稍后会用到的引用计数。系统中所有这些结构合称打开文件表；xv6 也简单地用数组保存它们：

```c
struct {
    struct spinlock lock;
    struct file file[NFILE];
} ftable;
```

看三个例子。首先，进程打开一个 300 字节文件，每次读取 100 字节：

| 系统调用 | 返回值 | 当前偏移 |
|---|---:|---:|
| `fd = open("file", O_RDONLY)` | 3 | 0 |
| `read(fd, buffer, 100)` | 100 | 100 |
| `read(fd, buffer, 100)` | 100 | 200 |
| `read(fd, buffer, 100)` | 100 | 300 |
| `read(fd, buffer, 100)` | 0 | 300 |
| `close(fd)` | 0 | — |

打开时偏移初始化为 0，每次读取后增加；越过文件末尾的读取返回 0。

第二个例子把同一文件打开两次。描述符 3、4 分别指向打开文件表中的不同项，因此偏移独立变化：

| 系统调用 | 返回值 | OFT[10] 偏移 | OFT[11] 偏移 |
|---|---:|---:|---:|
| `fd1 = open("file", O_RDONLY)` | 3 | 0 | — |
| `fd2 = open("file", O_RDONLY)` | 4 | 0 | 0 |
| `read(fd1, buffer1, 100)` | 100 | 100 | 0 |
| `read(fd2, buffer2, 100)` | 100 | 100 | 100 |
| `close(fd1)` | 0 | — | 100 |
| `close(fd2)` | 0 | — | — |

最后，进程在读取前重新定位：

| 系统调用 | 返回值 | 当前偏移 |
|---|---:|---:|
| `fd = open("file", O_RDONLY)` | 3 | 0 |
| `lseek(fd, 200, SEEK_SET)` | 200 | 200 |
| `read(fd, buffer, 50)` | 50 | 250 |
| `close(fd)` | 0 | — |

!!! note "边栏：调用 lseek() 并不会让磁盘寻道"
    名字欠佳的 `lseek()` 常把刚学磁盘的同学绕进去。它只修改内存中记录“下次从文件哪里读写”的变量，本身不产生磁盘 I/O。真正的磁盘寻道，是某次读写落到不同磁道、需要移动磁头。当然，若用 `lseek()` 把读写位置改得东一块西一块，随后的 I/O 很可能导致更多磁盘寻道；它会埋下导火索，但不是亲手点火的那一下。

## 39.6 共享打开文件表项：fork() 与 dup()

多数情况下，文件描述符与打开文件表项一一对应。即使两个进程同时读取同一文件，通常也各有自己的表项和当前偏移，彼此独立。

但有些场景会共享表项。父进程调用 `fork()` 创建子进程就是其中之一：

```c
int main(int argc, char *argv[]) {
    int fd = open("file.txt", O_RDONLY);
    assert(fd >= 0);
    int rc = fork();
    if (rc == 0) {
        rc = lseek(fd, 10, SEEK_SET);
        printf("child: offset %d\n", rc);
    } else if (rc > 0) {
        (void) wait(NULL);
        printf("parent: offset %d\n",
               (int) lseek(fd, 0, SEEK_CUR));
    }
    return 0;
}
```

*图 39.2：父子进程共享文件表项（`fork-seek.c`）。*

运行结果为：

```console
prompt> ./fork-seek
child: offset 10
parent: offset 10
```

关系如下：

```text
父进程 fd 3 ─┐
              ├─> 打开文件表项 { refcnt: 2, off: 10 } ─> inode #1000 (file.txt)
子进程 fd 3 ─┘
```

*图 39.3：两个进程共享一个打开文件表项。*

父子进程各有私有描述符数组，却指向同一个打开文件表项，再由它指向文件系统中的 inode。共享发生时引用计数增加；只有两个进程都关闭文件或退出后，该表项才会移除。

这种共享偶尔很有用。例如让多个协作进程向同一个输出文件写数据时，它们可以共享偏移而无需额外协调。`fork()` 后究竟还有哪些资源共享，请查手册页。

另一个更常用的共享方式是 `dup()`，以及它的近亲 `dup2()`、`dup3()`。`dup()` 创建一个新文件描述符，却让它与已有描述符指向同一个打开文件：

```c
int main(int argc, char *argv[]) {
    int fd = open("README", O_RDONLY);
    assert(fd >= 0);
    int fd2 = dup(fd);
    // 现在 fd 与 fd2 可以互换使用
    return 0;
}
```

*图 39.4：用 `dup()` 共享文件表项（`dup.c`）。*

编写 UNIX shell、实现输出重定向时，`dup()`——特别是 `dup2()`——非常有用。请花点时间想想为什么。你现在可能正在想：“做 shell 项目时怎么不早说？”唉，即便这是一本惊天地泣鬼神的操作系统巨著，也不可能把一切都恰好放在你最需要它的前一页。抱歉啦！

## 39.7 用 fsync() 立即写入

程序调用 `write()` 时，多数时候只是告诉文件系统：“请在未来某个方便的时候把这些数据写入持久存储。”为提高性能，文件系统会把写入在内存中缓冲一段时间，比如 5 秒或 30 秒，再真正发给设备。因此应用看来写入很快；只有少数情况，例如 `write()` 之后、数据落盘之前机器崩溃，数据才会丢失。

但数据库管理系统等应用需要更强保证。正确的恢复协议要求它能在特定时刻强制数据落盘。UNIX 为此提供 `fsync(int fd)`：调用后，文件系统把该描述符对应文件的所有脏数据（尚未写入的数据）强制写到磁盘，全部完成后才返回。

```c
int fd = open("foo", O_CREAT|O_WRONLY|O_TRUNC,
              S_IRUSR|S_IWUSR);
assert(fd > -1);
int rc = write(fd, buffer, size);
assert(rc == size);
rc = fsync(fd);
assert(rc == 0);
```

不过，这段代码未必保证你以为它保证的一切。有时还必须对包含 `foo` 的目录调用 `fsync()`，这样不仅文件数据已经落盘，新文件与目录的联系也持久存在。这个细节经常被忽略，于是应用级错误便愉快地排队登场 [P+13, P+14]。

## 39.8 重命名文件

命令行用 `mv` 重命名文件：

```console
prompt> mv foo bar
```

`strace` 会显示，`mv` 调用了 `rename(char *old, char *new)`。它的一项重要保证是：面对系统崩溃，重命名通常是**原子的(atomic)**。崩溃后文件要么仍叫旧名字，要么已经叫新名字，不会卡在某个奇形怪状的中间态。因此，需要原子更新文件状态的应用离不开它。

例如编辑器要给 `foo.txt` 插入一行，可以忽略错误检查后这样做：

```c
int fd = open("foo.txt.tmp", O_WRONLY|O_CREAT|O_TRUNC,
              S_IRUSR|S_IWUSR);
write(fd, buffer, size); // 写出文件的新版本
fsync(fd);
close(fd);
rename("foo.txt.tmp", "foo.txt");
```

编辑器先用临时名称写出新版本并强制落盘，确认元数据和内容安全后，再把临时文件重命名为原文件。最后一步原子地换入新版本，同时删除旧版本，从而完成原子文件更新。

## 39.9 获取文件信息

除了内容，文件系统还保存每个文件的大量**元数据(metadata)**。`stat()` 接收路径，`fstat()` 接收文件描述符，二者都会填充 `struct stat`：

```c
struct stat {
    dev_t     st_dev;     /* 文件所在设备 ID */
    ino_t     st_ino;     /* inode 号 */
    mode_t    st_mode;    /* 保护模式 */
    nlink_t   st_nlink;   /* 硬链接数 */
    uid_t     st_uid;     /* 所有者用户 ID */
    gid_t     st_gid;     /* 所有者组 ID */
    dev_t     st_rdev;    /* 设备 ID（若为特殊文件） */
    off_t     st_size;    /* 总大小，单位为字节 */
    blksize_t st_blksize; /* 文件系统 I/O 块大小 */
    blkcnt_t  st_blocks;  /* 已分配块数 */
    time_t    st_atime;   /* 上次访问时间 */
    time_t    st_mtime;   /* 上次修改时间 */
    time_t    st_ctime;   /* 上次状态变化时间 */
};
```

命令行工具 `stat` 能显示这些信息：

```console
prompt> echo hello > file
prompt> stat file
File: 'file'
Size: 6   Blocks: 8   IO Block: 4096   regular file
Device: 811h/2065d   Inode: 67158084   Links: 1
Access: (0640/-rw-r-----) Uid: (30686/remzi) Gid: (30686/remzi)
Access: 2011-05-03 15:50:20.157594748 -0500
Modify: 2011-05-03 15:50:20.157594748 -0500
Change: 2011-05-03 15:50:20.157594748 -0500
```

文件系统通常把这些信息保存在 inode 中。有些文件系统给类似结构起名 `dnode`，概念相同。所有 inode 都在磁盘上；为了加速访问，活跃 inode 的副本通常缓存在内存中。

## 39.10 删除文件

UNIX 用户会用 `rm` 删除文件，但它底下调用什么？让老朋友 `strace` 出场：

```console
prompt> strace rm foo
...
unlink("foo") = 0
```

`unlink()` 接受要删除的文件名，成功时返回 0。可它为什么叫“取消链接”，而不叫 `remove()` 或 `delete()`？要解开谜题，还得先多了解目录。

## 39.11 创建目录

目录不能直接写入。因为目录格式属于文件系统元数据，只能通过在其中创建文件、目录或其他对象间接更新；文件系统借此保证目录内容始终合法。

创建目录使用 `mkdir()`：

```console
prompt> strace mkdir foo
...
mkdir("foo", 0777) = 0
```

新目录虽被称为“空”，仍有两个最低限度的条目：`.` 指向自身，`..` 指向父目录。`ls -a` 可以看到它们：

```console
prompt> ls -a
./  ../
prompt> ls -al
total 8
drwxr-x---  2 remzi remzi    6 Apr 30 16:17 ./
drwxr-x--- 26 remzi remzi 4096 Apr 30 16:17 ../
```

!!! tip "小心强大的命令"
    `rm` 是“能力越大，闯祸越快”的优秀教材。`rm *` 会删除当前目录匹配的所有文件，`rm -rf *` 还会递归删除目录及其中内容。若不小心在文件系统根目录执行后者，整棵树可能顷刻秃掉。哎呀。

    强大命令用极少按键完成大量工作，也能用同样少的按键制造大量灾难。按下回车前，多看一眼通常比事后写恢复报告便宜。

## 39.12 读取目录

`ls` 会读取目录。下面这个小程序使用 `opendir()`、`readdir()` 和 `closedir()`，逐项打印当前目录中的文件名与 inode 号：

```c
int main(int argc, char *argv[]) {
    DIR *dp = opendir(".");
    assert(dp != NULL);
    struct dirent *d;
    while ((d = readdir(dp)) != NULL) {
        printf("%lu %s\n", (unsigned long) d->d_ino, d->d_name);
    }
    closedir(dp);
    return 0;
}
```

目录项 `struct dirent` 提供的信息如下：

```c
struct dirent {
    char           d_name[256]; /* 文件名 */
    ino_t          d_ino;       /* inode 号 */
    off_t          d_off;       /* 下一目录项的偏移 */
    unsigned short d_reclen;    /* 本记录长度 */
    unsigned char  d_type;      /* 文件类型 */
};
```

目录本身信息不多，核心只是名称到 inode 号的映射。程序若想知道长度等详细信息，还要对各文件调用 `stat()`。`ls -l` 正是如此；分别对普通 `ls` 和 `ls -l` 运行 `strace`，便能看到差别。

## 39.13 删除目录

删除目录使用 `rmdir()`。一次误删目录可能带走大量数据，因此它要求目录必须为空——也就是只剩 `.` 与 `..`——否则直接失败。

## 39.14 硬链接

现在用 `link()` 解开 `unlink()` 的命名谜题。`link()` 接收旧路径与新路径；把新名称“链接”到旧名称后，就多了一条引用同一文件的路。命令行程序是 `ln`：

```console
prompt> echo hello > file
prompt> cat file
hello
prompt> ln file file2
prompt> cat file2
hello
```

这里创建了名为 `file` 的文件，再建立名为 `file2` 的**硬链接(hard link)**。作者在命名上向来创意惊人：他们还养过一只叫“Cat”的猫，这是真事。后来猫去世了，又养了一只叫“Hammy”的仓鼠。更新：Hammy 也去世了。宠物遗体越堆越多——这脚注突然比文件系统阴沉得多。

`link()` 只是在目标目录中创建另一个名称，并让它指向原文件的 inode 号；数据没有复制，只是两个用户可读名称指向同一个文件：

```console
prompt> ls -i file file2
67158084 file
67158084 file2
```

创建文件实际上做了两件事：先建立 inode，记录大小、数据块位置等信息；再把用户可读名称链接到 inode，并把这条联系放进目录。对文件系统而言，原名称与后来创建的硬链接没有高低贵贱，二者都只是 inode 的名字。

删除文件因此叫 `unlink()`：它移除名称与 inode 之间的链接，并减少 inode 内的**链接计数(link count)**。只有计数降为 0，系统才释放 inode 和数据块，文件才算真正删除。于是删除一个名字后，另一个硬链接仍能使用：

```console
prompt> rm file
removed 'file'
prompt> cat file2
hello
```

链接计数的变化也能用 `stat()` 观察：

```console
prompt> echo hello > file       # Links: 1
prompt> ln file file2           # Links: 2
prompt> ln file2 file3          # Links: 3
prompt> rm file                 # Links: 2
prompt> rm file2                # Links: 1
prompt> rm file3                # 计数归零，真正释放
```

## 39.15 符号链接

另一种很有用的链接是**符号链接(symbolic link)**，也叫**软链接(soft link)**。硬链接有不少限制：不能链接目录，以免目录树出现环；不能跨文件系统，因为 inode 号只在单个文件系统内唯一。符号链接便为这些场景而生。

用 `ln -s` 创建：

```console
prompt> echo hello > file
prompt> ln -s file file2
prompt> cat file2
hello
```

表面效果类似，内部却大不相同。符号链接本身就是一种独立文件类型，与普通文件、目录并列。`ls -l` 的首字符中，`-` 表示普通文件，`d` 表示目录，`l` 表示符号链接：

```console
-rw-r----- 1 remzi remzi 6 May 3 19:10 file
lrwxrwxrwx 1 remzi remzi 4 May 3 19:10 file2 -> file
```

`file2` 长 4 字节，是因为符号链接把目标路径 `file` 当作自身数据。目标路径越长，链接文件也越大：

```console
prompt> echo hello > alongerfilename
prompt> ln -s alongerfilename file3
-rw-r----- 1 remzi remzi  6 May 3 19:17 alongerfilename
lrwxrwxrwx 1 remzi remzi 15 May 3 19:17 file3 -> alongerfilename
```

这种实现也可能留下**悬空引用(dangling reference)**：

```console
prompt> echo hello > file
prompt> ln -s file file2
prompt> rm file
prompt> cat file2
cat: file2: No such file or directory
```

与硬链接不同，删除原目标后，符号链接只是继续忠诚地指向一个已经不存在的路径。

## 39.16 权限位与访问控制列表

进程抽象虚拟化 CPU 与内存，让每个进程仿佛拥有私有资源；底层操作系统则在竞争者之间安全共享有限硬件。文件系统也把原始磁盘块变成友好的文件与目录，但文件常被多个用户和进程共享，并不总是私有，因此需要更全面的共享控制机制。

最经典的是 UNIX **权限位(permission bits)**：

```console
prompt> ls -l foo.txt
-rw-r--r-- 1 remzi wheel 0 Aug 24 16:29 foo.txt
```

第一个字符表示类型；其后九个字符分为三组，依次控制文件所有者、所属组和其他用户。每组中的 `r`、`w`、`x` 分别表示读、写、执行。上例的所有者可读写（`rw-`），组成员与其他人只能读（`r--`）。

所有者可用 `chmod` 修改模式：

```console
prompt> chmod 600 foo.txt
```

数字 6 是读位 4 与写位 2 的按位或；后两个 0 禁止组和其他用户访问，最终模式为 `rw-------`。

普通文件的执行位决定它能否作为程序运行。脚本没有执行位时：

```console
prompt> chmod 600 hello.csh
prompt> ./hello.csh
./hello.csh: Permission denied.
```

目录的执行位略有不同：它允许用户 `cd` 进入目录；再配合写位，用户才能在其中创建文件。最好的学习办法是自己试试。别担心，你（大概）不会把东西弄得太糟。

!!! note "边栏：文件系统的超级用户"
    谁能执行管理文件系统所需的特权操作？本地文件系统通常设有 `root` 超级用户，无视普通权限访问所有文件。AFS 等分布式文件系统采用访问控制列表，并让 `system:administrators` 组承担类似职责。

    这些受信用户也构成固有安全风险：攻击者若能冒充其中之一，就能访问系统内全部信息，隐私与保护保证随之破产。

比权限位更精细的是**访问控制列表(access control list, ACL)**。例如 AFS 为每个目录维护 ACL，可以明确列出谁能、谁不能访问资源，不受“所有者/组/其他人”三分法限制：

```console
prompt> fs listacl private
Access list for private is
Normal rights:
  system:administrators rlidwka
  remzi                rlidwka
```

这里系统管理员和 `remzi` 都能查找、插入、删除、管理、读取、写入并锁定目录中的文件。要让另一位作者 Andrea 读取和查找该目录，Remzi 可执行：

```console
prompt> fs setacl private/ andrea rl
```

Remzi 的隐私就这样没了！但你也学到了更重要的一课：美满婚姻里不能有秘密，哪怕秘密藏在文件系统中。两位作者自 1996 年起婚姻幸福——你若正想问的话。我们知道，你并没有。

!!! tip "小心 TOCTTOU"
    McPhee 在 1974 年指出：若有效性检查与相关操作之间存在时间窗口，多任务系统中的其他执行者就可能在窗口内改变检查对象，使控制程序执行无效操作。今天把它称为**检查时刻到使用时刻(Time Of Check To Time Of Use, TOCTTOU)**问题；遗憾的是，它至今仍活蹦乱跳。

    Bishop 与 Dilger [BD96] 给出一个例子。假设邮件服务以 `root` 身份运行。它先用 `lstat()` 检查收件箱确实是目标用户拥有的普通文件，而非指向敏感位置的链接；检查通过后，再把邮件追加进去。

    攻击者可以在检查和写入之间调用 `rename()`，把收件箱换成指向 `/etc/passwd` 等敏感文件的对象。若时机恰好，邮件服务会毫无戒心地替攻击者更新敏感文件。攻击者只需“发一封邮件”就获得越权写能力，甚至可向 `/etc/passwd` 加入 root 账户并接管系统。

    TOCTTOU 没有简单而完美的解法 [T+08]。减少必须以 root 运行的服务有所帮助；`O_NOFOLLOW` 能让 `open()` 在目标为符号链接时失败；事务型文件系统 [H+18] 可以从根本上解决，但尚未广泛部署。于是只剩那条不太令人振奋却仍然正确的建议：写高权限代码时，务必小心。

## 39.17 创建并挂载文件系统

我们已经游览了文件、目录和特殊链接的接口，还差最后一件事：怎样把多个底层文件系统拼成一棵完整目录树。答案是先创建文件系统，再把它们挂载进来。

多数文件系统提供 `mkfs` 工具（读作“make fs”）。给它一个设备，例如分区 `/dev/sda1`，以及文件系统类型，例如 `ext3`，它便在分区上写入一个以根目录开头的空文件系统。于是 `mkfs` 说：要有文件系统——便有了文件系统。

随后用 `mount` 程序（底层调用 `mount()`）让它在统一目录树中可见。`mount` 以已有目录作为**挂载点(mount point)**，把新文件系统粘到树上的那个位置。

假设 `/dev/sda1` 上有一个尚未挂载的 ext3 文件系统，根目录中有 `a`、`b` 两个子目录，各自含一个 `foo` 文件。把它挂到 `/home/users`：

```console
prompt> mount -t ext3 /dev/sda1 /home/users
prompt> ls /home/users/
a b
```

新文件系统的根现在对应 `/home/users/`；两个目录是 `/home/users/a` 与 `/home/users/b`；其中的文件则是 `/home/users/a/foo` 和 `/home/users/b/foo`。挂载的妙处正在这里：原本分离的文件系统被统一到一棵树中，命名一致而方便。

直接运行 `mount` 可以查看系统挂载了什么：

```text
/dev/sda1 on / type ext3 (rw)
proc on /proc type proc (rw)
sysfs on /sys type sysfs (rw)
/dev/sda5 on /tmp type ext3 (rw)
/dev/sda7 on /var/vice/cache type ext3 (rw)
tmpfs on /dev/shm type tmpfs (rw)
AFS on /afs type afs (rw)
```

这锅热闹的拼盘里有磁盘文件系统 ext3、暴露进程信息的 `proc`、保存临时文件的 `tmpfs`，以及分布式文件系统 AFS；它们全被粘进同一台机器的目录树。

!!! note "边栏：文件系统关键术语"
    - **文件**是可创建、读取、写入和删除的字节数组，有唯一的底层数字名称，常称 i-number 或 inode 号。
    - **目录**保存“用户可读名称—底层名称”二元组，每项指向文件或目录。目录自身也有 inode 号，并总有指向自身的 `.` 与指向父目录的 `..`。
    - **目录树**从根目录开始，把所有文件和目录组织成一棵大树。
    - 进程通常调用 `open()` 请求访问文件；若获准，操作系统返回文件描述符，供后续读写使用。
    - 文件描述符是每进程私有的，指向打开文件表项；后者记录底层文件、当前偏移和其他信息。
    - `read()`、`write()` 会自然推进当前偏移，`lseek()` 则显式改变它，实现随机访问。
    - 要强制更新落到持久介质，需调用 `fsync()` 等接口；正确完成这件事同时保持高性能并不容易 [P+14]。
    - 多个用户可读名称可以通过硬链接或符号链接指向同一文件；二者长短各异。所谓删除文件，最终只是从目录层次中执行最后一次 `unlink()`。
    - 文件系统通常提供共享控制机制：基础形式是权限位，更精细的 ACL 则能准确控制谁可以访问和操作信息。

## 39.18 小结

UNIX 文件系统接口看似朴素，真想掌握却有许多门道。最好的学习方式当然是大量使用它，所以请动手。也要继续阅读；一如既往，Stevens [SR05] 是很好的起点。

## 参考文献

- [BD96] “Checking for Race Conditions in File Accesses” by Matt Bishop, Michael Dilger. *Computing Systems* 9:2, 1996. 对 TOCTTOU 问题及其在文件系统中表现的精彩说明。
- [CK+08] “The xv6 Operating System” by Russ Cox, Frans Kaashoek, Robert Morris, Nickolai Zeldovich. 见 xv6-public 项目。一个很酷也很简单的 UNIX 实现。本书使用较旧的 2012-01-30 版本，因此示例可能与最新源码不同。
- [H+18] “TxFS: Leveraging File-System Crash Consistency to Provide ACID Transactions” by Y. Hu et al. USENIX ATC '18, June 2018. ATC '18 最佳论文，也是了解事务型文件系统的好起点。
- [K84] “Processes as Files” by Tom J. Killian. USENIX, June 1984. 提出 `/proc` 文件系统的论文，其中每个进程都能当作伪文件系统里的文件；聪明的想法今天仍在现代 UNIX 中服役。
- [L84] “Capability-Based Computer Systems” by Henry M. Levy. Digital Press, 1984. 对早期基于能力系统的优秀综述。
- [P+13] “Towards Efficient, Portable Application-Level Consistency” by Thanumalayan S. Pillai et al. HotDep '13, November 2013. 展示应用在提交数据到磁盘时多容易犯错，尤其是把特定文件系统假设偷偷带进应用。
- [P+14] “All File Systems Are Not Created Equal: On the Complexity of Crafting Crash-Consistent Applications” by Thanumalayan S. Pillai et al. OSDI '14, October 2014. 上述主题的完整会议论文，细节和趣闻都多得多。
- [SK09] “Principles of Computer System Design” by Jerome H. Saltzer and M. Frans Kaashoek. Morgan-Kaufmann, 2009. 系统领域的鸿篇巨制；MIT 就用它教系统。读一遍，再多读几遍，让内容慢慢泡进去。
- [SR05] “Advanced Programming in the UNIX Environment” by W. Richard Stevens and Stephen A. Rago. Addison-Wesley, 2005. 我们大概引用过它几十万次。想成为优秀系统程序员，它就是这么有用。
- [T+08] “Portably Solving File TOCTTOU Races with Hardness Amplification” by D. Tsafrir et al. FAST '08, 2008. 虽非最早提出 TOCTTOU 的论文，却是较新、写得很好的问题说明和可移植解决方案。

## 作业（代码）

本作业让你熟悉本章 API。请编写几个程序，大多仿照常见 UNIX 工具。

1. **Stat**：实现自己的 `stat` 命令，对给定文件或目录调用 `stat()`，打印文件大小、已分配块数、引用（链接）计数等。目录项数量变化时，目录的链接计数怎样变化？有用接口：`stat()`。
2. **列出文件**：编写程序列出指定目录中的文件。没有选项时只打印文件名；带 `-l` 时打印所有者、组、权限，以及 `stat()` 得到的其他信息。程序还应接受一个目录参数，例如 `myls -l directory`；省略时使用当前工作目录。有用接口：`stat()`、`opendir()`、`readdir()`、`getcwd()`。
3. **Tail**：编写程序打印文件末尾若干行。程序应高效地定位到接近文件末尾处，读入一块数据，再反向查找，直到找到所需行数；随后按正向顺序打印到文件结尾。调用形式为 `mytail -n file`，其中 `n` 是行数。有用接口：`stat()`、`lseek()`、`open()`、`read()`、`close()`。
4. **递归搜索**：从目录树中给定位置开始，打印每个文件和目录的名称。无参数时，以当前工作目录为根，递归打印所有子目录内容；给一个目录参数时，以它为根。再加入类似强大 `find` 工具的有趣选项。该用什么接口？这次你自己想。
