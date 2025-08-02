-- to autoamtically to the plugin at startup
vim.api.nvim_create_user_command("Present", function()
	require("present").start_presentation()
end, {})
-- or, above line can be added in user config
