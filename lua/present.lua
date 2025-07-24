local M = {}

local function create_floating_window(config)
	-- create a buffer
	local buf = vim.api.nvim_create_buf(false, true) -- no file, scratch buffer

	-- create the floatin window
	local win = vim.api.nvim_open_win(buf, true, config)

	return { buf = buf, win = win }
end

M.setup = function()
	-- ...
end

---@class present.Slides
---@field slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: The title of the slide
---@field body string: The body of slide

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

M.start_presentation = function(opts)
	opts = opts or {}
	opts.bufnr = opts.bufnr or 0

	local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
	local parsed = parse_slides(lines)

	---@type vim.api.keyset.win_config[]
	local width = vim.o.columns
	local height = vim.o.lines
	local windows = {
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
			height = height - 5, -- make it to 1
			style = "minimal",
			-- border = { " ", " ", " ", " ", " ", " ", " ", " " },
			border = "solid",
			col = 8,
			row = 5,
		},
	}
	local background_float = create_floating_window(windows.background)
	local header_float = create_floating_window(windows.header)
	local body_float = create_floating_window(windows.body)

	vim.bo[header_float.buf].filetype = "markdown"
	vim.bo[body_float.buf].filetype = "markdown"

	local set_slide_content = function(idx)
		local slide = parsed.slides[idx]

		local padding = string.rep(" ", (width - #slide.title) / 2)
		local title = padding .. slide.title
		vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { title })
		vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
	end

	local current_slide = 1
	vim.keymap.set("n", "n", function()
		current_slide = math.min(current_slide + 1, #parsed.slides)
		-- vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide].body)
		set_slide_content(current_slide)
	end, { buffer = body_float.buf })
	vim.keymap.set("n", "p", function()
		current_slide = math.max(current_slide - 1, 1)
		-- vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide].body)
		set_slide_content(current_slide)
	end, { buffer = body_float.buf })
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(body_float.win, true)
	end, { buffer = body_float.buf })

	local restore = { cmdheight = { original = vim.o.cmdheight, custom = 0 } }
	-- sets the cmdheight needed for presentation
	for option, config in pairs(restore) do
		vim.opt[option] = config.custom
	end

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = body_float.buf,
		callback = function()
			-- sets the cmdheight to its original value
			for option, config in pairs(restore) do
				vim.opt[option] = config.original
			end

			pcall(vim.api.nvim_win_close, background_float.win, true)
			pcall(vim.api.nvim_win_close, header_float.win, true)
		end,
	})

	-- vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[1])
	set_slide_content(current_slide)
end

M.start_presentation({ bufnr = 25 }) -- :echo nvim_get_current_buf
-- vim.print(parse_slides({
-- 	"plugin name: present.nvim",
-- 	"# here is H1",
-- 	"body of H1",
-- 	"## here is the H2",
-- 	"body of H2",
-- }))
--
return M
