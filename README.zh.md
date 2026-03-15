# mnemonic.nvim

> *源自希腊语 "mnemonikos" —— 关于记忆，保持专注。*

一个基于 FSRS 算法的间隔重复插件，专为 Neovim 打造。为那些相信"提出好问题比记住答案更重要"的学习者而设计。

---

## 1. 插件简介

**mnemonic.nvim** 是一个完全运行在 Neovim 内部的间隔重复系统。它帮助你在主动学习期间保持与知识的连接——不是为了建立永久的记忆档案，而是在你最需要的时候，让关键概念保持鲜活。

插件围绕三个核心原则设计：

- 卡片由你手动创建，每一张都经过深思熟虑
- 复习由 FSRS 算法驱动——目前最精准的记忆模型之一
- 主题有生命周期：学习期间保持活跃，学完后归档

数据以纯 JSON 文件的形式存储在你的笔记目录中。无需外部应用，无需同步服务，没有数据锁定。

---

## 2. 设计理念

### 自制卡片的目的不是永远记住

大多数间隔重复工具围绕"永久记忆"的理念构建——你添加一张卡片，系统无限期地安排复习，直到你"永远记住"它。

mnemonic.nvim 持有不同的观点。

当你在学习一个主题——比如 Rust 的所有权机制，或者动态规划的解题模式——真正的问题不是长期记忆。真正的问题是**在学习新概念的同时，不要忘记旧概念之间的联系**。周一学了闭包，周三转向迭代器，到了周五你已经忘记闭包是怎么工作的了。知识之间的链接断裂了。

这正是 mnemonic.nvim 要解决的问题。卡片属于某个**主题**，主题有**生命周期**：

- **活跃期** —— 你正在学习这个主题，卡片被 FSRS 调度并定期复习
- **归档期** —— 你已经完成了这个主题，卡片不再被复习，但数据保留

当你完成一门课程、结束一个项目、或者转向新的领域，你将主题归档。复习的负担消失了。你积累的知识留在笔记里。

### 质量重于数量

mnemonic.nvim 最重要的设计决策是**每日制卡上限**。

每个主题每天有制卡上限（默认：5 张）。达到上限后，今天无法再为这个主题创建新卡片。

这个限制是刻意为之的。它迫使你思考一个问题：*今天学的所有内容里，最值得记住的一件事是什么？*

一个能提出精准、有深度问题的人，对知识的掌握远比一个能背诵答案的人更深刻。每日上限不是限制——它是培养这种能力的工具。

### 卡片是思考，不是抄写

mnemonic.nvim 卡片的答案栏，不是从教材上复制的定义。它是**你自己凝练的思考**——你理解某件事的方式，用你自己的语言，在你刚刚学会它的那一刻写下来。

这很重要，因为记忆是重建性的。当你复习一张卡片时，你不是在"读取一个事实"——你是在重新激活当初理解这个概念时形成的神经网络。用你自己的语言写成的卡片，比用别人的语言写成的卡片，能更有效地重新激活那个网络。

### 设计背后的神经科学

mnemonic.nvim 的每一个设计决策都有认知科学的依据：

**测试效应（Testing Effect）** —— 从记忆中主动提取信息，比重复阅读的学习效果强 10 倍以上。mnemonic.nvim 的每次复习都是一次主动提取：你看到问题，思考，然后揭示答案。思考的过程本身就是学习。

**间隔效应（Spacing Effect）** —— 分散在时间中的复习，比集中复习的记忆巩固效果好 2-3 倍。FSRS 算法计算每张卡片的最佳复习时机——就在你即将遗忘之前——最大化每次复习的收益。

**必要难度（Desirable Difficulty）** —— 间隔学习和交错练习让学习感觉更难。这种难度不是问题，它是机制本身。mnemonic.nvim 不让复习变得容易，它让复习变得有效。

**稳定性与可提取性（Stability & Retrievability）** —— FSRS 用两个维度建模记忆：*稳定性*（记忆在衰减前能维持多久）和*可提取性*（此刻能回忆出来的概率）。每次复习都会更新这两个值。在即将遗忘时复习的卡片，稳定性提升最大。

---

## 3. 安装与使用

### 环境要求

- Neovim 0.9+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) —— 用于 backlinks 模糊搜索
- [dressing.nvim](https://github.com/stevearc/dressing.nvim) —— 推荐安装，提升输入框体验

### 使用 lazy.nvim 安装

```lua
{
  "Yeijon/mnemonic.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "stevearc/dressing.nvim",  -- 可选，但推荐
  },
  config = function()
    require("mnemonic").setup({
      -- 你的笔记 vault 路径
      vault = "~/notes",

      -- 每个主题每天最多创建几张卡片
      daily_limit = 5,

      -- FSRS 目标可提取性（0.9 = 在 90% 回忆概率时复习）
      target_retrievability = 0.9,

      -- 快捷键（可自定义）
      keymaps = {
        new_card = "<leader>nca",  -- 新建卡片
        review   = "<leader>ncr",  -- 开始复习
        manage   = "<leader>nct",  -- 管理主题
        cards    = "<leader>ncm",  -- 浏览/编辑/删除卡片
      },
    })
  end,
}
```

### 使用 packer.nvim 安装

```lua
use {
  "Yeijon/mnemonic.nvim",
  requires = {
    "nvim-telescope/telescope.nvim",
    "stevearc/dressing.nvim",
  },
  config = function()
    require("mnemonic").setup({
      vault = "~/notes",
      daily_limit = 5,
    })
  end,
}
```

### 数据存储位置

卡片和主题数据以 JSON 格式存储在 `<vault>/.mnemonic/` 目录下：

```
notes/
└── .mnemonic/
    ├── topics.json
    └── cards.json
```

这些是纯 JSON 文件，可以直接查看、备份，或与笔记一起进行版本控制。

---

## 4. 使用说明

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `<leader>nca` | 新建卡片 |
| `<leader>ncr` | 开始复习 |
| `<leader>ncm` | 浏览、编辑、删除卡片 |
| `<leader>nct` | 管理主题（归档、恢复、删除） |

### 命令

| 命令 | 功能 |
|------|------|
| `:MnemonicNew` | 新建卡片 |
| `:MnemonicReview` | 开始复习 |
| `:MnemonicCards` | 浏览/编辑/删除卡片 |
| `:MnemonicManage` | 管理主题 |

### 新建卡片

1. 按 `<leader>nca`
2. 选择已有主题或新建一个
3. 显示今日余额，例如 `2/5 used today`
4. 用 Telescope 选择关联笔记（backlinks）：
   - `<CR>` —— 添加一个文件，选择器保持打开
   - `<C-z>` —— 撤销最后添加的文件
   - `<C-d>` —— 完成选择，进入编辑窗口
   - `<Esc>` —— 跳过 backlinks，直接进入编辑窗口
   - `<C-b>` —— 返回主题选择
5. 在 `# Question` 下写问题，在 `# Answer` 下写回答
6. 按 `<leader>s` 保存

### 复习卡片

1. 按 `<leader>ncr`
2. 选择复习特定主题或所有活跃主题
3. 阅读问题——先思考，再揭示答案
4. 按 `<Space>` 揭示答案
5. 如果卡片有关联笔记，按 `o1`、`o2`... 在右侧分屏打开对应笔记
6. 诚实评分：
   - `1` Again —— 完全没想起来
   - `2` Hard —— 想起来了，但很费力
   - `3` Good —— 正确回忆
   - `4` Easy —— 瞬间想起

### 管理卡片

按 `<leader>ncm` 按主题浏览卡片，选中一张后：

- `e` —— 编辑问题和回答，`<leader>s` 保存
- `d` —— 删除卡片（有确认步骤）
- `a` —— 归档或恢复卡片
- `q` —— 关闭

### 主题生命周期

按 `<leader>nct` 管理主题：

- **归档（Archive）** —— 停止调度该主题下的所有卡片
- **恢复（Reactivate）** —— 重新开始调度
- **删除（Delete）** —— 永久删除主题及其所有卡片

---

## 5. FSRS 算法

mnemonic.nvim 实现了 [FSRS](https://github.com/open-spaced-repetition/fsrs4anki)（自由间隔重复调度器）的简化版本，这也是 Anki 最新版本默认使用的算法。

每张卡片追踪以下状态：

| 字段 | 说明 |
|------|------|
| `stability` | 记忆稳定性，越高说明记得越牢 |
| `difficulty` | 回忆难度（0.1 = 容易，1.0 = 困难） |
| `due` | 下次复习日期 |
| `state` | `new` / `learning` / `review` / `relearning` |
| `reps` | 总复习次数 |
| `lapses` | 遗忘次数 |

下次复习间隔的计算公式，目标是维持 90% 的回忆概率：

```
interval = -stability × ln(0.9)
```

---

## License

MIT
