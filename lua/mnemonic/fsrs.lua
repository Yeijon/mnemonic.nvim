-- fsrs.lua: FSRS algorithm implementation
-- Based on the Free Spaced Repetition Scheduler (FSRS v4)
-- Core concepts:
--   Stability (S): how long memory lasts before forgetting
--   Difficulty (D): how hard the card is to remember (0.1 ~ 1.0)
--   Retrievability (R): probability of recall at time t = e^(-t/S)

local M = {}
local config = require("mnemonic.config")

-- Initial stability after first review, indexed by rating (1=Again, 2=Hard, 3=Good, 4=Easy)
local INIT_STABILITY  = { 0.4, 1.2, 2.4, 5.0 }
local INIT_DIFFICULTY = { 0.8, 0.6, 0.4, 0.2 }

-- Stability increase factor per rating
local STABILITY_FACTOR = { 0.1, 0.2, 0.4, 0.8 }

-- Calculate next review interval in days to maintain target retrievability
function M.next_interval(stability)
  local r = config.options.target_retrievability
  -- R(t) = e^(-t/S) => t = -S * ln(R)
  local interval = math.floor(-stability * math.log(r))
  return math.max(1, interval)
end

-- Calculate current retrievability given stability and days since last review
function M.retrievability(stability, days_elapsed)
  if stability <= 0 then return 0 end
  return math.exp(-days_elapsed / stability)
end

-- Update card FSRS state after a review
-- rating: 1=Again, 2=Hard, 3=Good, 4=Easy
function M.update(card, rating)
  local fsrs = vim.deepcopy(card.fsrs)
  local today = os.date("%Y-%m-%d")

  if fsrs.state == "new" then
    -- First time seeing this card
    fsrs.stability  = INIT_STABILITY[rating]
    fsrs.difficulty = INIT_DIFFICULTY[rating]
    fsrs.state      = (rating == 1) and "learning" or "review"

  elseif fsrs.state == "learning" or fsrs.state == "relearning" then
    -- Still in learning phase
    if rating >= 3 then
      fsrs.stability = fsrs.stability * (1 + STABILITY_FACTOR[rating])
      fsrs.state     = "review"
    else
      fsrs.stability = math.max(0.4, fsrs.stability * 0.5)
    end

  else
    -- Mature card in review phase
    local recalled = rating >= 3
    if recalled then
      -- Successful recall: increase stability based on difficulty and rating
      local bonus = (1 + STABILITY_FACTOR[rating]) * (1.1 - fsrs.difficulty)
      fsrs.stability = fsrs.stability * math.max(1.1, bonus * 2)
    else
      -- Forgotten: reset stability, increase difficulty
      fsrs.lapses    = fsrs.lapses + 1
      fsrs.stability = math.max(0.4, fsrs.stability * 0.2)
      fsrs.state     = "relearning"
    end

    -- Adjust difficulty: harder if forgotten, easier if recalled well
    fsrs.difficulty = math.max(0.1, math.min(1.0,
      fsrs.difficulty + 0.1 * (3 - rating) * 0.1
    ))
  end

  fsrs.reps        = fsrs.reps + 1
  fsrs.last_review = today

  local interval = M.next_interval(fsrs.stability)
  local due_time  = os.time() + interval * 86400
  fsrs.due        = os.date("%Y-%m-%d", due_time)

  card.fsrs = fsrs
  return card
end

-- Get all cards due today or overdue from a list
function M.due_cards(cards, topic_id)
  local today = os.date("%Y-%m-%d")
  local due = {}
  for _, card in ipairs(cards) do
    local match = (topic_id == nil or card.topic_id == topic_id)
    if card.status == "active" and match and card.fsrs.due <= today then
      table.insert(due, card)
    end
  end
  -- Sort: overdue first, then by due date
  table.sort(due, function(a, b) return a.fsrs.due < b.fsrs.due end)
  return due
end

-- Summary stats for a topic
function M.stats(cards, topic_id)
  local today = os.date("%Y-%m-%d")
  local total, due_count, new_count, review_count = 0, 0, 0, 0
  for _, card in ipairs(cards) do
    local match = (topic_id == nil or card.topic_id == topic_id)
    if card.status == "active" and match then
      total = total + 1
      if card.fsrs.state == "new" then new_count = new_count + 1 end
      if card.fsrs.due <= today then due_count = due_count + 1 end
      if card.fsrs.state == "review" then review_count = review_count + 1 end
    end
  end
  return {
    total   = total,
    due     = due_count,
    new     = new_count,
    review  = review_count,
  }
end

return M
