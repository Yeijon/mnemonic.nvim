# mnemonic.nvim

> *From Greek "mnemonikos" — of memory, mindful.*

A FSRS-based spaced repetition plugin for Neovim. Built for learners who believe that asking the right question matters more than memorizing the right answer.

---

## 1. Introduction

**mnemonic.nvim** is a spaced repetition system that lives entirely inside Neovim. It helps you stay connected to what you are actively learning — not by building a permanent memory archive, but by keeping key concepts alive during the period when you need them most.

It is designed around three principles:

- Cards are created manually, with intention
- Review is driven by the FSRS algorithm — one of the most accurate memory models available
- Topics have a lifecycle: they are active while you study, and archived when you move on

Data is stored as plain JSON files alongside your notes. No external apps, no syncing services, no lock-in.

---

## 2. Design Philosophy

### The purpose of a flashcard is not to remember forever

Most spaced repetition tools are built around the idea of permanent retention — you add a card, and the system schedules it indefinitely until you "know" it forever.

mnemonic.nvim takes a different view.

When you are learning a topic — say, Rust ownership, or dynamic programming patterns — the real problem is not long-term retention. The real problem is **staying connected to earlier concepts as you learn new ones**. You learn closures on Monday, move on to iterators on Wednesday, and by Friday you have forgotten how closures worked. The links between ideas break down.

This is what mnemonic.nvim is designed to prevent. Cards belong to a **topic**, and a topic has a **lifecycle**:

- **Active** — you are currently studying this topic. Cards are scheduled and reviewed.
- **Archived** — you have finished this topic. Cards are no longer reviewed, but remain in your data.

When you finish a course, close a project, or move on from a subject, you archive the topic. The review burden disappears. The knowledge you built stays in your notes.

### Quality over quantity

The most important design decision in mnemonic.nvim is the **daily card limit**.

Each topic has a daily limit (default: 5 cards per day). Once you reach it, you cannot create more cards for that topic until tomorrow.

This constraint is intentional. It forces a question: *of everything I learned today, what is the single most important thing to remember?*

A person who can ask a precise, well-formed question understands the material more deeply than a person who can recite the answer. The daily limit is not a restriction — it is a tool for developing that skill.

### Cards are thinking, not transcription

The answer field in a mnemonic card is not a definition copied from a textbook. It is **your own condensed thinking** — the way you understood something, in your own words, at the moment you learned it.

This matters because memory is reconstructive. When you review a card, you are not reading a fact — you are re-activating the neural network that formed when you first understood the concept. A card written in your own voice re-activates that network more effectively than a card written in someone else's.

Use backlinks to connect the card to your notes. The answer field should be your thinking, not a transcript.

### The neuroscience behind the design

Every design decision in mnemonic.nvim is grounded in how memory actually works:

**Testing Effect** — Retrieving information from memory strengthens it far more than re-reading. Every review session in mnemonic.nvim is an act of retrieval: you see the question, you think, then you reveal the answer. The thinking is the learning.

**Spacing Effect** — Memories consolidate more effectively when review is distributed over time. The FSRS algorithm calculates the optimal moment to review each card — just before you would forget it — maximizing the benefit of each session.

**Desirable Difficulty** — Learning feels harder when it is spaced out and interleaved. That difficulty is not a problem. It is the mechanism. mnemonic.nvim does not make review easy. It makes review effective.

**Stability and Retrievability** — FSRS models memory using two dimensions: *stability* (how long a memory lasts before decaying) and *retrievability* (the probability of recall right now). Each review updates both. Cards reviewed just before forgetting gain the most stability.

---

## 3. Installation

### Requirements

- Neovim 0.9+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) — for backlink selection
- [dressing.nvim](https://github.com/stevearc/dressing.nvim) — recommended for better UI inputs

### Using lazy.nvim

```lua
{
  "Yeijon/mnemonic.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "stevearc/dressing.nvim",  -- optional but recommended
  },
  config = function()
    require("mnemonic").setup({
      -- Path to your notes vault, backlinks selector root path
      vault = "~/notes",

      -- Max cards you can create per topic per day
      daily_limit = 5,

      -- FSRS target retrievability (0.9 = review at 90% recall probability)
      target_retrievability = 0.9,

      -- Keymaps (customize as needed)
      keymaps = {
        new_card = "<leader>nca",  -- Add a new card
        review   = "<leader>ncr",  -- Start a review session
        manage   = "<leader>nct",  -- Manage topics
        cards    = "<leader>ncm",  -- Browse / edit / delete cards
      },
    })
  end,
}
```

### Using packer.nvim

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

### Data location

Cards and topics are stored as JSON in `<vault>/.mnemonic/`:

```
notes/
└── .mnemonic/
    ├── topics.json
    └── cards.json
```

These are plain JSON files. You can inspect, back up, or version-control them alongside your notes.

---

## 4. Usage

### Keymaps

| Key | Action |
|-----|--------|
| `<leader>nca` | Create a new card |
| `<leader>ncr` | Start a review session |
| `<leader>ncm` | Browse, edit, or delete cards |
| `<leader>nct` | Manage topics (archive, reactivate, delete) |

### Commands

| Command | Action |
|---------|--------|
| `:MnemonicNew` | Create a new card |
| `:MnemonicReview` | Start a review session |
| `:MnemonicCards` | Browse / edit / delete cards |
| `:MnemonicManage` | Manage topics |

### Creating a card

1. Press `:MnemonicNew`
2. Select an existing topic or create a new one
3. Your daily quota is shown — e.g. `2/5 used today`
4. Use Telescope to select backlinks (notes related to this card)
   - `<CR>` — add a file to backlinks, picker stays open
   - `<C-z>` — undo the last added backlink
   - `<C-d>` — done selecting, open the editor
   - `<Esc>` — skip backlinks, open the editor directly
   - `<C-b>` — go back to topic selection
5. Write your question under `# Question` and your answer under `# Answer`
6. Press `:wq` to save

![](assets/2026-03-15-19-17-55.png)

### Reviewing

1. Press `:MnemonicReview`
2. Choose to review a specific topic or all active topics
3. Read the question — think before revealing
4. Press `<Space>` to reveal the answer
5. If the card has backlinks, press `o1`, `o2`... to open the linked note in a vertical split
6. Rate your recall honestly:
   - `1` Again — could not recall
   - `2` Hard — recalled with significant effort
   - `3` Good — recalled correctly
   - `4` Easy — recalled instantly

![](assets/2026-03-15-19-36-46.png)

### Managing cards

Press `:MnemonicCards` to browse cards by topic. Select a card to:

- `e` — edit question and answer, `:wq` to save
- `d` — delete the card (with confirmation)
- `a` — archive or restore the card
- `q` — close

![](assets/2026-03-15-19-38-15.png)

![](assets/2026-03-15-19-38-49.png)

### Topic lifecycle

Press `:MnemonicManage` to manage topics:

- **Archive** — stops scheduling all cards in the topic
- **Reactivate** — resumes scheduling
- **Delete** — permanently removes the topic and all its cards

![](assets/2026-03-15-19-39-51.png)

---

## 5. FSRS Algorithm

mnemonic.nvim implements a simplified version of [FSRS](https://github.com/open-spaced-repetition/fsrs4anki) (Free Spaced Repetition Scheduler), the algorithm now used by default in Anki.

Each card tracks:

| Field | Description |
|-------|-------------|
| `stability` | How long the memory lasts before decaying |
| `difficulty` | How hard the card is to recall (0.1 = easy, 1.0 = hard) |
| `due` | The next review date |
| `state` | `new` / `learning` / `review` / `relearning` |
| `reps` | Total number of reviews |
| `lapses` | Number of times the card was forgotten |

The next review interval is calculated to maintain a 90% recall probability:

```
interval = -stability × ln(0.9)
```

---

## License

MIT
