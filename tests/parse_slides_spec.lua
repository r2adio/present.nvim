---@diagnostic disable: undefined-field

local parse = require("present")._parse_slides
local eq = assert.are.same

describe("present.parse_slides", function()
	it("should parse an empty file", function()
		eq({
			slides = {
				{ title = "", body = {} },
			},
		}, parse({}))
	end)

	it("shoud parse a file with one slide", function()
		eq(
			{
				slides = {
					{ title = "# slide 1", body = { "body 1" } },
				},
			},
			parse({
				"# slide 1",
				"body 1",
			})
		)
	end)
end)
