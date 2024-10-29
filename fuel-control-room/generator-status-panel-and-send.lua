local controlPanelRight = component.proxy("255B488344E43CE8606842B8F49DCDFA")
local controlPanelMiddle = component.proxy("828D993441BDEE93817E4CB9B1FD5E04")
local controlPanelLeft = component.proxy("77D7317644D1C820D9D7EB9AF1EB514D")
local powerSwitch = component.proxy("CF9C3BE0423778B98EFF0CB61BAB6EAB")
local mainPanelButton = controlPanelMiddle:getModule(5, 1, 0)
local collectionButton = controlPanelMiddle:getModule(5, 4, 0)
local powerResetButton = controlPanelMiddle:getModule(5, 7, 0)
local powerKillButton = controlPanelMiddle:getModule(5, 8, 0)

local net = computer.getPCIDevices(classes.NetworkCard)[1]

local componentCache = {}
local mappings = {}
local buttonMappings = {}
local flowMappings = {}
local generatorStandbyMapping = {}
local panelActive = true
local collectionActive = true

function sum(a, ...)
  if a then return a+sum(...) else return 0 end
end

function sma(period)
  local t = {}

  function average(n)
    if #t == period then table.remove(t, 1) end
    t[#t + 1] = n
    return sum(table.unpack(t)) / #t
  end
  return average
end

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

function addToSend(toSend, data)
  table.insert(toSend, table.concat(data, ","))
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

function updateGenerator(mapping, toSend)
  local generator = mapping.generator
  local button = mapping.button
  local name = mapping.name
  local fuelInventory = mapping.fuelInventory
  local inventoryFuel = fuelInventory.itemCount

  local status
  if generator.standby then
    -- Red
    status = -1
  else
    status = inventoryFuel
    --if inventoryFuel < 5000 then
    --  -- Yellow
    --  color = "yellow"
    --elseif inventoryFuel < 45000 then
    --  color = "orange"
    --else
    --  -- Green
    --  color = "green"
    --end
  end

  if panelActive then
    local color
    if status < 0 then
      color = "red"
    elseif status < 5000 then
      color = "orange"
    elseif inventoryFuel < 45000 then
      color = "yellow"
    else
      color = "green"
    end

    setColor(button, color)
  end

  addToSend(toSend, {"generator", name, status})
end

function setupGenerator(x, y, controlPanel, panel, building, floor, counter)
  local generatorName = "Generator " .. building .. "-" .. floor .. "-" .. counter
  local button = controlPanel:getModule(x, y, panel)
  local generator = getComponent(generatorName)
  local fuelInventory = generator:getInventories()[1]

  function disable()
    button:setColor(0, 0, 0, 0)
  end

  function toggleStandby()
    generator.standby = not generator.standby
  end

  function action()
    if panelActive then
      generator.standby = not generator.standby
    end
  end

  local mapping = {button=button, generator=generator, fuelInventory=fuelInventory, name=generatorName, action=action, update=updateGenerator, disable=disable}

  mappings[button.Hash] = mapping
  generatorStandbyMapping[generatorName] = toggleStandby

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

function updateFlow(mapping, toSend)  
  local name = mapping.name
  local pipe = mapping.pipe
  local gauge = mapping.gauge
  local display = mapping.display
  local average = mapping.average
  local throughput = mapping.throughput

  local percent = 0
  local flow = "0"
  if (pipe.fluidBoxFlowLimit > 0) then
    local flowPercent = pipe.fluidBoxFlowThrough / pipe.fluidBoxFlowLimit
    local average = math.abs(average(flowPercent))
    percent = average
    flow = math.floor(average * throughput)
  end

  if panelActive then
    display:setText(flow .. " m³/m")
    gauge.percent = percent
  end

  addToSend(toSend, {"flow", name, percent, flow})
end

function disableFlow(mapping)
  local gauge = mapping.gauge
  local display = mapping.display
  gauge.percent = 0
  display:setText("")  
end

function setupFlow(building, floor)
  local name = "Valve " .. building .. "-" .. floor
  local valve = getComponent(name)
  local pipe = valve:getPipeConnectors()[1]
  valve.potential = 0
  
  local throughput = 300
  local startingY = 4 + 6 * (1 - floor % 2)
  local x = ((building == 1) and 0 or 9)
  local controlPanel = ((building == 1) and controlPanelRight or controlPanelLeft)
  local panel = math.floor((floor - 1) / 2)
  local gauge = controlPanel:getModule(x, startingY, panel)
  gauge.limit = 1.0
  local display = controlPanel:getModule(x, startingY - 2, panel)

  local mapping = {gauge=gauge, display=display, pipe=pipe, throughput=throughput, average=sma(50), name=name, update=updateFlow, disable=disableFlow}
  mappings[gauge.Hash] = mapping
end

function setupBuildingFlow(building)
  local name = "Valve " ..  building
  local valve = getComponent(name)
  local pipe = valve:getPipeConnectors()[1]
  
  local throughput = 600
  local startingY = 6
  local x = ((building == 1) and 9 or 0)
  local panel = 1
  local gauge = controlPanelMiddle:getModule(x, startingY, panel)
  gauge.limit = 1.0
  local display = controlPanelMiddle:getModule(x, startingY - 2, panel)

  local mapping = {gauge=gauge, display=display, pipe=pipe, throughput=throughput, average=sma(50), name=name, update=updateFlow, disable=disableFlow}
  mappings[gauge.Hash] = mapping
end

function disableAllControls()
  for _, mapping in pairs(mappings) do
    if mapping.disable then
      mapping:disable()
    end
  end  
end

function setPanelActive(active)
  if active then
    panelActive = true
    setColor(mainPanelButton, "green")
  else
    panelActive = false
    setColor(mainPanelButton, "red")
    disableAllControls()
  end
end

function setupMainPanelButton()
  function action(mapping)
    setPanelActive(not panelActive)
  end

  event.listen(mainPanelButton)

  mappings[mainPanelButton.Hash] = {button=mainPanelButton, action=action}
end


function setupCollectionButton()
  function action(mapping)
    local button = mapping.button

    collectionActive = not collectionActive

    if collectionActive then
      setColor(button, "green")
    else
      setColor(button, "red")
      setPanelActive(false)
    end
  end

  event.listen(collectionButton)

  mappings[collectionButton.Hash] = {button=collectionButton, action=action}
end

function killPowerAction()
  powerSwitch:setIsSwitchOn(false)
  setColor(powerResetButton, "red")
  sendBroadcast('grid', false)
end

function resetPowerAction()
  powerSwitch:setIsSwitchOn(true)
  setColor(powerResetButton, "green")
  sendBroadcast('grid', true)
end

function setupPowerButtons()
  event.listen(powerKillButton)
  event.listen(powerResetButton)

  mappings[powerKillButton.Hash] = {action=killPowerAction}
  mappings[powerResetButton.Hash] = {action=resetPowerAction}
end

function updateAllTheThings()
  local toSend = {}
  for hash, mapping in pairs(mappings) do
    if mapping.update then
      mapping:update(toSend)
    end
  end
  sendUpdate(toSend)
end

function handleNetworkMessage(type, data)
  if type == 'collection' then
    collectionActive = not collectionActive
    sendBroadcast('collection', collectionActive)
    if (collectionActive) then
      setColor(collectionButton, 'green')
    else
      setColor(collectionButton, 'red')
    end
  elseif type == 'grid' then
    if data then
      resetPowerAction()
    else
      killPowerAction()
    end
  elseif type == 'generator' then
    local standbyToggle = generatorStandbyMapping[data]
    if standbyToggle then
      standbyToggle()
    else
      print("Failed to toggle standby for " .. data)
    end
  end
end

function setupNetworkListening()
  event.listen(net)
  net:open(101)
end

function sendUpdate(toSend)
  sendBroadcast('update', table.concat(toSend, "#"))
end

function sendBroadcast(type, data)
  net:broadcast(100, type, data)
end

setupBuildingOne()
setupBuildingTwo()
setupMainPanelButton()
setupCollectionButton()
setupPowerButtons()
setupNetworkListening()

while true do
  local e, s, sender, port, type, data = event.pull(0.5)
  if e then
    if e == "NetworkMessage" then
      --local start = computer.millis()
      handleNetworkMessage(type, data)
      --print("Performance:", computer.millis() - start, "ms")
    else
      local mapping = mappings[s.Hash]
      mapping:action()
    end
  end

  if collectionActive then
    --local start = computer.millis()
    updateAllTheThings()
    --print("Performance:", computer.millis() - start, "ms")
  end
end
