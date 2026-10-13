-- Pushes scripts from the repo's src/ into Studio (the reverse of Export.luau), for build sessions where src/ is edited
-- first. Serve src/ read-only on localhost first:  python -m http.server 34999 --bind 127.0.0.1 --directory src
-- Then, in the command bar (or via MCP, Edit mode), set PATHS to the files (relative to src/) and run this. HttpService is
-- turned on for the run and back off afterwards. A missing script (and its folders) is created: .server.luau = Script,
-- .client.luau = LocalScript, .luau = ModuleScript; init.*.luau = the folder's own script. Returns what it did.
-- (Builders: serve tools/builders the same way on another port and require them from ServerStorage._Builders, tools/bake.md.)
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local URL = "http://127.0.0.1:34999/"
local PATHS = {} -- e.g. { "ServerScriptService/Server/PosingCompService.luau" }

local function classOf(file)
	if file:sub(-12) == ".server.luau" then return "Script", file:sub(1, -13) end
	if file:sub(-12) == ".client.luau" then return "LocalScript", file:sub(1, -13) end
	return "ModuleScript", file:sub(1, -6)
end

local function push(path)
	local parts = string.split(path, "/")
	local parent: Instance = game:GetService(parts[1])
	for i = 2, #parts - 1 do
		local child = parent:FindFirstChild(parts[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = parts[i]
			child.Parent = parent
		end
		parent = child
	end
	local class, name = classOf(parts[#parts])
	local target
	if name == "init" then
		target = parent -- a script with script children: the folder IS the script
	else
		target = parent:FindFirstChild(name)
		if not target then
			target = Instance.new(class)
			target.Name = name
			target.Parent = parent
		end
	end
	assert(target.ClassName == class, path .. ": is a " .. target.ClassName .. ", expected " .. class)
	local source = HttpService:GetAsync(URL .. path, true):gsub("\r\n", "\n")
	ScriptEditorService:UpdateSourceAsync(target, function() return source end)
	return path .. " (" .. #source .. " chars)"
end

local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local done = {}
local ok, err = pcall(function()
	for _, path in ipairs(PATHS) do table.insert(done, push(path)) end
end)
HttpService.HttpEnabled = was
return (ok and "ok\n" or ("FAILED: " .. tostring(err) .. "\n")) .. table.concat(done, "\n")
