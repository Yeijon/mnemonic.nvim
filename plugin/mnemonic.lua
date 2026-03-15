-- plugin/mnemonic.lua: Register commands and keymaps

if vim.g.loaded_mnemonic then return end
vim.g.loaded_mnemonic = true

local function safe_call(fn)
  return function()
    vim.schedule(function()
      local ok, err = pcall(fn)
      if not ok then
        vim.notify("mnemonic: " .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end
end

local function setup_keymaps()
  local opts = require("mnemonic.config").options
  local ui   = require("mnemonic.ui")

  vim.keymap.set("n", opts.keymaps.review,   safe_call(ui.start_review),  { desc = "Review cards" })
  vim.keymap.set("n", opts.keymaps.new_card, safe_call(ui.new_card),      { desc = "Add card" })
  vim.keymap.set("n", opts.keymaps.manage,   safe_call(ui.manage_topics), { desc = "Manage topics" })
  vim.keymap.set("n", opts.keymaps.cards,    safe_call(ui.manage_cards),  { desc = "Manage cards" })
end

vim.api.nvim_create_user_command("MnemonicReview",  safe_call(function() require("mnemonic.ui").start_review()  end), { desc = "Start review session" })
vim.api.nvim_create_user_command("MnemonicNew",     safe_call(function() require("mnemonic.ui").new_card()      end), { desc = "Create new card" })
vim.api.nvim_create_user_command("MnemonicManage",  safe_call(function() require("mnemonic.ui").manage_topics() end), { desc = "Manage topics" })
vim.api.nvim_create_user_command("MnemonicCards",   safe_call(function() require("mnemonic.ui").manage_cards()  end), { desc = "Manage cards" })

vim.api.nvim_create_autocmd("VimEnter", {
  once     = true,
  callback = function()
    local config = require("mnemonic.config")
    if vim.tbl_isempty(config.options) then
      config.setup({})
    end
    setup_keymaps()
  end,
})
