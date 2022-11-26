-- mod-version:3
local core = require 'core'
local config = require 'core.config'
local process = require 'process'
--local lip = require 'plugins.Feathertime.lip'
local Doc = require 'core.doc'
local DocView = require 'core.docview'

HOME = HOME -- makes lua lsp quiet
--local wakatimeConf = core.try(lip.load, HOME .. '/.wakatime.cfg')
local av -- active view
local started -- whether we started/initialized everything yet
local lastFile -- last file path
local lastHeartbeat = os.time() -- last time of heartbeat
local home = os.getenv 'WAKATIME_HOME' or HOME
local ver = '0.1.0'

local wkIdentity = string.format('Lite XL/%s Feathertime/%s', VERSION, ver)
local wkCli

local conf = config.feathertime or {}
wkCli = conf.cliPath

local wkFolder = home .. PATHSEP .. '.wakatime'

local function exists(p)
	local f = io.open(p)
	if not f then return false end
	f:close()
	return true
end

local function split(str, delimiter)
	local res = {}
	local from = 1

	local delimFrom, delimTo = string.find(str, delimiter, from)

	while delimFrom do
		table.insert(res, string.sub(str, from, delimFrom - 1))
		from = delimTo + 1
		delimFrom, delimTo = string.find(str, delimiter, from)
	end

	table.insert(res, string.sub(str, from))

	return res
end

local function which(cmd)
	local pathDirs
	PLATFORM = PLATFORM
	if PLATFORM ~= "Windows" then
		pathDirs = split(os.getenv 'PATH', ':')
	else
		pathDirs = split(os.getenv 'PATH', ';')
	end

	for _, path in pairs(pathDirs) do
		local cmdPath = path:gsub('[/\\]$', '') .. PATHSEP .. cmd
		if exists(cmdPath) then
			return cmdPath
		end
	end
end

local function goos()
	if PLATFORM == 'Windows' then
		return 'windows'
	elseif PLATFORM == 'Mac OS X' then
		return 'darwin'
	elseif PLATFORM == 'Linux' then
		return 'linux'
	else
		-- ... ????
		return 'unknown'
	end
end

local function goarch()
	if PLATFORM == 'Windows' then
		-- apparently windows has an environment variable for arch
		local arch = string.lower(os.getenv 'PROCESSOR_ARCHITECTURE')
		-- it'll be either x86, arm, or something 64 bit (amd, ia, etc)
		if arch == 'x86' then
			return '386'
		elseif arch == 'arm' then
			return 'arm64' -- i guess ??
		else
			return 'amd64'
		end
	else
		-- unix like should have `arch` command
		local proc = process.start {'arch'}
		proc:wait(process.WAIT_INFINITE) -- wait for it to finish
		local arch = proc:read_stdout() or ''
		arch = arch:gsub('\n', '')
		if arch == 'x86_64' then
			return 'amd64'
		elseif arch == 'x86' then
			return '385'
		else
			return 'unknown' -- idk man
		end
	end
end

-- wkCli will be set if it's in the config, from above
if not wkCli then
	if which 'wakatime-cli' then
		wkCli = 'wakatime-cli'
	elseif which 'wakatime' then
		wkCli = 'wakatime'
	else
		local homeCli = wkFolder .. PATHSEP  .. 'wakatime-cli'
		if exists(homeCli) then
			wkCli = homeCli
		else
			homeCli = homeCli .. '-' .. goos() .. '-' .. goarch()
			if exists(homeCli) then wkCli = homeCli end
			core.log(homeCli)
		end
	end
end

if wkCli then
	started = true
	core.log '[Feathertime] Started!'
else
	core.log '[Feathertime] Could not find wakatime-cli, cannot start.'
end

local function enoughTime(t)
	return lastHeartbeat + (0.2 * 60 * 1000) < t
end

local function heartbeat(file, wrote)
	local args = {
		wkCli,
		'--entity', file,
		'--plugin', wkIdentity,
		'--verbose',
		wrote and '--write' or ''
	}
	process.start(args)
	core.log_quiet '[Feathertime] Sent heartbeat!'
end

--- Send an event to Wakatime.
--- @param file string Absolute file path
--- @param wrote boolean Whether the file got written to disk (ie save)
local function event(file, wrote)
	if not started then return end

	local time = os.time()
	if wrote or enoughTime(time) or lastFile ~= file then
		heartbeat(file, wrote)
		lastFile = file
		lastHeartbeat = time
	end
end

local docSave = Doc.save
function Doc:save(...)
	docSave(self, ...)
	event(self.abs_filename, true)
end

local dvTextInput = DocView.on_text_input
function DocView:on_text_input(text)
	dvTextInput(self, text)
	if getmetatable(self) == DocView and not self.doc.new_file then
		event(self.doc.abs_filename, false)
		lastFile = self.doc.abs_filename
	end
end

local setActiveView = core.set_active_view
function core.set_active_view(view)
	if getmetatable(view) == DocView and view ~= av then
		av = view
		if not view.doc.new_file then
			event(view.doc.abs_filename, false)
			lastFile = view.doc.abs_filename
		end
	end
	setActiveView(view)
end
