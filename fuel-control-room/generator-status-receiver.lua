local controlPanelRight = component.proxy("AF9541D242A805E77323D59BAA1ACF01")
local controlPanelMiddle = component.proxy("86A24326403049185FCC1D8F8A4FF334")
local controlPanelLeft = component.proxy("F9CDFA214EB42798210A6BA27C3F16A5")
local mainPanelButton = controlPanelMiddle:getModule(5, 1, 0)
local generatorDataCollectionButton = controlPanelMiddle:getModule(5, 4, 0)
local generatorPowerResetButton = controlPanelMiddle:getModule(5, 7, 0)
local generatorPowerKillButton = controlPanelMiddle:getModule(5, 8, 0)
local net = computer.getPCIDevices(classes.NetworkCard)[1]

local componentCache = {}
local mappings = {}
local buttonMappings = {}
local flowMappings = {}
local panelActive = true

function getComponent(name)
  if not componentCache[name] then
    local id = component.findComponent(name)[1]
    if id == nil then
      computer.panic("Could not find component \"" .. name .. "\"")
    end
    local c = component.proxy(id)
    componentCache[name] = c
  end
  return componentCache[name]
end

function setColor(button, color)
  if color == "red" then
    button:setColor(1, 0, 0, 0.5)
  elseif color == "orange" then
    button:setColor(0.94, 0.32, 0.3, 0.15)
  elseif color == "yellow" then
    button:setColor(1, 1, 0, 0.15)
  elseif color == "green" then
    button:setColor(0, 1, 0, 0.15)
  else
    button:setColor(0, 0, 0, 0)
  end
end
function updateGenerator(mapping, data)
  local button = mapping.button
  local status = tonumber(table.unpack(data))

  if panelActive then
    local color
    if status < 0 then
      color = "red"
    elseif status < 5000 then
      color = "orange"
    elseif status < 45000 then
      color = "yellow"
    else
      color = "green"
    end
    setColor(button, color)
  end
end

function setupGenerator(x, y, controlPanel, panel, building, floor, counter)
  local generatorName = "Generator " .. building .. "-" .. floor .. "-" .. counter

  function action(mapping)
    sendBroadcast('generator', generatorName)
  end

  function disable(mapping)
    local button = mapping.button
    button:setColor(0, 0, 0, 0)
  end

  local button = controlPanel:getModule(x, y, panel)
  local mapping = {button=button, name=generatorName, action=action, update=updateGenerator, disable=disable}

  mappings[generatorName] = mapping
  buttonMappings[button.Hash] = mapping

  event.listen(button)
end

function setupBuildingOne()
  for floor = 1, 5, 1 do
    local generatorCounter = 1
    local startingY = 4 + 6 * (1 - floor % 2)
    local panel = math.floor((floor - 1) / 2)
    for y = startingY, startingY - 4, -1 do
      for x = 6, 10, 1 do
        setupGenerator(x, y, controlPanelRight, panel, 1, floor, generatorCounter)
        generatorCounter = generatorCounter + 1
      end
    end
    
    setupFlow(1, floor)
  end
  setupBuildingFlow(1)
end

function setupBuildingTwo()
  for floor = 1, 5, 1 do
    local generatorCounter = 1
    local startingY = 4 + 6 * (1 - floor % 2)
    local panel = math.floor((floor - 1) / 2)
    for y = startingY, startingY - 4, -1 do
      for x = 0, 4, 1 do
        setupGenerator(x, y, controlPanelLeft, panel, 2, floor, generatorCounter)
        generatorCounter = generatorCounter + 1
      end
    end
    
    setupFlow(2, floor)
  end
  setupBuildingFlow(2)
end

function updateFlow(mapping, data)
  local name = mapping.name
  local gauge = mapping.gauge
  local display = mapping.display
  local percent, flow = table.unpack(data)

  if panelActive then
    display:setText(flow .. " m³/m")
    gauge.percent = percent
  end
end

function disableFlow(mapping)
  local gauge = mapping.gauge
  local display = mapping.display
  gauge.percent = 0
  display:setText("")  
end

function setupFlow(building, floor)
  local name = "Valve " .. building .. "-" .. floor
  
  local throughput = 300
  local startingY = 4 + 6 * (1 - floor % 2)
  local x = ((building == 1) and 0 or 9)
  local controlPanel = ((building == 1) and controlPanelRight or controlPanelLeft)
  local panel = math.floor((floor - 1) / 2)
  local gauge = controlPanel:getModule(x, startingY, panel)
  gauge.limit = 1.0
  local display = controlPanel:getModule(x, startingY - 2, panel)

  local mapping = {gauge=gauge, display=display, throughput=throughput, name=name, update=updateFlow, disable=disableFlow}
  mappings[name] = mapping
end

function setupBuildingFlow(building)
  local name = "Valve " ..  building
  
  local throughput = 600
  local startingY = 6
  local x = ((building == 1) and 9 or 0)
  local panel = 1
  local gauge = controlPanelMiddle:getModule(x, startingY, panel)
  gauge.limit = 1.0
  local display = controlPanelMiddle:getModule(x, startingY - 2, panel)

  local mapping = {gauge=gauge, display=display, throughput=throughput, name=name, update=updateFlow, disable=disableFlow}
  mappings[name] = mapping
end

function disableAllControls()
  print("Disable")
  for _, mapping in pairs(mappings) do
    mapping:disable()
  end  
end

function setupMainPanelButton()
  function action(mapping)
    local button = mapping.button
    if panelActive then
      setColor(button, 'red')
      panelActive = false
      disableAllControls()
    else
      panelActive = true
      setColor(button, 'green')
    end
  end

  event.listen(mainPanelButton)

  buttonMappings[mainPanelButton.Hash] = {button=mainPanelButton, action=action}
end

function setupPowerButtons()
  function killPowerAction()
    sendBroadcast('grid', false)
  end

  function resetPowerAction()
    sendBroadcast('grid', true)
  end

  event.listen(generatorPowerKillButton)
  event.listen(generatorPowerResetButton)

  buttonMappings[generatorPowerKillButton.Hash] = {action=killPowerAction}
  buttonMappings[generatorPowerResetButton.Hash] = {action=resetPowerAction}
end

function setupFuelGeneratorDataCollection()
  function action(mapping)
    sendBroadcast('collection')
  end

  event.listen(generatorDataCollectionButton)

  buttonMappings[generatorDataCollectionButton.Hash] = {button=generatorDataCollectionButton, action=action}
end

function setupNetworkListening()
  event.listen(net)
  net:open(100)
end

function sendBroadcast(type, data)
  net:broadcast(101, type, data)
end

function handleNetworkMessage(type, data)
  if (type == 'update') then
    for entry in string.gmatch(data, "[^#]+") do
      local next = string.gmatch(entry, "[^,]+")
      local type = next()
      local name = next()

      local mapping = mappings[name]
      local data = {}
      local v = next()
      while v do
        table.insert(data, v)
        v = next()
      end
      mapping:update(data)
    end
  elseif (type == 'collection') then
    if (data) then
      setColor(generatorDataCollectionButton, 'green')
    else
      setColor(generatorDataCollectionButton, 'red')
    end
  elseif (type == 'grid') then
    if (data) then
      setColor(generatorPowerResetButton, 'green')
    else
      setColor(generatorPowerResetButton, 'red')
    end
  end
end

function setup()
  event.ignoreAll()

  componentCache = {}
  mappings = {}
  buttonMappings = {}
  flowMappings = {}
  panelActive = true

  setupBuildingOne()
  setupBuildingTwo()
  setupMainPanelButton()
  setupFuelGeneratorDataCollection()
  setupNetworkListening()
  setupPowerButtons()
end

setup()

while true do
  local e, s, sender, port, type, data = event.pull(0.5)

  local status, err = pcall(function ()
    if (e) then
      if e == "NetworkMessage" then
        --local start = computer.millis()
        handleNetworkMessage(type, data)
        --print("Performance:", computer.millis() - start, "ms")
      elseif e == "Trigger" then
        local mapping = buttonMappings[s.Hash]
        mapping:action()
      end
    end
  end)

  if (err) then
    print(e, err)
    setup()
  end
end