-- Runs every test file: `lune run tests/run_all` from the repo root.
local process = require("@lune/process")
local fs = require("@lune/fs")
local failed = {}
for _, file in fs.readDir("tests") do
	if file:sub(-5) == ".luau" and file ~= "harness.luau" and file ~= "run_all.luau" then
		local result = process.exec("lune", { "run", "tests/" .. file:sub(1, -6) })
		local last = result.stdout:match("([^\n]*)\n?$") or ""
		print(string.format("%-10s %s", file:sub(1, -6), result.ok and last or "FAILED"))
		if not result.ok then
			table.insert(failed, file)
			print(result.stdout, result.stderr)
		end
	end
end
if #failed > 0 then process.exit(1) end
