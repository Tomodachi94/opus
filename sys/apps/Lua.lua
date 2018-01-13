local injector = _G.requireInjector or load(_G.http.get('https://raw.githubusercontent.com/kepler155c/opus/master/sys/apis/injector.lua').readAll())()
injector()

local Event      = require('event')
local History    = require('history')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors
local multishell = _ENV.multishell
local os         = _G.os
local textutils  = _G.textutils

local sandboxEnv = setmetatable(Util.shallowCopy(_ENV), { __index = _G })
sandboxEnv.exit = function() Event.exitPullEvents() end
sandboxEnv._echo = function( ... ) return { ... } end
injector(sandboxEnv)

if multishell and multishell.setTitle then
  multishell.setTitle(multishell.getCurrent(), 'Lua')
end
UI:configure('Lua', ...)

local command = ''
local history = History.load('usr/.lua_history', 25)
local extChars = Util.getVersion() > 1.76

local page = UI.Page {
  menuBar = UI.MenuBar {
    buttons = {
      { text = 'Local',  event = 'local'  },
      { text = 'Global', event = 'global' },
      { text = 'Device', event = 'device', name = 'Device' },
    },
  },
  prompt = UI.TextEntry {
    y = 2,
    shadowText = 'enter command',
    limit = 256,
    accelerators = {
      enter               = 'command_enter',
      up                  = 'history_back',
      down                = 'history_forward',
      mouse_rightclick    = 'clear_prompt',
      [ 'control-space' ] = 'autocomplete',
    },
  },
  indicator = UI.Text {
    backgroundColor = colors.black,
    y = 2, x = -1, width = 1,
  },
  grid = UI.ScrollingGrid {
    y = 3,
    columns = {
      { heading = 'Key',   key = 'name'  },
      { heading = 'Value', key = 'value' },
    },
    sortColumn = 'name',
    autospace = true,
  },
  notification = UI.Notification(),
}

function page.indicator:showResult(s)
  local values = {
    [ true  ] = { c = colors.green, i = (extChars and '\003') or '+' },
    [ false ] = { c = colors.red,   i = 'x' }
  }

  self.textColor = values[s].c
  self.value = values[s].i
  self:draw()
end

function page:setPrompt(value, focus)
  self.prompt:setValue(value)
  self.prompt.scroll = 0
  self.prompt:setPosition(#value)
  self.prompt:updateScroll()

  if value:sub(-1) == ')' then
    self.prompt:setPosition(#value - 1)
  end

  self.prompt:draw()
  if focus then
    page:setFocus(self.prompt)
  end
end

function page:enable()
  self:setFocus(self.prompt)
  UI.Page.enable(self)
end

local function autocomplete(env, oLine, x)
  local sLine = oLine:sub(1, x)
  local nStartPos = sLine:find("[a-zA-Z0-9_%.]+$")
  if nStartPos then
    sLine = sLine:sub(nStartPos)
  end

  if #sLine > 0 then
    local results = textutils.complete(sLine, env)

    if #results == 1 then
      return Util.insertString(oLine, results[1], x + 1)

    elseif #results > 1 then
      local prefix = results[1]
      for n = 1, #results do
        local result = results[n]
        while #prefix > 0 do
          if result:find(prefix, 1, true) == 1 then
            break
          end
          prefix = prefix:sub(1, #prefix - 1)
        end
      end
      if #prefix > 0 then
        return Util.insertString(oLine, prefix, x + 1)
      end
    end
  end
  return oLine
end

function page:eventHandler(event)
  if event.type == 'global' then
    self:setPrompt('', true)
    self:executeStatement('_G')
    command = nil

  elseif event.type == 'local' then
    self:setPrompt('', true)
    self:executeStatement('_ENV')
    command = nil

  elseif event.type == 'autocomplete' then
    local sz = #self.prompt.value
    local pos = self.prompt.pos
    self:setPrompt(autocomplete(sandboxEnv, self.prompt.value, self.prompt.pos))
    self.prompt:setPosition(pos + #self.prompt.value - sz)
    self.prompt:updateCursor()

  elseif event.type == 'device' then
    self:setPrompt('device', true)
    self:executeStatement('device')

  elseif event.type == 'history_back' then
    local value = history:back()
    if value then
      self:setPrompt(value)
    end

  elseif event.type == 'history_forward' then
    self:setPrompt(history:forward() or '')

  elseif event.type == 'clear_prompt' then
    self:setPrompt('')
    history:reset()

  elseif event.type == 'command_enter' then
    local s = tostring(self.prompt.value)

    if #s > 0 then
      history:add(s)
      history:back()
      self:executeStatement(s)
    else
      local t = { }
      for k = #history.entries, 1, -1 do
        table.insert(t, {
          name = #t + 1,
          value = history.entries[k],
          isHistory = true,
          pos = k,
        })
      end
      history:reset()
      command = nil
      self.grid:setValues(t)
      self.grid:setIndex(1)
      self.grid:adjustWidth()
      self:draw()
    end
    return true

  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

function page:setResult(result)
  local t = { }

  local function safeValue(v)
    if type(v) == 'string' or type(v) == 'number' then
      return v
    end
    return tostring(v)
  end

  if type(result) == 'table' then
    for k,v in pairs(result) do
      local entry = {
        name = safeValue(k),
        rawName = k,
        value = safeValue(v),
        rawValue = v,
      }
      if type(v) == 'table' then
        if Util.size(v) == 0 then
          entry.value = 'table: (empty)'
        else
          entry.value = tostring(v)
        end
      end
      table.insert(t, entry)
    end
  else
    table.insert(t, {
      name = type(result),
      value = tostring(result),
      rawValue = result,
    })
  end
  self.grid:setValues(t)
  self.grid:setIndex(1)
  self.grid:adjustWidth()
  self:draw()
end

function page.grid:eventHandler(event)
  local entry = self:getSelected()

  local function commandAppend()
    if entry.isHistory then
      --history.setPosition(entry.pos)
      return entry.value
    end
    if type(entry.rawValue) == 'function' then
      if command then
         return command .. '.' .. entry.name .. '()'
      end
      return entry.name .. '()'
    end
    if command then
      if type(entry.rawName) == 'number' then
        return command .. '[' .. entry.name .. ']'
      end
      if entry.name:match("%W") or
         entry.name:sub(1, 1):match("%d") then
        return command .. "['" .. tostring(entry.name) .. "']"
      end
      return command .. '.' .. entry.name
    end
    return entry.name
  end

  if event.type == 'grid_focus_row' then
    if self.focused then
      page:setPrompt(commandAppend())
    end
  elseif event.type == 'grid_select' then
    page:setPrompt(commandAppend(), true)
    page:executeStatement(commandAppend())

  elseif event.type == 'copy' then
    if entry then
      os.queueEvent('clipboard_copy', entry.rawValue)
    end
  else
    return UI.ScrollingGrid.eventHandler(self, event)
  end
  return true
end

function page:rawExecute(s)
  local fn, m

  fn = load('return (' ..s.. ')', 'lua', nil, sandboxEnv)

  if fn then
    fn = load('return {' ..s.. '}', 'lua', nil, sandboxEnv)
  end

  if fn then
    fn, m = pcall(fn)
    if #m == 1 then
      m = m[1]
    end
    return fn, m
  end

  fn, m = load(s, 'lua', nil, sandboxEnv)
  if fn then
    fn, m = pcall(fn)
  end

  return fn, m
end

function page:executeStatement(statement)
  command = statement

  local s, m = self:rawExecute(command)

  if s and m then
    self:setResult(m)
  else
    self.grid:setValues({ })
    self.grid:draw()
    if m then
      self.notification:error(m, 5)
    end
  end
  self.indicator:showResult(not not s)
end

local args = { ... }
if args[1] then
  command = 'args[1]'
  sandboxEnv.args = args
  page:setResult(args[1])
end

UI:setPage(page)
Event.pullEvents()
UI.term:reset()
