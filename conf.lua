local identity = "TradeMap"

love.filesystem.setIdentity(identity, true)
love.setDeprecationOutput(true)

local args = require("util.args")

local console = args["console"]

if console and love._os == "Windows" then
  love._openConsole()
end

if not jit then
  print("No JIT support", "LuaJit is required to run this project. This system doesn't support it.")
  args["quit"] = true
  return
else
  jit.on()
end

local ffi = require("ffi")
if not ffi then
  print("Unsupported version", "Could not load LuaJit's FFI. Required to run this project. Tell a developer as this should be packaged with the project.")
  args["quit"] = true
  return
end

local settings = require("util.settings")

love.conf = function(t)
  t.console = console
  t.version = "12.0"
  t.identity = identity
  t.appendidentity = true
  t.accelerometerjoystick = false
  
  t.gammacorrect      = true
  t.highdpi           = true

  t.window.title        = "Trade Map"
  t.window.width        = settings.client.windowSize.width
  t.window.height       = settings.client.windowSize.height
  t.window.fullscreen   = settings.client.windowFullscreen
  t.window.resizable    = true
  t.window.minwidth     = settings._default.client.windowSize.width
  t.window.minheight    = settings._default.client.windowSize.height
  t.window.displayindex = 1
  --t.window.depth        = 24
  t.window.mssa         = 4

  t.modules.audio    = true
  t.modules.data     = true
  t.modules.event    = true
  t.modules.font     = true
  t.modules.graphics = true
  t.modules.image    = true
  t.modules.keyboard = true
  t.modules.math     = true
  t.modules.mouse    = true
  t.modules.sound    = true
  t.modules.system   = true
  t.modules.timer    = true
  t.modules.window   = true
  
  t.modules.joystick = false
  t.modules.thread   = false
  t.modules.touch    = false
  t.modules.video    = false
  t.modules.physics  = false
end