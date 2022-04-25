-- mod-version:2 -- lite-xl 2.0
local core = require 'core'
local process = require 'process'
--local lip = require 'plugins.Feathertime.lip'
local Doc = require 'core.doc'
local DocView = require 'core.docview'

--HOME = HOME -- makes lua lsp quiet
--local wakatimeConf = core.try(lip.load, HOME .. '/.wakatime.cfg')
local wakatimeCli = HOME .. '/.wakatime/wakatime-cli-linux-amd64'
local lastHeartbeat = os.time()
local av = nil
local lastFile = nil
local wakatimeIdentity = 'Lite XL/2.1 Feathertime/0.1'

local function enoughTime(t)
	return lastHeartbeat + (0.1 * 60 * 1000) < t
end

local function heartbeat(file, wrote)
	local args = {
		wakatimeCli,
		'--entity', file,
		'--plugin', wakatimeIdentity,
		'--verbose',
		wrote and '--write' or ''
	}
	process.start(args)
	core.log_quiet '[Feathertime] Sent heartbeat!'
end

local function event(file, wrote)
	core.log_quiet('[Feathertime] Got event for ' .. file)
	local time = os.time()
	if wrote or enoughTime(time) or lastFile ~= file then
		heartbeat(file, wrote)
		lastFile = file
		lastHeartbeat = time
	end
end

local docSave = Doc.save
function Doc:save(...)
	event(self.abs_filename, true)
	docSave(self, ...)
end

local setActiveView = core.set_active_view
function core.set_active_view(view)
	if getmetatable(view) == DocView and view ~= av then
		av = view
		event(view.doc.abs_filename, false)
		lastFile = view.doc.abs_filename
	end
	setActiveView(view)
end
