-- Exports every game script from Studio into the repo's src/ folder (GitHub is the backup; Studio is the source
-- of truth). Start tools/export/receive.ps1 first, turn on HttpService (Game Settings > Security, or
-- HttpService.HttpEnabled = true in the command bar), run this in the command bar, then turn HttpService off again.
-- Paths mirror the Explorer: src/ServerScriptService/..., src/ReplicatedStorage/..., src/StarterPlayer/...
-- Script = .server.luau, LocalScript = .client.luau, ModuleScript = .luau (a script with script children is
-- written as a folder with init.*.luau). Returns the list of written paths.
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")

local URL = "http://localhost:34998/"
local ROOTS = { "ServerScriptService", "ReplicatedStorage", "StarterPlayer", "StarterGui", "StarterPack", "ServerStorage", "ReplicatedFirst" }
local SUFFIX = { Script = ".server.luau", LocalScript = ".client.luau", ModuleScript = ".luau" }

local written = {}

local function hasScriptChildren(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then return true end
	end
	return false
end

local function send(path, source)
	HttpService:PostAsync(URL, source, Enum.HttpContentType.TextPlain, false, { ["X-Path"] = path })
	table.insert(written, path)
end

local function walk(inst, dir)
	for _, child in ipairs(inst:GetChildren()) do
		local suffix = SUFFIX[child.ClassName]
		if suffix then
			local ok, source = pcall(function() return ScriptEditorService:GetEditorSource(child) end)
			if not ok then source = (child :: any).Source end
			if hasScriptChildren(child) then
				send(dir .. child.Name .. "/init" .. suffix, source)
				walk(child, dir .. child.Name .. "/")
			else
				send(dir .. child.Name .. suffix, source)
			end
		elseif hasScriptChildren(child) then
			walk(child, dir .. child.Name .. "/")
		end
	end
end

for _, name in ipairs(ROOTS) do
	walk(game:GetService(name), name .. "/")
end
return table.concat(written, "\n")
