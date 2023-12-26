local lg, lm = love.graphics, love.mouse

local isCursorSupported = lm.isCursorSupported()
local cursor_sizewe, cursor_sizeall, cursor_ibeam, cursor_hand
if isCursorSupported then
  cursor_sizewe = lm.getSystemCursor("sizewe")
  cursor_sizeall = lm.getSystemCursor("sizeall")
  cursor_ibeam = lm.getSystemCursor("ibeam")
  cursor_hand = lm.getSystemCursor("hand")
end

local suit = require("libs.suit").new()
suit.theme = require("ui.theme_Editor")

local flux = require("libs.flux")

local settings = require("util.settings")
local assets = require("util.assets")

local undo = require("src.undo")

local scene = {
  editor = require("scene.editor.editor"),
  companies = require("scene.editor.companies"),
  drop = "not dropping",
}

local loadImageAssets = function(assetID)
  assets[assetID] = assets[assetID] or lg.newImage(assets._path[assetID])
end

scene.load = function(project, start)
  scene.active = scene.editor
  scene.project = project

  assets["audio.ui.button"] = assets["audio.ui.button"] or love.audio.newSource(assets._path["audio.ui.button"], "static")
  assets["audio.ui.button"]:setVolume(0.4)

  loadImageAssets("icon.barsHorizontal")
  loadImageAssets("icon.barsHorizontal.inactive")
  loadImageAssets("icon.save")
  loadImageAssets("icon.undo")
  loadImageAssets("icon.redo")
  loadImageAssets("icon.trashcan")
  loadImageAssets("icon.trashcan.open")
  loadImageAssets("icon.up")
  loadImageAssets("icon.down")
  loadImageAssets("icon.left")
  loadImageAssets("icon.right")
  loadImageAssets("icon.updown")
  loadImageAssets("icon.updown.up")
  loadImageAssets("icon.updown.down")
  
  scene.editor.load(project, suit)
  scene.companies.load(project, suit)
  scene.resize(lg.getDimensions())
  local stop = love.timer.getTime()
  
  print(("Took %.4f ms to load project"):format((stop-start)*1000))

  undo.clear()
end

scene.unload = function()
  local success, errorMessage = scene.project:close()
  if not success then error(errorMessage) end -- todo: replace with better error
  scene.editor.unload()
  undo.clear()
end

local buttonlist = {
  "Save & Close", "Don't Save", "Cancel", escapebutton = 3, enterbutton = 1,
}

scene.quit = function()
  if scene.project.dirty then
    local pressedbutton = love.window.showMessageBox("Unsaved work, are you sure you want to quit?", "Are you aure you want to quit without saving?", buttonlist)
    if pressedbutton == 1 then
      scene.project:saveProject()
    elseif pressedbutton == 3 then
      return true
    end
  end
end

scene.resize = function(w, h)
  local wsize = settings._default.client.windowSize
  local tw, th = wsize.width, wsize.height
  local sw, sh = w / tw, h / th
  scene.scale = sw < sh and sw or sh

  suit.scale = scene.scale
  suit.theme.scale = scene.scale

  local fontSize = math.floor(18 * scene.scale)
  local fontName = "font.regular."..fontSize
  if not assets[fontName] then
    assets[fontName] = lg.newFont(assets._path["font.regular"], fontSize)
    assets[fontName]:setFilter("nearest", "nearest")
  end
  lg.setFont(assets[fontName])
  print("Set font size to", fontSize)

  local fontSize = math.floor(12 * scene.scale)
  local fontName = "font.regular."..fontSize
  if not assets[fontName] then
    assets[fontName] = lg.newFont(assets._path["font.regular"], fontSize)
    assets[fontName]:setFilter("nearest", "nearest")
  end
  suit.subtitleFont = assets[fontName]

  scene.editor.resize(w, h)
  scene.companies.resize(w, h)
end

scene.topLeftIcon = "icon.barsHorizontal"
local timerIcon, timerTime, iconY = 0, 1, {0}

scene.update = function(dt)
  scene.active.update(dt)
  if scene.topLeftIcon ~= "icon.barsHorizontal" then
    timerIcon = timerIcon + dt
    if timerIcon > timerTime then
      scene.topLeftIcon = "icon.barsHorizontal"
      timerIcon, timerTime = 0, 1
      iconY[1] = 0
    end
  else
    iconY[1] = 0
  end
end

local bgline = {.5,.5,.5}
local b1txt = "Trades"
local b2txt = "Companies"

scene.updateui = function()
  suit:enterFrame(1)

  local height = 40
  local imgScale = .4

  local b = suit:ImageButton(assets[scene.topLeftIcon], { hovered = assets["icon.barsHorizontal.inactive"], scale = imgScale }, 0,iconY[1])
  
  if b.hit then
    if not scene.quit() then -- lazy hack, should change
      require("util.sceneManager").changeScene("scene.menu", true)
    end
  end
  if b.left then
    lm.setCursor(nil)
  end
  if b.entered and cursor_hand then
    lm.setCursor(cursor_hand)
  end

  suit:Shape("NavbarBgLine", bgline, 0, height-3, lg.getWidth(), 3)
  suit.layout:reset(100*imgScale*scene.scale+10, 5, 10)
  local b1 = suit:Button(b1txt, { noScaleX = true, r=3, active = scene.active == scene.editor }, suit.layout:right(lg.getFont():getWidth(b1txt) + 10, 35))
  if b1.hit then scene.active = scene.editor end
  local b2 = suit:Button(b2txt, { noScaleX = true, r=3, active = scene.active == scene.companies }, suit.layout:right(lg.getFont():getWidth(b2txt) + 10, 35))
  if b2.hit then scene.active = scene.companies end
  if b1.hovered or b2.hovered then
    bgline[1],bgline[2],bgline[3] = .6,.6,.6
  else
    bgline[1],bgline[2],bgline[3] = .6,.6,.6
  end
  if b1.left or b2.left then
    lm.setCursor(nil)
  end
  if b1.entered or b2.entered then
    if cursor_hand then lm.setCursor(cursor_hand) end
  end
  suit:Shape("NavbarBg", {.3,.3,.3}, 0,0, lg.getWidth(), height)

  scene.active.updateui(0, height)
end

scene.draw = function()
  lg.origin()
  lg.clear(0,0,0,1)
  scene.active.draw()
  suit:draw()
  if scene.active.drawAboveUI then
    scene.active.drawAboveUI()
  end
  lg.setColor(1,1,1,1)
end

scene.filedropped = function(file)
  scene.drop = "dropped"
end

scene.directorydropped = function(directory)
  scene.drop = "dropped"
end

scene.isdropping = function(x, y)
  scene.drop = "dropping"
end

scene.stoppeddropping = function()
  scene.drop = "not dropping"
end

scene.wheelmoved = function(...)
  suit:updateWheel(...)
  scene.active.wheelmoved(...)
end

scene.textedited = function(...)
  suit:textedited(...)
end

scene.textinput = function(...)
  suit:textinput(...)
end

scene.keypressed = function(key, scancode, isrepeat)
  suit:keypressed(key, scancode, isrepeat)
  if love.keyboard.isScancodeDown("rctrl", "lctrl") then
    if scancode == "s" then
      if scene.project:saveProject() then
        scene.topLeftIcon = "icon.save"
        flux.to(iconY, .3, {-4}):ease("backout"):after(iconY, .3, {-1}):ease("backout")
        timerTime = 1
      end
      return
    elseif scancode == "z" then
      if undo.pop() then
        timerTime = .3
        scene.topLeftIcon = "icon.undo"
        scene.project.dirty = true
      end
      return
    elseif scancode == "y" then
      if undo.redoPop() then
        timerTime = .3
        scene.topLeftIcon = "icon.redo"
        scene.project.dirty = true
      end
    end
  end
  scene.active.keypressed(key, scancode, isrepeat)
end

scene.mousepressed = function(...)
  scene.active.mousepressed(...)
end

scene.mousemoved = function(...)
  scene.active.mousemoved(...)
end

scene.mousereleased = function(...)
  scene.active.mousereleased(...)
end

return scene