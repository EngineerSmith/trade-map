local lg, lm, lt = love.graphics, love.mouse, love.timer

local isCursorSupported = lm.isCursorSupported()
local cursor_sizewe, cursor_sizeall, cursor_ibeam, cursor_hand, cursor_sizens, cursor_sizenesw, cursor_sizenwse
if isCursorSupported then
  cursor_sizewe = lm.getSystemCursor("sizewe")
  cursor_sizens = lm.getSystemCursor("sizens")
  cursor_sizenesw = lm.getSystemCursor("sizenesw")
  cursor_sizenwse = lm.getSystemCursor("sizenwse")
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
local movingBox = false
local movingBoxDirection = false
local movingBoxRadius = 5
local movingBoxChanged = false

local editor = { 
  gridX = 0, gridY = 0,
  gridScale = 0,
  keyListen = { },
  tileW = 20, tileH = 20,
  activeBox = nil,
}
require("scene.editor.editor.comment")(editor)

editor.load = function(project, suit)
  editor.project = project
  editor.suit = suit
  editor.resizeGrid(editor.gridScale)
end

editor.unload = function()
  editor.project = nil
  if isCursorSupported then
    lm.setCursor(nil)
  end
end

editor.update = function(dt)

end

editor.updateui = function()

end

local drawGrid = function(x, y, tileW, tileH, viewportW, viewportH, scale)
  lg.setLineWidth(math.min(.8 / (scale * 1.5) - editor.gridScale, .4))
  lg.push("all")
  lg.setColor(.3,.3,.35,1)
  -- Calculate visible grid boundaries, aligning with tile edges
  local startX = math.floor((x - viewportW / 2 / scale) / tileW) * tileW
  local endX = math.ceil((x + viewportW / 2 / scale) / tileW) * tileW
  local startY = math.floor((y - viewportH / 2 / scale) / tileH) * tileH
  local endY = math.ceil((y + viewportH / 2 / scale) / tileH) * tileH

  -- Draw vertical lines at tile edges
  for gridX = startX, endX, tileW do
    local screenX = (gridX - x) * scale + viewportW / 2
    lg.line(screenX, 0, screenX, viewportH)
  end

  -- Draw horizontal lines at tile edges
  for gridY = startY, endY, tileH do
    local screenY = (gridY - y) * scale + viewportH / 2
    lg.line(0, screenY, viewportW, screenY)
  end
  lg.pop()
end

local getBoxGridPosition = function(box)
  local scale = editor.suit.scale + editor.gridScale
  local x, y = editor.gridX, editor.gridY
  local screenX = (box.x * editor.tileW - x) * scale
  local screenY = (box.y * editor.tileH - y) * scale
  local screenW = box.w * editor.tileW * scale
  local screenH = box.h * editor.tileH * scale
  return screenX, screenY, screenW, screenH
  --return box.x * editor.tileW - editoir.gridX, box.y * editor.tileH - editor.gridY, box.w * editor.tileW, box.h * editor.tileH 
end

local getNewPosition = function(screenX, screenY, screenW, screenH, mouseX, mouseY)
  if movingBoxDirection:find("N") then
    screenH = screenH - (mouseY - screenY)
    screenY = mouseY
  elseif movingBoxDirection:find("S") then
    screenH = screenH + (mouseY - screenY - screenH)
  end
  if movingBoxDirection:find("W") then
    screenW = screenW - (mouseX - screenX)
    screenX = mouseX
  elseif movingBoxDirection:find("E") then
    screenW = screenW + (mouseX - screenX - screenW)
  end
  return screenX, screenY, screenW, screenH
end

local drawBox = function(box)
  local screenX, screenY, screenW, screenH = getBoxGridPosition(box)
  local r, g, b = unpack(box.color)
  if editor.activeBox == box then
    r, g, b = 1, 0, 0
    if movingBox then
      r, g, b = .7,.7,.7
      screenX, screenY, screenW, screenH = getNewPosition(screenX, screenY, screenW, screenH, box.mouseX, box.mouseY)
      print(screenX, screenY, screenW, screenH)
    end
  end
  lg.push("all")
  lg.setColor(r,g,b, box.a or 0.4)
  lg.rectangle("fill", screenX, screenY, screenW, screenH)
  lg.setColor(r,g,b, 1.0)
  lg.rectangle("line", screenX, screenY, screenW, screenH)
  if box == editor.activeBox then
    local r = movingBoxRadius
    lg.circle("fill", screenX, screenY, r) -- NW
    lg.circle("fill", screenX + screenW / 2, screenY, r) -- N
    lg.circle("fill", screenX + screenW, screenY, r) -- NE
    lg.circle("fill", screenX + screenW, screenY + screenH / 2, r) -- E
    lg.circle("fill", screenX + screenW, screenY + screenH, r) -- SE
    lg.circle("fill", screenX + screenW / 2, screenY + screenH, r) -- S
    lg.circle("fill", screenX, screenY + screenH, r) -- SW
    lg.circle("fill", screenX, screenY + screenH / 2, r) -- W
  end
  lg.pop()
  return screenX, screenY
end

local drawComment = function(comment)
  local scale = editor.suit.scale + editor.gridScale
  local screenX, screenY = drawBox(comment)
  lg.push("all")
  lg.setFont(editor.monoFont)
  lg.print(" "..tostring(comment.text), screenX, screenY,0,scale/editor.monoFontScale)
  lg.pop()
end

editor.draw = function()
  local scale = editor.suit.scale + editor.gridScale
  local w, h = lg.getDimensions()
  lg.push("all")
  lg.circle("fill", 0,0, 5)
  drawGrid(editor.gridX, editor.gridY, editor.tileW, editor.tileH, w, h, scale)
  lg.push("all")
  lg.translate(lg.getWidth()/2,lg.getHeight()/2)
  for _, box in ipairs(editor.project.boxes) do
    if box.type == "comment" then
      drawComment(box)
    else
      drawBox(box)
    end
  end
  lg.pop()
  lg.pop()
end

editor.drawAboveUI = function()

end

editor.resize = function(_, _)

end

editor.resizeGrid = function(gridScale)
  local fontSize = 20
  if gridScale <= -0.4 then
    fontSize = 10
  elseif gridScale >= 1 then
    fontSize = 30
  end
  editor.monoFontScale = fontSize/15
  local fontName = "font.mono."..fontSize
  if not assets[fontName] then
    assets[fontName] = lg.newFont(assets._path["font.mono"], fontSize)
  end
  editor.monoFont = assets[fontName]
end

editor.convertMouseToGrid = function(x, y)
  local scale = editor.suit.scale + editor.gridScale
  local w, h = lg.getDimensions()
  local gridX = math.floor((x - w / 2) / scale + editor.gridX)
  local gridY = math.floor((y - h / 2) / scale + editor.gridY)
  local tileX = math.floor(gridX / editor.tileW)
  local tileY = math.floor(gridY / editor.tileH)
  gridX, gridY = (gridX - editor.gridX) * scale, (gridY - editor.gridY) * scale
  return tileX, tileY, gridX, gridY
end

editor.canPlaceBox = function(x, y, w, h)
  for _, box in ipairs(editor.project.boxes) do
    if box.x < x + w     and
       box.x + box.w > x and
       box.y < y + h     and
       box.y + box.h > y then
        return false
    end
  end
  return true
end

editor.isPointInBox = function(x, y)
  for _, box in ipairs(editor.project.boxes) do
    if box.x <= x and
       box.x + box.w >= x and
       box.y <= y and
       box.y + box.h >= y then
      return true, box
    end
  end
  return false, nil
end

editor.keypressed = function(_, scancode)
  local listeners = editor.keyListen[scancode]
  if listeners then
    local x, y = editor.convertMouseToGrid(lm.getPosition())
    for _, listener in ipairs(listeners) do
      listener(scancode, x, y)
    end
  end
end

local pressedTime
editor.mousepressed = function(x, y, button)
  if editor.suit:anyHovered() then return end
  if button == 1 then
    local tx, ty, gx, gy = editor.convertMouseToGrid(x, y)
    if movingBoxDirection then
      movingBox = true
      local box = editor.activeBox
      box.mouseX = gx
      box.mouseY = gy
      return
    end
    local isInBox, box = editor.isPointInBox(tx, ty)
    if isInBox then
      editor.activeBox = box
      return
    end
    movingGrid = true
    pressedTime = lt.getTime()
  end
  if button == 3 then
    movingGrid = true
  end
  if movingGrid and cursor_sizeall then
    lm.setCursor(cursor_sizeall)
  end
end

local isPointInCircle = function(cx, cy, r, x, y) 
  return (x - cx)^2 + (y - cy)^2 <= r^2
end

editor.mousemoved = function(x, y, dx, dy)
  if movingGrid then
    local scale = editor.suit.scale + editor.gridScale
    editor.gridX = editor.gridX - dx / scale
    editor.gridY = editor.gridY - dy / scale
    return
  end
  if editor.activeBox then
    local _, _, gridX, gridY = editor.convertMouseToGrid(x, y)
    if movingBox then
      local box = editor.activeBox
      box.mouseX = gridX
      box.mouseY = gridY
      if isCursorSupported then
        lm.setCursor(movingBoxChanged)
      end
      return
    end
    local bx, by, bw, bh = getBoxGridPosition(editor.activeBox)
    local r = movingBoxRadius
    local cardinalPositions = {
      {x = bx,        y = by,        dir = "NW", cursor = cursor_sizenwse},
      {x = bx + bw/2, y = by,        dir = "N",  cursor = cursor_sizens},
      {x = bx + bw,   y = by,        dir = "NE", cursor = cursor_sizenesw},
      {x = bx + bw,   y = by + bh/2, dir = "E",  cursor = cursor_sizewe},
      {x = bx + bw,   y = by + bh,   dir = "SE", cursor = cursor_sizenwse},
      {x = bx + bw/2, y = by + bh,   dir = "S",  cursor = cursor_sizens},
      {x = bx,        y = by + bh,   dir = "SW", cursor = cursor_sizenesw},
      {x = bx,        y = by + bh/2, dir = "W",  cursor = cursor_sizewe}
    }
    for _, cardinal in ipairs(cardinalPositions) do
      if isPointInCircle(cardinal.x, cardinal.y, r, gridX, gridY) then
        movingBoxDirection = cardinal.dir
        movingBoxChanged = cardinal.cursor or true
        break
      end
    end
    if not movingBoxChanged then
      movingBoxDirection = nil
      lm.setCursor(nil)
    elseif isCursorSupported then
      lm.setCursor(movingBoxChanged)
      movingBoxChanged = nil
    end
  end
end

editor.mousereleased = function(_, _, button)
  if movingGrid then
    movingGrid = false
    lm.setCursor(nil)
  end
  if movingBox then
    local box = editor.activeBox
    local scale = editor.suit.scale + editor.gridScale
    local sx, sy, sw, sh = getBoxGridPosition(box)
    local gx, gy, gw, gh = getNewPosition(sx, sy, sw, sh, box.mouseX, box.mouseY)
    local dx, dy, dw, dh = gx - sx, gy - sy, gw - sw, gh - sh
    print(sx, sy, sw, sh, ":", gx, gy, gw, gh, ":", dx, dy, dw, dh)
    local scaledTileW = editor.tileW * scale
    local scaledTileH = editor.tileH * scale
    if dx ~= 0 then
        box.x = box.x + math.floor(dx / scaledTileW)
    end
    if dy ~= 0 then
      box.y = box.y + math.floor(dy / scaledTileH)
    end
    if dw ~= 0 then
      print("width", box.w)
      box.w = box.w + math.ceil(dw / scaledTileW)
      print(box.w)
    end
    if dh ~= 0 then
      print("height", box.h)
      box.h = box.h + math.ceil(dh / scaledTileH)
      print(box.h)
    end
    if box.w < 0 then
      box.x = box.x + box.w
      box.w = -box.w
    end
    if box.h < 0 then
      box.y = box.y + box.h
      box.h = -box.h
    end
    print("CHANGED TO:", box.x, box.y, box.w, box.h)
    box.mouseX = nil
    box.mouseY = nil
    movingBoxChanged = nil
    movingBoxDirection = nil
    movingBox = false
    lm.setCursor(nil)
  end
  if pressedTime and lt.getTime() - pressedTime < 0.1 then
    editor.activeBox = nil
  end
  pressedTime = nil
end

local wheelmovedTime = -100
editor.wheelmoved = function(_, _, _, y)
  local speed = 1
  if lt.getTime() - wheelmovedTime < 0.1 then
    speed = 2
  end
  editor.gridScale = editor.gridScale + y * 0.05 * speed
  local touched = false
  if editor.gridScale < -.5 then
    editor.gridScale = -.5
    touched = true
  elseif editor.gridScale > 1.2 then
    editor.gridScale = 1.2
    touched = true
  end
  if not touched then
    editor.resizeGrid(editor.gridScale)
    wheelmovedTime = lt.getTime()
  end
end

return editor