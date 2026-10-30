-- Floating "recent sessions" panel docked to the right of the Claude desktop app.
-- Floats while Claude is in front, drops behind other apps, ctrl+alt+R toggles it.
-- Resizing either window moves the shared edge; the other one fills the rest.
-- Moving Claude's window needs Accessibility permission for Hammerspoon.
local URL = "http://127.0.0.1:7799/"
-- This file is symlinked into ~/.hammerspoon; the server sits one folder up from the real file
local here = hs.fs.pathToAbsolute(debug.getinfo(1, "S").source:sub(2)):match("(.*)/")
local SERVER = here .. "/../recent.py"
local WIDTH_KEY = "claudeRecent.width"
local MIN_WIDTH = 150

local M = {}
local pinnedOff = false -- set by the hotkey, so auto-show doesn't fight you

-- Start the server unless something already answers on the port
local function ensureServer()
  hs.http.asyncGet(URL .. "data", nil, function(status)
    if status ~= 200 then
      M.server = hs.task.new("/usr/bin/env", nil, { "python3", SERVER })
      M.server:start()
    end
  end)
end

local function claudeWin()
  local app = hs.application.get("Claude")
  return app and app:mainWindow()
end

local function frame()
  local s = hs.screen.mainScreen():frame()
  local w = hs.settings.get(WIDTH_KEY) or 280
  return { x = s.x + s.w - w, y = s.y, w = w, h = s.h }
end

-- Claude doesn't report moves its window makes, so poll both frames and let
-- whichever one changed decide where the shared edge goes.
local last = {} -- the frames we last saw or set: panel left edge, Claude right edge

local function same(a, b) return a and b and math.abs(a - b) < 1 end

local function dock()
  local win = claudeWin()
  if not win or win:isFullScreen() or not M.view:isVisible() then return end
  local s = win:screen():frame()
  local c, p = win:frame(), M.view:frame()
  if not same(p.x, last.panel) then
    -- The panel moved: Claude takes everything to its left
    hs.settings.set(WIDTH_KEY, p.w)
    win:setFrame({ x = s.x, y = s.y, w = p.x - s.x, h = s.h }, 0)
  elseif not same(c.x2, last.claude) then
    -- Claude moved: the panel takes everything to its right, unless Claude covers the edge
    local w = s.x + s.w - c.x2
    if w >= MIN_WIDTH then
      hs.settings.set(WIDTH_KEY, w)
      M.view:frame({ x = c.x2, y = s.y, w = w, h = s.h })
    end
  end
  last.panel, last.claude = M.view:frame().x, win:frame().x2
end

local function build()
  M.view = hs.webview.new(frame())
    :url(URL)
    :windowTitle("Recent")
    :windowStyle({ "titled", "utility", "resizable", "closable", "nonactivating" })
    :level(hs.drawing.windowLevels.floating)
    :allowTextEntry(true)
    :deleteOnClose(false)
end

-- Raising and lowering only change the window's layer. show() would make the
-- panel the key window and pull focus away from Claude.
local function raise() if not pinnedOff then M.view:bringToFront(false) end end
local function lower() M.view:sendToBack() end

ensureServer()
build()

M.watcher = hs.application.watcher.new(function(name, event)
  if event ~= hs.application.watcher.activated then return end
  if name == "Claude" then raise()
  elseif name ~= "Hammerspoon" then lower() end
end):start()

M.docker = hs.timer.doEvery(0.25, dock)

hs.hotkey.bind({ "ctrl", "alt" }, "R", function()
  pinnedOff = M.view:isVisible()
  if pinnedOff then M.view:hide() return end
  local front = hs.application.frontmostApplication()
  M.view:show()
  front:activate() -- hand focus straight back
end)

-- Shown once at load, then only raised and lowered
local front = hs.application.frontmostApplication()
M.view:show()
front:activate()
if front:name() == "Claude" then raise() else lower() end

return M
