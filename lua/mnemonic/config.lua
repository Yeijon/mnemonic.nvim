-- mnemonic.nvim - A FSRS-based spaced repetition plugin for Neovim
-- config.lua: Default configuration

local M = {}

M.defaults = {
  -- Path to store data files (relative to vault root)
  data_dir = ".mnemonic",

  -- Vault root path (defaults to current working directory)
  vault = vim.fn.getcwd(),

  -- Daily card creation limit per topic
  daily_limit = 5,

  -- FSRS target retrievability (0.9 = review when 90% chance of recall)
  target_retrievability = 0.9,

  -- Keymaps
  keymaps = {
    review   = "<leader>ncr",
    new_card = "<leader>nca",
    manage   = "<leader>nct",
    cards    = "<leader>ncm",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
