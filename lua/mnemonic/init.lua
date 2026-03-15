-- init.lua: Plugin entry point

local M = {}

function M.setup(opts)
  require("mnemonic.config").setup(opts)
end

return M
