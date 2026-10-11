# AGENTS.md — 《操作系统导论：三个简单部件》中文翻译工作指南

> 本文件是给**后续接手的 AI 智能体 / 协作者**看的操作手册。开始任何工作前请完整读一遍，
> 并遵守其中的约定，避免重复劳动、破坏风格一致性。
> 本文件仅可由用户编辑, 禁止AI擅自修改.
> 已经部署到page, https://wdwkmooop.github.io/ostep-zn/
---

## 0. 一句话说明

把 OSTEP（*Operating Systems: Three Easy Pieces*, v1.00/1.01）
翻译成中文，以 **Markdown 为唯一真源**，用 **MkDocs Material** 生成**静态 HTML** 站点。


---

## 1. 工作目录一览

```
ostep/                               ← 项目根（工作目录）
├─ ostep part1.pdf                   ← 原书 Part I（虚拟化），292 页
├─ ostep part2.pdf                   ← 原书 Part II（并发），130 页
├─ ostep part3.pdf                   ← 原书 Part III（持久化与分布式系统），286 页；正文范围为第 35~51 章
├─ ostep-ch.docx                     ← 【作者旧稿】已译 26.5~28.6（并发），仅作**行文风格参考**
└─ ostep-zh/                         ← 我们的翻译工程
   ├─ AGENTS.md                      ← 本文件
   ├─ mkdocs.yml                     ← 站点配置
   ├─ requirements.txt               ← Python 依赖
   ├─ progress.md                    ← 逐章进度看板（**每章完成后必须更新**）
   ├─ extraction/                    ← 原文抽取缓存（自动生成，不要手改）
   ├─ tools/                         ← 抽取 / 拆页 / 裁图脚本
   ├─ build/                         ← mkdocs 生成的静态站（自动生成，不要手改）
   └─ docs/                          ← ★ 所有译文 Markdown 与素材
      ├─ index.md                    ← 首页
      ├─ glossary.md                 ← 术语对照表（**必读，先查再译**）
      ├─ style-guide.md              ← 本地翻译风格与规范（**必读；已忽略，禁止提交**）
      ├─ preface/                    ← 前言、致讲师、致学生、致谢
      ├─ 02-introduction.md ...      ← 正文各章（命名见 §4）
      ├─ assets/css/extra.css        ← 自定义样式（crux/边栏/对话框）
      └─ assets/figures/chNN/        ← 每章裁出的插图（自动生成）
```

---

## 2. 环境与构建

* 操作系统：Windows（PowerShell 5.1）。脚本均为 `.ps1`。
* 需要的命令行工具（已就位，勿另装）：
  * `pdftotext` / `pdftoppm` / `pdfimages` —— 位于 `D:\texlive\2026\bin\windows\`
  * Python 3.12（`C:\Pythons\Python312\python3.exe`）、Node、Git
* Python 依赖见 `requirements.txt`（`mkdocs-material`、`jieba`、`mkdocs-glightbox`）。

常用命令（在 `ostep-zh/` 目录下执行）：

```powershell
# 安装依赖（首次）
& "C:\Pythons\Python312\python3.exe" -m pip install -r requirements.txt

# 本地预览（推荐；file:// 下搜索索引会被浏览器拦截）
& "C:\Pythons\Python312\python3.exe" -m mkdocs serve
#   打开 http://127.0.0.1:8000

# 生成静态站到 build/
powershell -ExecutionPolicy Bypass -File .\tools\build.ps1
```

> **注意**：构建使用非目录式 URL，因此用 `file://` 直接打开 `build/index.html` 时，页面导航和
> 前后页链接可用；但浏览器跨域策略仍会让搜索结果为空。要验证搜索，请用 `mkdocs serve` 或
> `python -m http.server`。

### 2.1 Windows/PS 5.1 踩坑备忘（易忘，务必遵守）

* **所有 `.ps1` 必须存成 UTF-8 *带 BOM***。PowerShell 5.1 会把无 BOM 的 UTF-8 脚本里的中文
  按 GBK 解码，直接导致语法错误。修改脚本后如报"缺少字符串终止符"之类，先检查 BOM。
* **`requirements.txt` 只许写 ASCII**。pip 在本机 GBK 区域设置下读取带中文注释的
  requirements 会抛 `UnicodeDecodeError`。
* **`mkdocs.yml` 里含冒号的字符串要加引号**（如 `site_description` 的
  `"Operating Systems: Three Easy Pieces"`），否则 YAML 报 `mapping values are not allowed here`。
* 调 `python` 时优先用完整路径 `C:\Pythons\Python312\python3.exe`。
* 期望 `mkdocs build --strict` **零警告**；它是本项目的验收命令之一。

---

## 3. 每章翻译的标准流程（**严格按顺序执行**）

1. **抽取原文**
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\extract.ps1 -Chapter 4
   ```
   生成 `extraction/raw/ch04.txt`（按页，含分页符 `\f`）和 `extraction/ch04.pages.txt`（每页一块）。
   同时保留一份 `-layout` 版方便看代码/图注。

2. **通读原文**（该章对应的 PDF 页区间见 §5 映射表）。弄清：
   * 章标题、各节标题（含编号）
   * `THE CRUX`（问题核心）、`ASIDE`（边栏）、`TIP`（提示）三类框分别出现在哪
   * 图号与图注、代码清单号
   * 对话章（ch1/3/11/12/24）的问答结构

3. **翻译正文**，写入 `docs/<文件名>.md`（命名见 §4）。边译边：
   * 查 `glossary.md`，新术语先加表再使用
   * 套用 `style-guide.md` 的语气（详见 §6）
   * 正文中出现公式用 `$...$`（少量，调度/分页处）

4. **裁图**：对本章每张图
   * 先看原页图像，确定裁剪框（CSS 像素，左上角为原点，300 DPI 渲染）
   * 写入 `tools/crops.json`（按 `chNN/figX.Y` 为键，见 §7 格式）
   * 运行 `powershell -ExecutionPolicy Bypass -File .\tools\crop-figures.ps1 -Chapter 4`
   * 输出到 `docs/assets/figures/ch04/`，在正文用
     `![图 4.1 进程的内存布局](assets/figures/ch04/fig4.1.png)` 引用

5. **转写代码**：PDF 抽出的代码是**残缺的**（见 §8），必须**看图逐字重打**成
   ```` ```c ... ``` ```` 代码块，保留行号（若原文有行号，用代码块的 `linenums` 或
   Material 的 annotation 逐行讲解）。**代码中的注释要翻译成中文**（见 §6）；代码本身、
   标识符、字符串与命令行参数保持原样。

6. **自检**（见 §9 完成标准）。

7. **更新 `progress.md`**：把该章状态从 `未开始/翻译中` 改为 `已完成`，并记下拉取页区间、
   图数、遗留问题。

> Part III 正文按用户指定的节奏推进：**每批四章**；第 51 章单独收尾。附录 A~H 也纳入
> 翻译范围，继续按**每批四篇附录**推进（A~D、E~H）。每批全部达到完成标准并交作者抽查后，
> 再继续下一批；不要跨批次铺开未完成译文。

---

## 4. 文档命名与导航

文件名用 `NN-slug.md`，`NN` 为原书章号（两位，前言用 `00-`）：

```
docs/index.md                     首页（封面 + 目录说明）
docs/preface/to-everyone.md       致所有人
docs/preface/to-educators.md      致讲师
docs/preface/to-students.md       致学生
docs/preface/acknowledgments.md   致谢
docs/preface/final-words.md       结束语
docs/01-dialogue-on-the-book.md   第 1 章 关于本书的对话
docs/02-introduction.md           第 2 章 操作系统导论
docs/03-dialogue-on-virtualization.md
docs/04-the-process.md            第 4 章 抽象：进程  ← 模板章
docs/05-process-api.md
docs/06-limited-direct-execution.md
docs/07-scheduling-introduction.md
docs/08-mlfq.md
docs/09-proportional-share.md
docs/10-multiprocessor-scheduling.md
docs/11-summary-dialogue-cpu.md
docs/12-dialogue-on-memory-virtualization.md
docs/13-address-spaces.md
docs/14-memory-api.md
docs/15-address-translation.md
docs/16-segmentation.md
docs/17-free-space-management.md
docs/18-paging-introduction.md
docs/19-tlbs.md
docs/20-smaller-tables.md
docs/21-beyond-physical-memory-mechanisms.md
docs/22-beyond-physical-memory-policies.md
docs/23-complete-vm-systems.md
docs/24-summary-dialogue-memory.md
docs/25-dialogue-on-concurrency.md
...
docs/34-summary-dialogue-concurrency.md
docs/35-dialogue-on-persistence.md
docs/36-io-devices.md
docs/37-hard-disk-drives.md
docs/38-raids.md
docs/39-files-and-directories.md
docs/40-file-system-implementation.md
docs/41-locality-and-ffs.md
docs/42-crash-consistency-fsck-and-journaling.md
docs/43-log-structured-file-systems.md
docs/44-flash-based-ssds.md
docs/45-data-integrity-and-protection.md
docs/46-summary-dialogue-persistence.md
docs/47-dialogue-on-distribution.md
docs/48-distributed-systems.md
docs/49-nfs.md
docs/50-afs.md
docs/51-summary-dialogue-distribution.md
docs/appendix-a-dialogue-vmm.md
docs/appendix-b-virtual-machine-monitors.md
docs/appendix-c-dialogue-monitors.md
docs/appendix-d-monitors-deprecated.md
docs/appendix-e-dialogue-labs.md
docs/appendix-f-laboratory-tutorial.md
docs/appendix-g-laboratory-systems-projects.md
docs/appendix-h-laboratory-xv6-projects.md
```

新增/改名后，**必须同步更新 `mkdocs.yml` 的 `nav:`**，否则该页不会出现在站点导航里。

---

## 5. 章节 → PDF 页映射（`ostep part1.pdf`，1-based）

> **重要**：该 PDF 由各章单独排版再拼接而成，**每章的页眉/页码都会从该章第 1 页重新开始**，
> 且**实际页序与"章号顺序"并不一致**（例如第 7 章被排到了调度章的末尾，PDF 第 125 页起）。
> 下表为 2026-10 用 `pdftotext` 逐页复核后的真实区间，`extract.ps1` 的 `$PageMap` 与此同步。

| 内容 | PDF 页 | 内容 | PDF 页 |
|---|---|---|---|
| 前言/致谢/目录 | 1–21 | 第 13 章 地址空间 | 139–147 |
| 第 1 章 关于本书的对话 | 22–23 | 第 14 章 内存 API | 148–157 |
| 第 2 章 操作系统导论 | 24–41 | 第 15 章 地址转换 | 158–171 |
| 第 3 章 关于虚拟化的对话 | 44–45 | 第 16 章 分段 | 172–182 |
| 第 4 章 抽象：进程 | 46–56 | 第 17 章 空闲空间管理 | 183–199 |
| 第 5 章 插曲：进程 API | 57–68 | 第 18 章 分页：介绍 | 200–212 |
| 第 6 章 机制：受限制的直接执行 | 69–83 | 第 19 章 分页：快速地址转换（TLB） | 213–228 |
| 第 8 章 调度：多级反馈队列 | 84–95 | 第 20 章 分页：较小的表 | 229–243 |
| 第 9 章 调度：比例份额 | 96–109 | 第 21 章 超越物理内存：机制 | 244–254 |
| 第 10 章 多处理器调度（高级） | 110–122 | 第 22 章 超越物理内存：策略 | 255–271 |
| 第 11 章 CPU 虚拟化总结对话 | 123–124 | 第 23 章 完整虚拟内存系统 | 272–289 |
| 第 7 章 调度：介绍 | 125–136 | 第 24 章 内存虚拟化总结对话 | 290–292 |
| 第 12 章 关于内存虚拟化的对话 | 137–138 | | |

`ostep part2.pdf`（Part II）和 `ostep part3.pdf`（Part III）的正文页区间如下：

| 内容 | PDF 页 | 内容 | PDF 页 |
|---|---|---|---|
| 第 25 章 关于并发的对话 | Part II 3–4 | 第 35 章 关于持久化的对话 | Part III 3–4 |
| 第 26 章 并发：介绍 | Part II 5–19 | 第 36 章 I/O 设备 | Part III 5–17 |
| 第 27 章 插曲：线程 API | Part II 20–31 | 第 37 章 硬盘驱动器 | Part III 18–33 |
| 第 28 章 锁 | Part II 32–53 | 第 38 章 廉价冗余磁盘阵列（RAID） | Part III 34–51 |
| 第 29 章 基于锁的并发数据结构 | Part II 54–67 | 第 39 章 插曲：文件和目录 | Part III 52–77 |
| 第 30 章 条件变量 | Part II 68–83 | 第 40 章 文件系统实现 | Part III 78–95 |
| 第 31 章 信号量 | Part II 84–101 | 第 41 章 局部性与快速文件系统 | Part III 96–109 |
| 第 32 章 常见并发问题 | Part II 102–117 | 第 42 章 崩溃一致性：FSCK 与日志 | Part III 110–130 |
| 第 33 章 基于事件的并发 | Part II 118–128 | 第 43 章 日志结构文件系统 | Part III 131–146 |
| 第 34 章 并发总结对话 | Part II 129–130 | 第 44 章 基于闪存的 SSD | Part III 147–170 |
| | | 第 45 章 数据完整性与保护 | Part III 171–183 |
| | | 第 46 章 持久化总结对话 | Part III 184–185 |
| | | 第 47 章 关于分布式的对话 | Part III 186–187 |
| | | 第 48 章 分布式系统 | Part III 188–203 |
| | | 第 49 章 Sun 网络文件系统（NFS） | Part III 204–221 |
| | | 第 50 章 Andrew 文件系统（AFS） | Part III 222–235 |
| | | 第 51 章 分布式总结对话 | Part III 236–237 |

本项目将同一 `ostep part3.pdf` 中的第 47~51 章“分布式系统”与附录 A~H 均纳入翻译范围。

| 附录 | 标题 | Part III PDF 页 |
|---|---|---:|
| A | 关于虚拟机监控器的对话 | 238 |
| B | 虚拟机监控器 | 239–251 |
| C | 关于管程的对话 | 252 |
| D | 管程（已弃用） | 253–265 |
| E | 关于实验的对话 | 266–267 |
| F | 实验：教程 | 268–279 |
| G | 实验：系统项目 | 280–283 |
| H | 实验：xv6 项目 | 284–286 |

> 已核实全部章节区间；`extract.ps1` 抽取某一章时会多带出下一章的起始页，翻译时忽略即可。

---

## 6. 风格与术语（详见 `style-guide.md` / `glossary.md`）

> `docs/style-guide.md` 仅供本地协作使用，已列入 `.gitignore`。不得使用 `git add -f` 强制加入，
> 不得让它出现在任何 commit、发布站点导航或公开页面链接中。

作者旧稿（`ostep-ch.docx`，仅并发部分）确立的语气基线——**请模仿**：

* 口语化、直白，调侃语气表达与俏皮话：
  * "可得费一番脑筋"、"否则,你可学不会!"
  * "炫技容易翻车"、"代码的奇幻漂流"、"让你抓心挠肝"
  * 对话章保留教授/学生的贫嘴与桃子梗，**意译出等价幽默**，不要直译。
* 术语**首现**中英并列，其后固定用中文：`进程(process)`、`地址空间(address space)`、
  `页表(page table)`、`锁(lock)`、`条件变量(condition variable)`。
* **API / 函数名 / 命令行 / 文件名 / 变量名一律保留英文原样**：`fork()`、`pthread_mutex_lock()`、
  `./scheduler.py -p FIFO`。
* **代码中的注释翻译成中文**；代码本身、标识符、字符串字面量与数学符号保持原样。
  * 行内 / 块注释：译成中文，保留注释符号（`//`、`/* */`、`#`）。
  * 代码里的字符串输出、`printf` 文本、命令行参数、文件名**不翻译**（它们是程序行为的一部分）。
  * 若注释里含标识符/术语，按 `glossary.md` 处理，标识符保留英文。

---

## 7. 图片裁剪规范

* 渲染：`pdftoppm -r 300 -png`（300 DPI）。
* 裁剪框 `tools/crops.json` 单位是**渲染后像素**，`x,y` 为左上角，`w,h` 为宽高：

  ```json
  {
    "ch04": {
      "fig4.1": { "page": 47, "x": 250, "y": 1400, "w": 2050, "h": 700 },
      "fig4.2": { "page": 51, "x": 250, "y": 600,  "w": 2050, "h": 1100 }
    }
  }
  ```

* 裁剪后若发现线宽/字太小，可对该图单独提高 DPI（脚本支持 `dpi` 覆盖字段）。
* 图片文件命名 `fig<N>.<M>.png`，与原文图号一致；正文图注格式：
  `*图 4.1：进程的内存布局。左：代码/数据/堆/栈；右：多进程共享物理内存。*`
* **不要**用整页截图充当插图——应裁到图的边界框。
* 为了避免裁剪不全, 裁剪框应当留出 5%左右 的余量
* 为了确保不要裁剪到残缺部分, 可以做边缘像素的检查, 以此确保边缘是空白.

---

## 8. 代码转写警告（重要）

这些 PDF 的**代码块无法用文本抽取还原**，`pdftotext` 会得到错乱结果，例如原文

```c
pthread_t p;
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
```

抽取后可能变成 `pthread_metex_init`、签名断行错位等。因此：

* **一律以 PDF 页面图像为准，逐字重敲**代码。
* 敲完后用编译器/眼睛核对括号、分号、参数顺序。
* 忠于原文，**不要**顺手"修正"原书示例的 bug 或命名（除非原书正文明确指出）。
* **注释译成中文**，但代码、标识符、字符串字面量、命令行参数保持原样（见 §6）。
* 需要行内讲解的代码，用 MkDocs Material 的 code annotation 写法（`# (1)` + 列表）。

---

## 9. 完成标准（Definition of Done）

一章"完成"须同时满足：

- [ ] 正文、所有 `CRUX`/`ASIDE`/`TIP` 框、对话章问答，全部译出，无遗漏段落
- [ ] 所有插图已裁并正确嵌入，图注已译，编号与原文一致
- [ ] 所有代码清单已转写并高亮（C 代码语言标注为 `c`），**注释已译成中文**
- [ ] 术语符合 `glossary.md`；新术语已回写术语表
- [ ] 站内链接（前后章、图片路径）可点；`mkdocs build` 无警告
- [ ] `progress.md` 已更新（状态、页区间、图数、遗留问题）

---

## 10. 三类框 / 对话章的写法约定

Material 的 admonition 语法（缩进 4 空格）：

```markdown
!!! danger "问题核心"
    这里写 `THE CRUX` 的内容。

!!! note "边栏"
    这里写 `ASIDE` 的内容。

!!! tip "提示"
    这里写 `TIP` 的内容。
```

对话章（ch1/3/11/12/24）用自定义容器（CSS 已定义）：

```markdown
<div class="dialogue" markdown>
**教授：** 于是我们来到了操作系统的第二根支柱：并发。

**学生：** 我以为有四个支柱来着……？
</div>
```

---

## 11. 禁止事项

* 不要修改 `ostep part*.pdf`、`ostep-ch.docx` 等原始文件。
* 不要手改 `extraction/`、`build/`、`docs/assets/figures/` 下的自动生成内容。
* 不要在未更新 `mkdocs.yml` 的情况下新增页面。
* 不要为图省事跳过代码转写、用截图糊弄。
* 不要一次性翻译超过两章；保持小步交付、作者可抽查。
* 不要引入 Node/前端构建链；本项目锁定 MkDocs Material。

---

## 12. 术语速查（完整见 `glossary.md`）

| English | 中文 | English | 中文 |
|---|---|---|---|
| process | 进程 | page table | 页表 |
| address space | 地址空间 | page fault | 缺页 |
| virtual memory | 虚拟内存 | swap | 交换 |
| thread | 线程 | TLB | 快表（保留 TLB） |
| concurrency | 并发 | scheduler | 调度器 |
| lock | 锁 | policy / mechanism | 策略 / 机制 |
| condition variable | 条件变量 | crux | 问题核心 |
| context switch | 上下文切换 | aside / tip | 边栏 / 提示 |

---

_任何不确定之处：优先保持与作者旧稿一致的语气；无法判断时在 `progress.md` 的"遗留问题"
中记录并交给作者，不要擅自发明术语。_
