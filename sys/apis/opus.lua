local Opus = { }

local function runDir(directory, desc, open)
  if not fs.exists(directory) then
    return true
  end

  local success = true
  local files = fs.list(directory)
  table.sort(files)

  for _,file in ipairs(files) do
    os.sleep(0)
    local result, err = open(directory .. '/' .. file)
    if result then
      if term.isColor() then
        term.setTextColor(colors.green)
      end
      term.write('[PASS] ')
      term.setTextColor(colors.white)
      term.write(fs.combine(directory, file))
    else
      if term.isColor() then
        term.setTextColor(colors.red)
      end
      term.write('[FAIL] ')
      term.setTextColor(colors.white)
      term.write(fs.combine(directory, file))
      if err then
        printError(err)
      end
      success = false
    end
    print()
  end

  return success
end

function Opus.loadExtensions()
  --return runDir('sys/extensions', '[ ext ] ', shell.run)
  return true
end

function Opus.loadServices()
  return runDir('sys/services', '[ svc ] ', shell.openHiddenTab)
end

function Opus.autorun()
  local s = runDir('sys/autorun', '[ aut ] ', shell.run)
  return runDir('usr/autorun', '[ aut ] ', shell.run) and s
end

return Opus
