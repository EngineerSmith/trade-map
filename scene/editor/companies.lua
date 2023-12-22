local lg, lm = love.graphics, love.mouse

local isCursorSupported = lm.isCursorSupported()
local cursor_sizewe, cursor_sizeall, cursor_ibeam, cursor_hand
if isCursorSupported then
  cursor_sizewe = lm.getSystemCursor("sizewe")
  cursor_sizeall = lm.getSystemCursor("sizeall")
  cursor_ibeam = lm.getSystemCursor("ibeam")
  cursor_hand = lm.getSystemCursor("hand")
end

local sysl = require("libs.SYSL-Text")
local nfs = require("libs.nativefs")
local flux = require("libs.flux")

local settings = require("util.settings")
local fileUtil = require("util.file")
local assets = require("util.assets")

local undo = require("src.undo")

local movingGrid = false

local scene = { 
  gridX = 0, gridY = 0,
  gridScale = 0,
  activeCompany = nil,
}

scene.load = function(project, suit)
  scene.project = project
  scene.suit = suit
end

scene.unload = function()
  scene.project = nil
  if isCursorSupported then
    lm.setCursor(nil)
  end
end

scene.update = function(dt)
  local suit = scene.suit
  if scene.scrollHitbox then
    local limit = (scene.scrollHitbox[4] - scene.scrollHitbox[2]) - scene.scrollHeightLimit
    if limit > 0 then 
      scene.scrollHeight = 0
      goto continue
    end
    if scene.scrollHeight > 0 then scene.scrollHeight = scene.scrollHeight - dt*8*scene.scrollHeight end
    if scene.scrollHeight < limit then scene.scrollHeight = scene.scrollHeight + dt*8*(limit-scene.scrollHeight) end
    -- if it goes too far, we don't want to lose the scroll area
    if scene.scrollHeight > 300*suit.scale then scene.scrollHeight = 0 end
    if scene.scrollHeight < limit-300*suit.scale then scene.scrollHeight = limit end
  end
  ::continue::
end

local validateTabWidth = function(width)
  if width < 180 then width = 180 end
  if width > 350 then width = 350 end
  return width
end

local tabWidth = validateTabWidth(settings.client.companiesTabWidth)
settings.client.companiesTabWidth = tabWidth
local tabWidthChanging = false
local tabNotHeld = false

scene.scrollHeight = 0
scene.scrollHitbox = nil

local drawCompanyUi = function(company, width)
  local suit = scene.suit

  local name = company.name
  local instanceInfo = scene.project.getInstanceInfo()
  if instanceInfo.lang then
    name = instanceInfo.lang["company.ptdye."..company.abbreviation]
    if not name or name == "" then name = company.name end
  end
  local x, y, _w, h = suit.layout:down(width, lg.getFont():getHeight())
  suit:Label(name, {
      noScaleY = true,
      noBox = true,
      align = "left",
      oneLine = true,
    }, x,y,_w,h)
  suit.layout:padding(5, 5)
  suit:Label(company.abbreviation, {
      x = 0.0001, y = 0, w = 0,
      h = 5, r = 5, override = true,
      font = suit.subtitleFont,
      noScaleY = true,
      align = "center",
      oneLine = true,
      color = {bg = company.color, fg={.95,.95,.95}},
    }, suit.layout:down(width-5, suit.subtitleFont:getHeight()))
  suit.layout:padding(0,10)
  suit:Shape(-1, {.5,.5,.5}, {noScaleY = true}, suit.layout:down(width, 1*(suit.scale*1.5)))
  suit.layout:padding(20, 2)
  
  y = y + 3
  local height = h + suit.subtitleFont:getHeight() + 7
  if scene.activeCompany == company then
    suit:Shape(-1, {.3,.3,.3}, {noScaleY=true, cornerRadius=3,override=true,x=0.0001,y=0,w=0,h=0}, x-3,y,width+6,height+2)
  end
  if not tabWidthChanging then
    local mx, my = lm.getPosition()
    if mx > x and mx < x + width*suit.scale and my > y and my < y + height then
      if cursor_hand then lm.setCursor(cursor_hand) end
      if lm.isDown(1) then
        scene.activeCompany = company
      end
      return 1
    end
  end
end

scene.calculateScrollboxHeight = function()
  local suit = scene.suit
  local notExtended = lg.getFont():getHeight() + suit.subtitleFont:getHeight() + 16 + suit.scale*1.5*4
  local height = #scene.project.companies * notExtended
  scene.scrollHeightLimit = height + 2 * suit.scale
end

local drawStencil = function(x,y,w,h)
  lg.setColorMask(false)
  lg.setStencilMode("replace", "always", 1)
  lg.rectangle("fill", x,y,w,h)
  lg.setStencilMode("keep", "greater", 0)
  lg.setColorMask(true)
end

local clearStencil = function()
  lg.setStencilMode()
end

local drawScrollBox = function(x, y, width)
  local suit = scene.suit

  suit.layout:reset(x, y, 10, 10)
  local label = suit:Label("Companies", {noBox = true}, suit.layout:up(width-5, lg.getFont():getHeight()))
  suit:Shape(-1, {.6,.6,.6}, {noScaleY = true}, x,label.y+label.h,width-5,2*suit.scale)

  scene.scrollHitbox = {x, label.y+label.h, (width-5)*suit.scale, lg.getHeight()}
  
  suit:Draw(clearStencil, unpack(scene.scrollHitbox)) -- suit draws backwards, clear stencil first
  suit.layout:reset(x+5, label.y+label.h+10+scene.scrollHeight, 20,3)

  local toggle = 0
  for _, company in ipairs(scene.project.companies) do
    toggle = toggle + (drawCompanyUi(company, width-15) or 0)
  end
  if toggle == 0 and not tabWidthChanging and scene.suit:mouseInRect(unpack(scene.scrollHitbox)) then
    lm.setCursor(nil)
  end

  suit:Draw(drawStencil, {noScaleY=true}, unpack(scene.scrollHitbox))  -- suit draws backwards, set stencil last

  local dragBarColor = {.2,.2,.2}
  if suit:wasHovered("companiesTabBGDragBar") or tabWidthChanging then
    dragBarColor = {.6,.6,.6}
  end
  local dragBar = suit:Shape("companiesTabBGDragBar", dragBarColor, width-5, y, 5,lg.getHeight())
  suit:Shape("companiesTabBG", {.4,.4,.4}, x,y, width-5, lg.getHeight())

  local isPrimaryMousePressed = lm.isDown(1)
  if dragBar.entered and isPrimaryMousePressed and not tabWidthChanging then
    tabNotHeld = true
  end
  if dragBar.hovered then
    if cursor_sizewe then lm.setCursor(cursor_sizewe) end
    if not isPrimaryMousePressed then
      tabNotHeld = false
    elseif not tabNotHeld then
      tabWidthChanging = true
    end
  end
  if tabWidthChanging then
    tabWidth = validateTabWidth(lm.getX() / suit.scale)
  end
  if tabWidthChanging and not isPrimaryMousePressed then
    tabWidthChanging = false
    tabWidth = math.floor(tabWidth)
    settings.client.companiesTabWidth = tabWidth
    if not dragBar.hovered then
      tabNotHeld = false
      if isCursorSupported then lm.setCursor(nil) end
    end
  end
  if dragBar.left and not tabWidthChanging then
    tabNotHeld = false
    if isCursorSupported then lm.setCursor(nil) end
  end
end

scene.updateui = function(x, y)
  drawScrollBox(x, y, tabWidth)
end

scene.draw = function()
  
end

scene.drawAboveUI = function()

end

scene.resize = function(_, _)
  scene.calculateScrollboxHeight()
end

scene.mousepressed = function(x,y, button)
  if button == 3 and scene.scrollHitbox and scene.suit:mouseInRect(unpack(scene.scrollHitbox)) then
    scene.scrollHeight = 0
  end
end

scene.mousemoved = function(_, _, dx, dy)
  if movingGrid then
    scene.gridX = scene.gridX + dx
    scene.gridY = scene.gridY + dy
  end
end

scene.mousereleased = function(_,_, button)
  if movingGrid then
    movingGrid = false
    lm.setCursor(nil)
  end
end

scene.wheelmoved = function( _, y)
  local limit = (scene.scrollHitbox[4] - scene.scrollHitbox[2]) - scene.scrollHeightLimit
  if not (limit > 0) and not movingGrid and scene.scrollHitbox and scene.suit:mouseInRect(unpack(scene.scrollHitbox)) then
    scene.scrollHeight = scene.scrollHeight + y * settings.client.scrollspeed * scene.suit.scale
  end
end

return scene 