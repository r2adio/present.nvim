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
---@field blocks present.Block[]: A codeblock inside of a slide

---@class present.Block
---@field language string: Language of the codeblock
---@field body string: The body of the codeblock

-- Takes some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
	local slides = { slides = {} }
	local current_slide = {
		title = "",
		body = {},
		blocks = {},
	}

	local separator = "^# " -- only Heading 1

	for _, line in ipairs(lines) do
		-- print(line, "find:", line:find(separator), "|")
		if line:find(separator) then
			if #current_slide.title > 0 then
				table.insert(slides.slides, current_slide)
			end
			current_slide = {
				title = line,
				body = {},
				blocks = {},
			}
		else
			table.insert(current_slide.body, line)
		end
		-- table.insert(current_slide, line)
	end
	table.insert(slides.slides, current_slide)

	-- iterate over all slides and check for different blocks
	for _, slide in ipairs(slides.slides) do
		local block = { language = nil, body = "" }
		local inside_block = false
		for _, line in ipairs(slide.body) do
			if vim.startswith(line, "```") then
				if not inside_block then
					inside_block = true
					block.language = string.sub(line, 4)
				else
					inside_block = false
					block.body = vim.trim(block.body) -- removing extra white space
					table.insert(slide.blocks, block)
				end
			else
				-- inside of a current markdown block
				-- but it is not one of the guards.
				-- so insert this text
				if inside_block then
					block.body = block.body .. line .. "\n"
				end
			end
		end
	end

	return slides
end

local create_window_configuration = function()
	local width = vim.o.columns
	local height = vim.o.lines

	local header_height = 1 + 2 -- 1 + border
	local footer_height = 1 -- 1, no border
	local body_height = height - header_height - footer_height - 2 - 1 -- for our own border

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
			row = 4,
		},
		footer = {
			relative = "editor",
			width = width,
			height = 1,
			style = "minimal",
			-- border = { " ", " ", " ", " ", " ", " ", " ", " " }, -- TODO: add border on top of footer
			col = 0,
			row = height - 1,
			zindex = 3,
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
	state.title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

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

		local footer = string.format("  %d / %d  |  %s ", state.current_slide, #state.parsed.slides, state.title)
		vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer })
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
	present_keymap("n", "X", function()
		local slide = state.parsed.slides[state.current_slide]
		-- TODO: support for other languages
		local block = slide.blocks[1]
		if not block then
			print("No blocks on this page.")
			return
		end

		-- override the default print function, to capture all the output
		-- store the original print function
		local original_print = print

		-- table to capture print message
		local output = { "", "# Code", "", "```" .. block.language }
		vim.list_extend(output, vim.split(block.body, "\n"))
		table.insert(output, "```")

		-- redefine the print function
		print = function(...)
			local args = { ... }
			local message = table.concat(vim.tbl_map(tostring, args), "\t")
			table.insert(output, message)
		end

		-- call the provided function
		local chunk = loadstring(block.body)
		pcall(function()
			table.insert(output, "")
			table.insert(output, "# Output")
			table.insert(output, "")
			if not chunk then
				table.insert(output, "<<<BROKEN CODE>>>")
			else
				chunk() -- handling nil value
			end
		end)

		-- restore the original print function
		print = original_print

		local buf = vim.api.nvim_create_buf(false, true) -- no file, scratch buffer
		local temp_width = math.floor(vim.o.columns * 0.8)
		local temp_height = math.floor(vim.o.lines * 0.8)
		vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			style = "minimal",
			noautocmd = true,
			width = temp_width,
			height = temp_height,
			row = math.floor((vim.o.lines - temp_height) / 2),
			col = math.floor((vim.o.columns - temp_width) / 2),
			border = "rounded",
		})

		vim.bo[buf].filetype = "markdown"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
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

-- vim.print(parse_slides({
-- 	"plugin name: present.nvim",
-- 	"# here is H1",
-- 	"body of H1",
-- 	"## here is the H2",
-- 	"body of H2",
-- }))
-- M.start_presentation({ bufnr = 145 }) -- :echo nvim_get_current_buf

-- smthing that exists and wanna test, but dont wanna expose; and just for testing purpose => prefix w/ `underscore`
M._parse_slides = parse_slides

return M
