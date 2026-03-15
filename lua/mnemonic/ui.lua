-- ui.lua: Floating window UI for review and card creation

local M = {}
local db   = require("mnemonic.db")
local fsrs = require("mnemonic.fsrs")
local config = require("mnemonic.config")

-- ── Helpers ───────────────────────────────────────────────────────────────

local function create_float(lines, opts)
  local width  = opts.width or 60
  local height = #lines + 2
  local buf    = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width    = width,
    height   = height,
    row      = math.floor((vim.o.lines - height) / 2),
    col      = math.floor((vim.o.columns - width) / 2),
    border   = "rounded",
    style    = "minimal",
    title    = opts.title or " mnemonic ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
  return buf, win
end

local function close_float(buf, win)
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
end

local function center_text(text, width)
  local pad = math.floor((width - #text) / 2)
  return string.rep(" ", math.max(0, pad)) .. text
end

local function wrap_text(text, width)
  local lines = {}
  local line = ""
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width then
      table.insert(lines, line)
      line = word
    else
      line = line == "" and word or (line .. " " .. word)
    end
  end
  if line ~= "" then table.insert(lines, line) end
  return lines
end

-- ── Topic Selector ────────────────────────────────────────────────────────

local function select_topic(callback)
  local topics = db.get_active_topics()
  if #topics == 0 then
    vim.ui.input({ prompt = "No active topics. Create one (name): " }, function(name)
      if not name or name == "" then return end
      local topic = db.create_topic(name)
      callback(topic)
    end)
    return
  end

  local choices = {}
  for _, t in ipairs(topics) do
    local cards = db.get_active_cards(t.topic_id)
    local stats = fsrs.stats(cards, t.topic_id)
    table.insert(choices, string.format("%-25s  due:%-3d  total:%-3d", t.name, stats.due, stats.total))
  end
  table.insert(choices, "+ New topic")

  vim.ui.select(choices, { prompt = "Select topic:" }, function(choice, idx)
    if not choice then return end
    if idx == #choices then
      vim.ui.input({ prompt = "New topic name: " }, function(name)
        if not name or name == "" then return end
        local topic = db.create_topic(name)
        callback(topic)
      end)
    else
      callback(topics[idx])
    end
  end)
end

-- ── Review Session ────────────────────────────────────────────────────────

local function show_review(cards, index, session_stats)
  if index > #cards then
    -- Session complete
    local lines = {
      "",
      center_text("Session Complete!", 58),
      "",
      center_text(string.format("Reviewed: %d cards", session_stats.reviewed), 58),
      center_text(string.format("Again: %d  Hard: %d  Good: %d  Easy: %d",
        session_stats.again, session_stats.hard,
        session_stats.good, session_stats.easy), 58),
      "",
      center_text("Press any key to close", 58),
      "",
    }
    local buf, win = create_float(lines, { title = " mnemonic — done ", width = 60 })
    vim.keymap.set("n", "<CR>", function() close_float(buf, win) end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "q",    function() close_float(buf, win) end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "<Esc>",function() close_float(buf, win) end, { buffer = buf, nowait = true })
    return
  end

  local card  = cards[index]
  local W     = 60
  local q_lines = wrap_text(card.question, W - 4)

  local lines = { "" }
  local title = string.format(" [%d/%d] ", index, #cards)

  for _, l in ipairs(q_lines) do
    table.insert(lines, "  " .. l)
  end
  table.insert(lines, "")
  table.insert(lines, center_text("─────────────────────────────", W))
  table.insert(lines, center_text("<Space> to reveal answer", W))
  table.insert(lines, "")

  local buf, win = create_float(lines, { title = title, width = W })

  -- Reveal answer
  vim.keymap.set("n", "<Space>", function()
    close_float(buf, win)

    local a_lines = wrap_text(card.answer, W - 4)
    local reveal  = { "" }
    for _, l in ipairs(q_lines) do table.insert(reveal, "  " .. l) end
    table.insert(reveal, "")
    table.insert(reveal, "  " .. string.rep("─", W - 4))
    table.insert(reveal, "")
    for _, l in ipairs(a_lines) do table.insert(reveal, "  " .. l) end

    -- Backlinks with jump shortcuts
    if #card.backlinks > 0 then
      table.insert(reveal, "")
      table.insert(reveal, "  Links:")
      for i, link in ipairs(card.backlinks) do
        table.insert(reveal, string.format("    [o%d] %s", i, link))
      end
    end

    table.insert(reveal, "")
    table.insert(reveal, center_text("[1] Again  [2] Hard  [3] Good  [4] Easy", W))
    table.insert(reveal, "")

    local rbuf, rwin = create_float(reveal, { title = title, width = W })

    local function rate(rating)
      close_float(rbuf, rwin)
      local labels = { "again", "hard", "good", "easy" }
      session_stats.reviewed = session_stats.reviewed + 1
      session_stats[labels[rating]] = session_stats[labels[rating]] + 1

      local updated = fsrs.update(card, rating)
      db.update_card(updated)
      show_review(cards, index + 1, session_stats)
    end

    vim.keymap.set("n", "1", function() rate(1) end, { buffer = rbuf, nowait = true })
    vim.keymap.set("n", "2", function() rate(2) end, { buffer = rbuf, nowait = true })
    vim.keymap.set("n", "3", function() rate(3) end, { buffer = rbuf, nowait = true })
    vim.keymap.set("n", "4", function() rate(4) end, { buffer = rbuf, nowait = true })
    vim.keymap.set("n", "q", function() close_float(rbuf, rwin) end, { buffer = rbuf, nowait = true })

    -- Jump to backlink: o1, o2, o3...
    for i, link in ipairs(card.backlinks) do
      vim.keymap.set("n", "o" .. i, function()
        local vault = config.options.vault
        local path  = vault .. "/" .. link
        vim.cmd("vsplit " .. vim.fn.fnameescape(path))
      end, { buffer = rbuf, nowait = true, desc = "Open link " .. i })
    end

  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "q", function() close_float(buf, win) end, { buffer = buf, nowait = true })
end

function M.start_review()
  local all_cards = db.load_cards().cards

  vim.ui.select(
    { "Review specific topic", "Review all active topics" },
    { prompt = "Review mode:" },
    function(choice, idx)
      if not choice then return end

      if idx == 1 then
        select_topic(function(topic)
          local due = fsrs.due_cards(all_cards, topic.topic_id)
          if #due == 0 then
            vim.notify("No cards due for: " .. topic.name, vim.log.levels.INFO)
            return
          end
          show_review(due, 1, { reviewed=0, again=0, hard=0, good=0, easy=0 })
        end)
      else
        local due = fsrs.due_cards(all_cards, nil)
        if #due == 0 then
          vim.notify("No cards due today!", vim.log.levels.INFO)
          return
        end
        show_review(due, 1, { reviewed=0, again=0, hard=0, good=0, easy=0 })
      end
    end
  )
end

-- ── Card Creation ─────────────────────────────────────────────────────────

-- Open a large floating buffer for editing question and answer
-- Template lines are pre-filled; user edits and saves with :wq
local function open_card_editor(topic, used, limit, backlinks)
  local W, H = 70, 20
  local buf  = vim.api.nvim_create_buf(false, true)

  local template = {
    "# Question",
    "",
    "",
    "",
    "# Answer",
    "",
    "",
    "",
    "─────────────────────────────────────────────────────────────────",
    "  Write your question and answer above.",
    "  <leader>s to save card.  q to cancel.",
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, template)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = W,
    height    = H,
    row       = math.floor((vim.o.lines - H) / 2),
    col       = math.floor((vim.o.columns - W) / 2),
    border    = "rounded",
    title     = string.format(" New Card — %s  [%d/%d today] ", topic.name, used, limit),
    title_pos = "center",
  })

  -- Place cursor on line 3 (question body)
  vim.api.nvim_win_set_cursor(win, { 3, 0 })
  vim.schedule(function() vim.cmd("startinsert") end)

  local saved = false

  local function save_card()
    if saved then return end
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

      local question_lines, answer_lines = {}, {}
      local section = nil
      for _, line in ipairs(lines) do
        if line == "# Question" then
          section = "q"
        elseif line == "# Answer" then
          section = "a"
        elseif line:match("^─") then
          break
        elseif section == "q" and line ~= "" then
          table.insert(question_lines, line)
        elseif section == "a" and line ~= "" then
          table.insert(answer_lines, line)
        end
      end

      local question = table.concat(question_lines, "\n")
      local answer   = table.concat(answer_lines, "\n")

      if question == "" or answer == "" then
        vim.notify("Question or answer is empty — card not saved.", vim.log.levels.WARN)
        return
      end

      saved = true
      db.create_card(topic.topic_id, question, answer, backlinks)
      vim.notify(
        string.format("Card created! [%d/%d used today]", used + 1, limit),
        vim.log.levels.INFO
      )
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
  end

  vim.keymap.set({ "n", "i" }, "<leader>s", save_card, { buffer = buf, nowait = true, desc = "Save card" })
  vim.keymap.set("n", "<leader>b", function()
    vim.api.nvim_win_close(win, true)
    pick_backlinks(topic, used, limit)
  end, { buffer = buf, nowait = true, desc = "Back to backlinks" })
  vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf, nowait = true })
end

-- Pick backlinks via Telescope, then open card editor
local function pick_backlinks(topic, used, limit)
  local vault = config.options.vault
  local ok, telescope = pcall(require, "telescope.builtin")

  if not ok then
    open_card_editor(topic, used, limit, {})
    return
  end

  local backlinks = {}

  local function reopen()
    local title = #backlinks > 0
      and string.format("Backlinks (%d selected: %s)", #backlinks, table.concat(backlinks, ", "))
      or  "Select backlinks — <CR> add, <C-z> undo, <C-d> done, <Esc> skip, <C-b> back"

    telescope.find_files({
      prompt_title    = title,
      cwd             = vault,
      attach_mappings = function(prompt_buf, map)
        local actions      = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        -- <CR>: add one file, reopen picker
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          if entry then
            table.insert(backlinks, entry.value)
          end
          actions.close(prompt_buf)
          reopen()
        end)

        -- <C-z>: undo last backlink
        map("i", "<C-z>", function()
          if #backlinks > 0 then
            local removed = table.remove(backlinks)
            vim.notify("Removed: " .. removed, vim.log.levels.INFO)
          else
            vim.notify("Nothing to undo.", vim.log.levels.WARN)
          end
          actions.close(prompt_buf)
          reopen()
        end)
        map("n", "<C-z>", function()
          if #backlinks > 0 then
            local removed = table.remove(backlinks)
            vim.notify("Removed: " .. removed, vim.log.levels.INFO)
          else
            vim.notify("Nothing to undo.", vim.log.levels.WARN)
          end
          actions.close(prompt_buf)
          reopen()
        end)

        -- <C-d>: done, open editor
        map("i", "<C-d>", function()
          actions.close(prompt_buf)
          open_card_editor(topic, used, limit, backlinks)
        end)
        map("n", "<C-d>", function()
          actions.close(prompt_buf)
          open_card_editor(topic, used, limit, backlinks)
        end)

        -- <Esc>: skip backlinks, open editor directly
        map("i", "<Esc>", function()
          actions.close(prompt_buf)
          open_card_editor(topic, used, limit, backlinks)
        end)
        map("n", "<Esc>", function()
          actions.close(prompt_buf)
          open_card_editor(topic, used, limit, backlinks)
        end)

        -- <C-b>: back to topic selection
        map("i", "<C-b>", function()
          actions.close(prompt_buf)
          M.new_card()
        end)
        map("n", "<C-b>", function()
          actions.close(prompt_buf)
          M.new_card()
        end)

        return true
      end,
    })
  end

  reopen()
end

function M.new_card()
  select_topic(function(topic)
    local used  = db.cards_created_today(topic.topic_id)
    local limit = topic.daily_limit or config.options.daily_limit

    if used >= limit then
      vim.notify(
        string.format("Daily limit reached for '%s' (%d/%d). Make them count!", topic.name, used, limit),
        vim.log.levels.WARN
      )
      return
    end

    pick_backlinks(topic, used, limit)
  end)
end

-- ── Topic Management ──────────────────────────────────────────────────────

function M.manage_topics()
  local topics = db.load_topics().topics
  if #topics == 0 then
    vim.notify("No topics yet. Create one with <leader>nq", vim.log.levels.INFO)
    return
  end

  local choices = {}
  for _, t in ipairs(topics) do
    local status = t.status == "active" and "active" or "archived"
    table.insert(choices, string.format("[%s] %s", status, t.name))
  end

  vim.ui.select(choices, { prompt = "Manage topic:" }, function(choice, idx)
    if not choice then return end
    local topic = topics[idx]

    local actions = topic.status == "active"
      and { "Archive topic", "Delete topic (and all cards)", "Cancel" }
      or  { "Reactivate topic", "Delete topic (and all cards)", "Cancel" }

    vim.ui.select(actions, { prompt = topic.name .. ":" }, function(action, aidx)
      if not action or action == "Cancel" then return end

      if action == "Delete topic (and all cards)" then
        vim.ui.select(
          { "Yes, delete everything", "Cancel" },
          { prompt = "Delete '" .. topic.name .. "' and ALL its cards?" },
          function(confirm, cidx)
            if cidx ~= 1 then return end
            -- Delete all cards under this topic
            local cards_data = db.load_cards()
            local remaining = {}
            for _, c in ipairs(cards_data.cards) do
              if c.topic_id ~= topic.topic_id then
                table.insert(remaining, c)
              end
            end
            cards_data.cards = remaining
            db.save_cards(cards_data)
            -- Delete topic
            local topics_data = db.load_topics()
            local remaining_topics = {}
            for _, t in ipairs(topics_data.topics) do
              if t.topic_id ~= topic.topic_id then
                table.insert(remaining_topics, t)
              end
            end
            topics_data.topics = remaining_topics
            db.save_topics(topics_data)
            vim.notify("Deleted topic and all cards: " .. topic.name, vim.log.levels.INFO)
          end
        )
      elseif topic.status == "active" then
        db.archive_topic(topic.topic_id)
        vim.notify("Archived: " .. topic.name, vim.log.levels.INFO)
      else
        local data = db.load_topics()
        for _, t in ipairs(data.topics) do
          if t.topic_id == topic.topic_id then
            t.status = "active"
            t.archived_at = nil
          end
        end
        db.save_topics(data)
        vim.notify("Reactivated: " .. topic.name, vim.log.levels.INFO)
      end
    end)
  end)
end

-- ── Card Management (Browse / Edit / Delete) ─────────────────────────────

function M.manage_cards()
  -- Step 1: select topic
  local topics = db.get_active_topics()
  local all_topics = db.load_topics().topics
  if #all_topics == 0 then
    vim.notify("No topics yet.", vim.log.levels.INFO)
    return
  end

  local choices = {}
  for _, t in ipairs(all_topics) do
    local status = t.status == "active" and "" or " [archived]"
    local count  = #db.get_cards_by_topic(t.topic_id)
    table.insert(choices, string.format("%-25s  %d cards%s", t.name, count, status))
  end

  vim.ui.select(choices, { prompt = "Select topic to browse:" }, function(_, tidx)
    if not tidx then return end
    local topic = all_topics[tidx]
    local cards = db.get_cards_by_topic(topic.topic_id)

    if #cards == 0 then
      vim.notify("No cards in: " .. topic.name, vim.log.levels.INFO)
      return
    end

    -- Step 2: list cards
    local card_choices = {}
    for _, c in ipairs(cards) do
      local status = c.status == "active" and "" or " [archived]"
      local due    = c.fsrs.due or "new"
      table.insert(card_choices, string.format("[due:%s]%s  %s", due, status, c.question))
    end

    vim.ui.select(card_choices, { prompt = "Select card:" }, function(_, cidx)
      if not cidx then return end
      local card = cards[cidx]

      -- Step 3: show card detail with markdown rendering
      local W, H = 70, 25
      local buf  = vim.api.nvim_create_buf(false, true)

      local lines = {
        "## Question",
        "",
      }
      for _, l in ipairs(vim.split(card.question, "\n")) do
        table.insert(lines, l)
      end
      table.insert(lines, "")
      table.insert(lines, "---")
      table.insert(lines, "")
      table.insert(lines, "## Answer")
      table.insert(lines, "")
      for _, l in ipairs(vim.split(card.answer, "\n")) do
        table.insert(lines, l)
      end
      if #card.backlinks > 0 then
        table.insert(lines, "")
        table.insert(lines, "## Links")
        table.insert(lines, "")
        for _, link in ipairs(card.backlinks) do
          table.insert(lines, "- " .. link)
        end
      end
      table.insert(lines, "")
      table.insert(lines, "---")
      table.insert(lines, "")
      table.insert(lines, string.format(
        "> due: %s  |  stability: %.1f  |  reps: %d  |  state: %s",
        card.fsrs.due, card.fsrs.stability, card.fsrs.reps, card.fsrs.state
      ))
      table.insert(lines, "")
      table.insert(lines, "`e` Edit   `d` Delete   `a` Archive/Restore   `q` Close")

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_set_option_value("filetype",   "markdown", { buf = buf })
      vim.api.nvim_set_option_value("modifiable", false,      { buf = buf })
      vim.api.nvim_set_option_value("bufhidden",  "wipe",     { buf = buf })
      vim.api.nvim_set_option_value("buftype",    "nofile",   { buf = buf })

      local win = vim.api.nvim_open_win(buf, true, {
        relative  = "editor",
        width     = W,
        height    = H,
        row       = math.floor((vim.o.lines - H) / 2),
        col       = math.floor((vim.o.columns - W) / 2),
        border    = "rounded",
        title     = string.format(" %s ", topic.name),
        title_pos = "center",
      })
      vim.api.nvim_set_option_value("wrap",      true,  { win = win })
      vim.api.nvim_set_option_value("linebreak", true,  { win = win })
      vim.api.nvim_set_option_value("cursorline", false, { win = win })

      -- Edit card
      vim.keymap.set("n", "e", function()
        close_float(buf, win)

        local ebuf = vim.api.nvim_create_buf(false, true)
        local template = {
          "# Question",
          "",
          card.question,
          "",
          "# Answer",
          "",
          card.answer,
          "",
          "─────────────────────────────────────────────────────────────────",
          "  Edit question and answer above.",
          "  <leader>s to save.  q to cancel.",
        }
        vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, template)
        vim.api.nvim_set_option_value("filetype",  "markdown", { buf = ebuf })
        vim.api.nvim_set_option_value("bufhidden", "wipe",     { buf = ebuf })
        vim.api.nvim_set_option_value("buftype",   "nofile",   { buf = ebuf })

        local EW, EH = 70, 20
        local ewin = vim.api.nvim_open_win(ebuf, true, {
          relative  = "editor",
          width     = EW,
          height    = EH,
          row       = math.floor((vim.o.lines - EH) / 2),
          col       = math.floor((vim.o.columns - EW) / 2),
          border    = "rounded",
          title     = " Edit Card ",
          title_pos = "center",
        })
        vim.api.nvim_win_set_cursor(ewin, { 3, 0 })
        vim.schedule(function() vim.cmd("startinsert") end)

        local saved = false

        local function save_edit()
          if saved then return end
          if not vim.api.nvim_buf_is_valid(ebuf) then return end
          local elines = vim.api.nvim_buf_get_lines(ebuf, 0, -1, false)
          local q_lines2, a_lines2 = {}, {}
          local section = nil
          for _, line in ipairs(elines) do
            if line == "# Question" then section = "q"
            elseif line == "# Answer" then section = "a"
            elseif line:match("^─") then break
            elseif section == "q" and line ~= "" then table.insert(q_lines2, line)
            elseif section == "a" and line ~= "" then table.insert(a_lines2, line)
            end
          end
          local new_q = table.concat(q_lines2, "\n")
          local new_a = table.concat(a_lines2, "\n")
          if new_q == "" or new_a == "" then
            vim.notify("Question or answer empty — not saved.", vim.log.levels.WARN)
            return
          end
          saved = true
          card.question = new_q
          card.answer   = new_a
          db.update_card(card)
          vim.notify("Card updated.", vim.log.levels.INFO)
          if vim.api.nvim_win_is_valid(ewin) then
            vim.api.nvim_win_close(ewin, true)
          end
        end

        local function cancel_edit()
          if vim.api.nvim_win_is_valid(ewin) then
            vim.api.nvim_win_close(ewin, true)
          end
        end

        vim.keymap.set({ "n", "i" }, "<leader>s", save_edit,   { buffer = ebuf, nowait = true })
        vim.keymap.set("n",          "q",          cancel_edit, { buffer = ebuf, nowait = true })
        vim.keymap.set("n",          "<Esc>",      cancel_edit, { buffer = ebuf, nowait = true })
      end, { buffer = buf, nowait = true })

      -- Delete card
      vim.keymap.set("n", "d", function()
        vim.ui.select({ "Yes, delete", "Cancel" }, { prompt = "Delete this card?" }, function(_, idx)
          if idx == 1 then
            local data = db.load_cards()
            for i, c in ipairs(data.cards) do
              if c.card_id == card.card_id then
                table.remove(data.cards, i)
                break
              end
            end
            db.save_cards(data)
            vim.notify("Card deleted.", vim.log.levels.INFO)
            close_float(buf, win)
          end
        end)
      end, { buffer = buf, nowait = true })

      -- Archive card
      vim.keymap.set("n", "a", function()
        local new_status = card.status == "active" and "archived" or "active"
        card.status = new_status
        db.update_card(card)
        vim.notify("Card " .. new_status .. ".", vim.log.levels.INFO)
        close_float(buf, win)
      end, { buffer = buf, nowait = true })

      vim.keymap.set("n", "q",     function() close_float(buf, win) end, { buffer = buf, nowait = true })
      vim.keymap.set("n", "<Esc>", function() close_float(buf, win) end, { buffer = buf, nowait = true })
    end)
  end)
end

return M
