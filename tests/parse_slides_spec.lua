---@diagnostic disable: undefined-field

local parse = require("present")._parse_slides
local eq = assert.are.same

describe("present.parse_slides", function()
	it("should parse an empty file", function()
		eq({
			slides = {
				{
					title = "",
					body = {},
					blocks = {},
				},
			},
		}, parse({}))
	end)

	it("shoud parse a file with one slide", function()
		eq(
			{
				slides = {
					{
						title = "# slide 1",
						body = { "body 1" },
						blocks = {},
					},
				},
			},
			parse({
				"# slide 1",
				"body 1",
			})
		)
	end)

	it("shoud parse a file with one slide, and a block", function()
		local results = parse({
			"# slide 1",
			"body 1",
			"```lua",
			"print('hi')",
			"```",
		})

		-- should only have 1 slide
		eq(1, #results.slides)

		local slide = results.slides[1]
		eq("# slide 1", slide.title)
		eq({
			"body 1",
			"```lua",
			"print('hi')",
			"```",
		}, slide.body)

		local block = vim.trim([[
```lua
print('hi')
```
		]])
		eq({
			language="lua",
			body="print('hi')",
		}, slide.blocks[1])
	end)
end)
