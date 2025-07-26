local M = {}

local function create_floating_window(config, enter)
	if enter == nil then
		enter = false
	end

	-- create a buffer
	local buf = vim.api.nvim_create_buf(false, true) -- no file, scratch buffer

	-- create the floatin window
	local win = vim.api.nvim_open_win(buf, enter or false, config)

	return { buf = buf, win = win }
end

M.setup = function()
	-- ...
end

---@class present.Slides
---@field slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: The title of the slide
---@field body string[]: The body of slide

-- Takes some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
	local slides = { slides = {} }
	local current_slide = {
		title = "",
		body = {},
	}

	local separator = "^#"

	for _, line in ipairs(lines) do
		-- print(line, "find:", line:find(separator), "|")
		if line:find(separator) then
			if #current_slide.title > 0 then
				table.insert(slides.slides, current_slide)
			end
			current_slide = {
				title = line,
				body = {},
			}
		else
			table.insert(current_slide.body, line)
		end
		table.insert(current_slide, line)
	end
	table.insert(slides.slides, current_slide)
	return slides
end

local create_window_configuration = function()
	local width = vim.o.columns
	local height = vim.o.lines

	local header_height = 1 + 2 -- 1 + border
	local footer_height = 1 -- 1, no border
	local body_height = height - header_height - footer_height - 2 -- for our own border

	return {
		background = {
			relative = "editor",
			width = width,
			height = height,
			style = "minimal",
			col = 0,
			row = 0,
			zindex = 1,
		},
		header = {
			relative = "editor",
			width = width,
			height = 1,
			style = "minimal",
			-- border = { " ", " ", " ", " ", " ", " ", " ", " " },
			border = "rounded",
			col = 0,
			row = 0,
			zindex = 2,
		},
		body = {
			relative = "editor",
			width = width - 8,
			height = body_height,
			style = "minimal",
			-- border = { " ", " ", " ", " ", " ", " ", " ", " " },
			border = "solid",
			col = 8,
			row = 5,
		},
		footer = {
			relative = "editor",
			width = width,
			height = 1,
			style = "minimal",
			-- border = { " ", " ", " ", " ", " ", " ", " ", " " }, -- TODO: add border on top of footer
			col = 0,
			row = height - 1,
			zindex = 2,
		},
	}
end

-- a global state object
local state = {
	parsed = {},
	current_slide = 1,
	floats = {},
}

local foreach_float = function(cb)
	for name, float in pairs(state.floats) do
		cb(name, float)
	end
end

local present_keymap = function(mode, key, callback)
	vim.keymap.set(mode, key, callback, {
		buffer = state.floats.body.buf,
	})
end

M.start_presentation = function(opts)
	opts = opts or {}
	opts.bufnr = opts.bufnr or 0

	local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
	state.parsed = parse_slides(lines)
	state.current_slide = 1

	-- func for creating all the windows
	local windows = create_window_configuration()
	state.floats.background = create_floating_window(windows.background)
	state.floats.header = create_floating_window(windows.header)
	state.floats.body = create_floating_window(windows.body, true) -- need to make sure body goes last
	state.floats.footer = create_floating_window(windows.footer)

	foreach_float(function(_, float)
		vim.bo[float.buf].filetype = "markdown"
	end)

	local set_slide_content = function(idx)
		local width = vim.o.columns
		local slide = state.parsed.slides[idx]

		local padding = string.rep(" ", (width - #slide.title) / 2)
		local title = padding .. slide.title
		vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { title })
		vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
		vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { "footer" })
	end

	present_keymap("n", "n", function()
		state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
		set_slide_content(state.current_slide)
	end)
	present_keymap("n", "p", function()
		state.current_slide = math.max(state.current_slide - 1, 1)
		set_slide_content(state.current_slide)
	end)
	present_keymap("n", "q", function()
		vim.api.nvim_win_close(state.floats.body.win, true)
	end)

	local restore = { cmdheight = { original = vim.o.cmdheight, custom = 0 } }
	-- sets the cmdheight needed for presentation
	for option, config in pairs(restore) do
		vim.opt[option] = config.custom
	end

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = state.floats.body.buf,
		callback = function()
			-- sets the cmdheight to its original value
			for option, config in pairs(restore) do
				vim.opt[option] = config.original
			end

			-- automatically close all the buffers in the window
			foreach_float(function(_, float)
				pcall(vim.api.nvim_win_close, float.win, true)
			end)
		end,
	})

	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("present-resized", {}),
		callback = function()
			if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
				return
			end

			-- automatically updated all the windows in global state object
			local updated = create_window_configuration()
			foreach_float(function(name, _)
				vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
			end)

			-- re-calculate current slide contents
			set_slide_content(state.current_slide)
		end,
	})

	-- vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[1])
	set_slide_content(state.current_slide)
end

M.start_presentation({ bufnr = 14 }) -- :echo nvim_get_current_buf
-- vim.print(parse_slides({
-- 	"plugin name: present.nvim",
-- 	"# here is H1",
-- 	"body of H1",
-- 	"## here is the H2",
-- 	"body of H2",
-- }))
--
return M
