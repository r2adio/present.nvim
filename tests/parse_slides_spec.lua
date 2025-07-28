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
					{ title = '# first slide', body = { "body of first slide" } },
				},
			},
			parse({
				"# first slide",
				"body of first slide",
			})
		)
	end)
end)
