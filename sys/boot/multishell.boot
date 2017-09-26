-- Loads the Opus environment regardless if the file system is local or not

local w, h = term.getSize()
local str = 'Opus OS'
term.setTextColor(colors.white)
term.setBackgroundColor(colors.cyan)
term.setCursorPos((w - #str) / 2, h / 2)
term.clear()
term.write(str)
term.setCursorPos(1, h / 2 + 2)

local GIT_REPO = 'kepler155c/opus/develop'
local BASE     = 'https://raw.githubusercontent.com/' .. GIT_REPO

local function makeEnv()
  local env = setmetatable({
    LUA_PATH = '/sys/apis:/usr/apis'
  }, { __index = _G })
  for k,v in pairs(getfenv(1)) do
    env[k] = v 
  end
  return env
end

-- os.run doesn't provide return values :(
local function run(file, ...)
  local s, m = loadfile(file, makeEnv())
  if s then
    local args = { ... }
    s, m = pcall(function()
      return s(table.unpack(args))
    end)
  end

  if not s then
    printError('Error loading ' .. file)
    error(m)
  end
  return m
end

local function runUrl(file, ...)
  local url = BASE .. '/' .. file

  local h = http.get(url)
  if h then
    local fn, m = load(h.readAll(), url, nil, makeEnv())
    h.close()
    if fn then
      return fn(...)
    end
  end
  error('Failed to download ' .. url)
end

shell.setPath('usr/apps:sys/apps:' .. shell.path())

if fs.exists('sys/apis/injector.lua') then
  _G.requireInjector = run('sys/apis/injector.lua')
else
  -- not local, run the file system directly from git
  _G.requireInjector = runUrl('/sys/apis/injector.lua')
  runUrl('/sys/extensions/vfs.lua')

  -- install file system
  fs.mount('', 'gitfs', GIT_REPO)
end

-- user environment
if not fs.exists('usr/apps') then
  fs.makeDir('usr/apps')
end
if not fs.exists('usr/autorun') then
  fs.makeDir('usr/autorun')
end
if not fs.exists('usr/etc/fstab') then
  local file = io.open('usr/etc/fstab', "w")
  file:write('usr gitfs kepler155c/opus-apps/master')
  file:close()
end

-- extensions
local dir = 'sys/extensions'
for _,file in ipairs(fs.list(dir)) do
  run('sys/apps/shell', fs.combine(dir, file))
end

-- install user file systems
fs.loadTab('usr/etc/fstab')

local args = { ... }
if args[1] then
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
end
args[1] = args[1] or 'sys/apps/multishell'
run('sys/apps/shell', table.unpack(args))

fs.restore()
