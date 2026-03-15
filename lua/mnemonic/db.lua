-- db.lua: Data layer - read/write JSON files for topics and cards

local M = {}
local config = require("mnemonic.config")

local function data_path(filename)
  local vault = config.options.vault
  local dir = vault .. "/" .. config.options.data_dir
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. filename
end

-- Read JSON file, return parsed table or default
local function read_json(filepath, default)
  local f = io.open(filepath, "r")
  if not f then return default end
  local content = f:read("*a")
  f:close()
  if content == "" then return default end
  local ok, data = pcall(vim.fn.json_decode, content)
  return ok and data or default
end

-- Write table as JSON file
local function write_json(filepath, data)
  local f = io.open(filepath, "w")
  if not f then
    vim.notify("mnemonic: failed to write " .. filepath, vim.log.levels.ERROR)
    return false
  end
  f:write(vim.fn.json_encode(data))
  f:close()
  return true
end

-- ── Topics ────────────────────────────────────────────────────────────────

function M.load_topics()
  return read_json(data_path("topics.json"), { topics = {} })
end

function M.save_topics(data)
  return write_json(data_path("topics.json"), data)
end

function M.get_active_topics()
  local data = M.load_topics()
  local active = {}
  for _, t in ipairs(data.topics) do
    if t.status == "active" then
      table.insert(active, t)
    end
  end
  return active
end

function M.create_topic(name, notes_path)
  local data = M.load_topics()
  local topic = {
    topic_id   = "t-" .. os.date("%Y%m%d") .. "-" .. math.random(1000, 9999),
    name       = name,
    status     = "active",
    daily_limit = config.options.daily_limit,
    created_at = os.date("%Y-%m-%d"),
    archived_at = nil,
    notes_path = notes_path or "",
  }
  table.insert(data.topics, topic)
  M.save_topics(data)
  return topic
end

function M.archive_topic(topic_id)
  local data = M.load_topics()
  for _, t in ipairs(data.topics) do
    if t.topic_id == topic_id then
      t.status = "archived"
      t.archived_at = os.date("%Y-%m-%d")
    end
  end
  M.save_topics(data)
  -- Also archive all cards under this topic
  local cards_data = M.load_cards()
  for _, c in ipairs(cards_data.cards) do
    if c.topic_id == topic_id then
      c.status = "archived"
    end
  end
  M.save_cards(cards_data)
end

-- ── Cards ─────────────────────────────────────────────────────────────────

function M.load_cards()
  return read_json(data_path("cards.json"), { cards = {} })
end

function M.save_cards(data)
  return write_json(data_path("cards.json"), data)
end

function M.get_cards_by_topic(topic_id)
  local data = M.load_cards()
  local result = {}
  for _, c in ipairs(data.cards) do
    if c.topic_id == topic_id then
      table.insert(result, c)
    end
  end
  return result
end

function M.get_active_cards(topic_id)
  local data = M.load_cards()
  local result = {}
  for _, c in ipairs(data.cards) do
    local match = topic_id == nil or c.topic_id == topic_id
    if c.status == "active" and match then
      table.insert(result, c)
    end
  end
  return result
end

function M.create_card(topic_id, question, answer, backlinks)
  local data = M.load_cards()
  local card = {
    card_id   = "c-" .. os.date("%Y%m%d") .. "-" .. math.random(1000, 9999),
    topic_id  = topic_id,
    question  = question,
    answer    = answer,
    status    = "active",
    backlinks = backlinks or {},
    created_at = os.date("%Y-%m-%d"),
    fsrs = {
      stability  = 0,
      difficulty = 0.3,
      due        = os.date("%Y-%m-%d"),
      last_review = nil,
      reps       = 0,
      lapses     = 0,
      state      = "new",
    },
  }
  table.insert(data.cards, card)
  M.save_cards(data)
  return card
end

function M.update_card(card)
  local data = M.load_cards()
  for i, c in ipairs(data.cards) do
    if c.card_id == card.card_id then
      data.cards[i] = card
      break
    end
  end
  M.save_cards(data)
end

-- Count cards created today for a topic
function M.cards_created_today(topic_id)
  local data = M.load_cards()
  local today = os.date("%Y-%m-%d")
  local count = 0
  for _, c in ipairs(data.cards) do
    if c.topic_id == topic_id and c.created_at == today then
      count = count + 1
    end
  end
  return count
end

return M
