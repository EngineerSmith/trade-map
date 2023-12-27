local project = { }
project.__index = project

local lt = love.timer

local json = require("util.json")
local file = require("util.file")
local color = require("util.color")

local nfs = require("libs.nativefs")

local companyUtil = require("src.companyUtil")

local lfs = love.filesystem

local tradePath = "/server_scripts/base/trading/"
local langPath = "/assets/ptdye/lang/"
local sealPath = "/assets/wares/textures/gui/seal/"

local projectsFile = "projects.json"
local projectFile = tradePath .. ".meta"
local projectTradeTree = tradePath .. "tradeTree.json"

local instanceInfo = { }
project.getInstanceInfo = function() return instanceInfo end

project.new = function(path)
  if not nfs.getInfo(path, "directory") then
    return nil, "Could not find the directory at "..tostring(path)
  end
  
  project.addProject(path)

  return project
end

project.getActiveProjects = function()
  if lfs.getInfo(projectsFile, "file") then
    local success, projects = json.decode(projectsFile)
    return projects
  end
end

project.addProject = function(path)
  local projects = project.getActiveProjects() or {}
  local found = false
  for i, project in ipairs(projects) do
    if project.path == path then
      project.time = os.time()
      table.remove(projects, i)
      table.insert(projects, 1, project)
      found = true
    end
  end
  if not found then
    table.insert(projects, 1, {path = path, time = os.time()})
  end
  json.encode(projectsFile, projects)
end

project.loadProject = function(path)
  instanceInfo = { 
    seal = { }
  }
  instanceInfo.path = path
  -- new Project
  if not nfs.getInfo(path..projectFile, "file") then
    print("New project: creating new project profile @ "..path..projectFile)
    love.window.setTitle("Trade Map - "..path)
    return setmetatable({
        dirty = false,
        companies = { },
        boxes = { },
        tradeRoutes = { },
      }, project)
  else -- existing Project
    print("Pre-existing project: attempting to open project profile")
    local success, self = json.decode(path..projectFile, true)
    if not success then 
      return nil, "A problem appeared trying to load the project metadata.\n"..tostring(self)
    end
    print("Opened project profile")
    love.window.setTitle("Trade Map - "..(self.name))
    local success, trades = json.decode(path..projectTradeTree, true)
    if not success then
      return nil, "A problem appeared trying to load the trade tree json.\n"..tostring(trades)
    end
    print("Opened trade tree json")
    instanceInfo.trades = trades
    setmetatable(self, project)
    self.dirty = false
    self.boxes = self.boxes or { }

    self:loadCompanies()
    self:loadLocalization()
    self:loadTradeRoutes()
    print("Loaded "..#self.companies.." companies")
    for _, company in ipairs(self.companies) do
      print(("\tAgreements: %3d   FileName: %s"):format(#company.agreement or 0, company.fileName))
    end
    return self
  end
end

project.close = function(self)
  love.window.setTitle("Trade Map")
  return true
end

project.saveProject = function(self)
  if self.dirty then
    self.dirty = nil
    local start = lt.getTime()
    print("Saving!")
    local success, errorMessage = json.encode(instanceInfo.path..projectFile, self, true)
    print("Saved metadata to "..instanceInfo.path..projectFile)
    if not success then
      self.dirty = true
      return errorMessage
    end
    local success, errorMessage = json.encode(instanceInfo.path..projectTradeTree, instanceInfo.trades, true)
    if not success then
      self.dirty = true
      return errorMessage
    end
    print("Saved trade tree to "..instanceInfo.path..projectTradeTree)
    local companyDirectory = instanceInfo.path .. tradePath .. "company/"
    print("Saving companies:")
    for _, company in ipairs(self.companies) do
      local path = instanceInfo.path..sealPath..company.fileName..".png"
      local hasSeal = nfs.getInfo(path, "file") ~= nil
      local path = companyDirectory..(company.name)..".js"
      nfs.write(path, companyUtil.companyToScript(company, hasSeal))
      print("\tSaved to "..path)
    end

    local stop = love.timer.getTime()
    print(("Saving took %.4f ms"):format((stop - start)*1000))

    project.addProject(instanceInfo.path)
    self.dirty = false
    return true
  end
end

project.loadCompanies = function(self)
  self.companies = self.companies or { }
  instanceInfo.tradeBoxes = { }
  local map = { }
  for _, company in ipairs(self.companies) do
    map[company.fileName] = company
  end
  local companyDirectory = instanceInfo.path .. tradePath .. "company/"
  for _, filePath in ipairs(nfs.getDirectoryItems(companyDirectory)) do
    if nfs.getInfo(companyDirectory .. filePath, "file") and file.getFileExtension(filePath) == "js" then
      local fileName = file.getFileName(filePath)
      local company = map[fileName]
      if not company then
        company = {
          fileName = fileName,
          agreement = { },
        }
        table.insert(self.companies, company)
        self.dirty = true
      end
      local script = nfs.read(companyDirectory..filePath)
      local dirty, errorMessage = companyUtil.scriptToCompany(script, company)
      if dirty == nil then
        print("Error occured trying to transform "..companyDirectory..filePath..": Given error message: "..errorMessage)
        company.warning = errorMessage --todo add UI
      else
        company.warning = nil
        if dirty == true then
          self.diry = true
        end
        instanceInfo.tradeBoxes[company.abbreviation] = { }
        local tradeBoxes = instanceInfo.tradeBoxes[company.abbreviation]
        for _, box in ipairs(self.boxes) do
          if box.type == "trade" and box.company == company.abbreviation then
            local found = false
            for _, agreement in ipairs(company.agreement) do
              if agreement.name == box.agreement then
                found = true
                break
              end
            end
            if not found then
              tradeBoxes[box.agreement] = "Warning! this agreement is not found within the companies javascript file!"
            else
              tradeBoxes[box.agreement] = true
            end
          end
        end
      end
    end
  end
  table.sort(self.companies, function(a, b) return a.name < b.name end)
  instanceInfo.abbreviation = { }
  for _, company in ipairs(self.companies) do
    -- instance - abb to company
    instanceInfo.abbreviation[company.abbreviation] = company
    -- color
    if not company.color then
      company.color = color.getDeterministicColor(company.abbreviation)
      self.dirty = true
    end
    -- seal
    local path = instanceInfo.path..sealPath..company.fileName..".png"
    if nfs.getInfo(path, "file") then
      company.hasSeal = true
      local fd = nfs.newFileData(path, company.fileName..".png")
      local seal = love.graphics.newImage(fd)
      seal:setFilter('nearest')
      instanceInfo.seal[company.name] = seal
    else
      print("No seal for "..company.fileName..", at "..path)
    end
  end
end

project.loadLocalization = function()
  local file = instanceInfo.path..langPath.."en_us.json"
  if nfs.getInfo(file, "file") then
    local success, lang = json.decode(file, true)
    if success then
      print("Loaded "..file)
      instanceInfo.lang = lang
    else
      print("Couldn't load "..file)
    end
  end
end

project.loadTradeRoutes = function(self)
  
end

return project