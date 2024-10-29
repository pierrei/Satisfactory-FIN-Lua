local controlPanel = component.proxy("B57B5B154B3A49D1C5E81FA2E4BAB038")
local powerControlPanel = component.proxy("D66088A24538E84F786554999898C002")
local oilExtractorPanel = component.proxy("37C26A1E4EF560432FFC23B9E221FA6A")
local fuelOutPanel = component.proxy("41E9F1A64C8E7F189E5D679F0F357F7A")
local mainPowerSwitch = component.proxy("4AE17846467FB8F8023DB5B417D9A4D2")
local powerBankPowerSwitch = component.proxy("52F7A52A45EBBB4A29559FA4D15F55DB")
local controlRoomLights = component.proxy("79BECC754B12A8411F3717AA21006EBE")
local displaySwitch = controlPanel:getModule(10, 5, 0)

local mappings = {}
local mappingsByButton = {}
local panelActive = displaySwitch.state

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

function setupPowerControls() 
  function setupPowerSwitch(button, switch, indicator)
    function buttonAction(mapping)
      local switch = mapping.switch
      local button = mapping.button
      local indicator = mapping.indicator

      local state = button.state
      switch:setIsSwitchOn(state)
      if (state) then
        indicator:setColor(0, 1, 0, 0.15)
      else
        indicator:setColor(1, 0, 0, 0.5)
      end
    end

    function update(mapping)
      local switch = mapping.switch
      local button = mapping.button

      if (switch.isSwitchOn) then
        -- Green
        button:setColor(0, 1, 0, 0.15)
      else
        -- Red
        button:setColor(1, 0, 0, 0.5)
      end
    end

    local mapping = {button=button, switch=switch, indicator=indicator, buttonAction=buttonAction, update=update}
    table.insert(mappings, mapping)
    mappingsByButton[mapping.button.Hash] = mapping
    event.listen(button)
  end

  function updateFusedCircuit(indicator, circuit)
    if (circuit.isFuesed) then
      -- Red
      indicator:setColor(1, 0, 0, 0.5)
    else
      -- Green
      indicator:setColor(0, 1, 0, 0.15)
    end
  end

  function updateOnCircuit(condition)
    return function(indicator, circuit)      
      if (condition(circuit)) then
        -- Green
        indicator:setColor(0, 1, 0, 0.15)
      else
        -- Black
        indicator:setColor(0, 0, 0, 0)
      end
    end
  end

  function setupCircuit(indicator, circuit, updateCircuit)
    function update(mapping)
      local indicator = mapping.indicator
      local circuit = mapping.circuit
      
      updateCircuit(indicator, circuit)
    end

    local mapping = {indicator=indicator, circuit=circuit, update=update}
    table.insert(mappings, mapping)
  end
  
  function setupFuseLight(...)
    local circuits = {...}

    function update()
      local anyFuesed = false
      for i,v in ipairs(circuits) do
        anyFuesed = anyFuesed or v.isFuesed
      end

      if anyFuesed and controlRoomLights.colorSlot == 0 then
        controlRoomLights.colorSlot = 1
      end

      if not anyFuesed and controlRoomLights.colorSlot == 1 then
        controlRoomLights.colorSlot = 0
      end
    end

    table.insert(mappings, {update=update})
  end

  function setupPowerDisplay(display, circuit, getValue)
    function update(mapping)
      local display = mapping.display
      local circuit = mapping.circuit

      display:setText(getValue(circuit))
    end

    local mapping = {display=display, circuit=circuit, update=update}
    table.insert(mappings, mapping)
  end

  function setupGauge(gauge, circuit, getValue)
    function update(mapping)
      local gauge = mapping.gauge
      local circuit = mapping.circuit

      gauge.percent = getValue(circuit)
    end

    local mapping = {gauge=gauge, circuit=circuit, update=update}
    table.insert(mappings, mapping)
    gauge.limit = 1.0
  end

  local mainGridIndicator = powerControlPanel:getModule(1, 1, 0)
  local mainSwitchButton = powerControlPanel:getModule(3, 1, 0)
  local mainSwitchIndicator = powerControlPanel:getModule(3, 2, 0)
  local fuelProdGridIndicator = powerControlPanel:getModule(5, 1, 0)
  local powerBankSwitchButton = powerControlPanel:getModule(7, 1, 0)
  local powerBankSwitchIndicator = powerControlPanel:getModule(7, 2, 0)
  local powerBankGridIndicator = powerControlPanel:getModule(9, 1, 0)

  local mainGridPowerProducedDisplay = powerControlPanel:getModule(1, 9, 0)
  local mainGridPowerUsedDisplay = powerControlPanel:getModule(2, 9, 0)
  local fuelProdPowerUsageDisplay = powerControlPanel:getModule(5, 9, 0)
  local powerBankPowerStoreDisplay = powerControlPanel:getModule(8, 9, 0)
  local powerBankPowerGauge = powerControlPanel:getModule(9, 9, 0)
  local powerBankChargingIndicator = powerControlPanel:getModule(9, 7, 0)
  local powerBankOnBatteriesIndicator = powerControlPanel:getModule(9, 6, 0)
  local powerBankTimeToEmptyDisplay = powerControlPanel:getModule(9, 5, 0)

  local mainPowerSwitchConnectors = mainPowerSwitch:getPowerConnectors()
  local mainCircuit = mainPowerSwitchConnectors[2]:getCircuit()
  local fuelProdCircuit = mainPowerSwitchConnectors[1]:getCircuit()
  local powerBankCircuit = powerBankPowerSwitch:getPowerConnectors()[1]:getCircuit() 

  setupCircuit(mainGridIndicator, mainCircuit, updateFusedCircuit)
  setupCircuit(fuelProdGridIndicator, fuelProdCircuit, updateFusedCircuit)
  setupCircuit(powerBankGridIndicator, powerBankCircuit, updateFusedCircuit)

  setupPowerSwitch(mainSwitchButton, mainPowerSwitch, mainSwitchIndicator)
  setupPowerSwitch(powerBankSwitchButton, powerBankPowerSwitch, powerBankSwitchIndicator)

  setupPowerDisplay(mainGridPowerProducedDisplay, mainCircuit, function (circuit)
    return string.format("%.1f", circuit.production / 1000)
  end)
  setupPowerDisplay(mainGridPowerUsedDisplay, mainCircuit, function (circuit)
    return string.format("%.1f", circuit.consumption / 1000)
  end)
  setupPowerDisplay(fuelProdPowerUsageDisplay, fuelProdCircuit, function (circuit)
    return string.format("%.1f", circuit.consumption / 1000)
  end)
  setupPowerDisplay(powerBankPowerStoreDisplay, powerBankCircuit, function (circuit)
    return string.format("%.0f", circuit.batteryStore)
    --return string.format("%.0f", circuit.batteryInput)
  end)
  setupPowerDisplay(powerBankTimeToEmptyDisplay, powerBankCircuit, function (circuit)
    local time = circuit.batteryTimeUntilEmpty
    if (time == 0.0) then
      return "-"
    end

    local time = circuit.batteryTimeUntilEmpty
    local min = string.format("%.0f", time / 60)
    local seconds = string.format("%02d", math.floor(math.fmod(time, 60)))
    return min .. ":" .. seconds
  end)
  setupGauge(powerBankPowerGauge, powerBankCircuit, function (circuit)
    return circuit.batteryStorePercent
  end)

  setupCircuit(powerBankChargingIndicator, powerBankCircuit, updateOnCircuit(function (circuit)
    return circuit.batteryTimeUntilFull > 0
  end))
  setupCircuit(powerBankOnBatteriesIndicator, powerBankCircuit, updateOnCircuit(function (circuit)
    return circuit.batteryTimeUntilEmpty > 0
  end))
  setupFuseLight(mainCircuit, fuelProdCircuit, powerBankCircuit)
end

function setupRefinery(x, y, panel, refineryPrefix, refineryCounter)
  function refineryButtonAction(mapping)
    local refinery = mapping.refinery
    refinery.standby = not refinery.standby
  end

  function updateRefineryMapping(mapping)
    if panelActive then
      local gauge = mapping.gauge
      local refinery = mapping.refinery
      local button = mapping.button

      gauge.percent = refinery.productivity
      if refinery.standby then
        -- Red
        button:setColor(1, 0, 0, 0.5)
      else
        if refinery.productivity < 0.8 then
          -- Yellow
          button:setColor(1, 1, 0, 0.15)
        else
          -- Green
          button:setColor(0, 1, 0, 0.15)
        end
      end
    end
  end

  function disable(mapping)
    local gauge = mapping.gauge
    local button = mapping.button
    gauge.percent = 0
    button:setColor(0, 0, 0, 0)
  end

  local gauge = controlPanel:getModule(x, y, panel)
  local button = controlPanel:getModule(x, y -1, panel)
  local refineryAlias = refineryPrefix .. " " .. refineryCounter
  local refinery = component.proxy(component.findComponent(refineryAlias)[1])   

  local refineryMapping = {gauge=gauge, button=button, refinery=refinery, buttonAction=refineryButtonAction, update=updateRefineryMapping, disable=disable}

  table.insert(mappings, refineryMapping)
  mappingsByButton[button.Hash] = refineryMapping

  event.listen(button)
  gauge.limit = 1.0
end

function setupHeavyOilRefineries()
  local refineryCounter = 1
  for y = 2, 10, 2 do
    for x = 2, 8, 1 do
      setupRefinery(x, y, 0, "Heavy Oil", refineryCounter)
      refineryCounter = refineryCounter + 1
    end
  end
end

function setupMidPanelFuelRefineries()
  local refineryCounter = 1
  for y = 1, 7, 2 do
    for x = 2, 8, 1 do
      setupRefinery(x, y, 1, "Turbo Fuel", refineryCounter)
      refineryCounter = refineryCounter + 1
    end
  end
end

function setupTopPanelFuelRefineries()
  local refineryCounter = 29
  for y = 1, 3, 2 do
    for x = 4, 8, 1 do
      setupRefinery(x, y, 2, "Turbo Fuel", refineryCounter)
      refineryCounter = refineryCounter + 1
    end
  end
end

function setupOilExtractor(number, x, y)
  function buttonAction(mapping)
    local building = mapping.building
    building.standby = not building.standby
  end

  function update(mapping)
    if panelActive then
      local gauge = mapping.gauge
      local building = mapping.building
      local button = mapping.button

      gauge.percent = building.productivity
      if building.standby then
        -- Red
        button:setColor(1, 0, 0, 0.5)
      else
        if building.productivity < 0.8 then
          -- Yellow
          button:setColor(1, 1, 0, 0.15)
        else
          -- Green
          button:setColor(0, 1, 0, 0.15)
        end
      end
    end
  end

  function disable(mapping)
    local gauge = mapping.gauge
    local button = mapping.button
    gauge.percent = 0
    button:setColor(0, 0, 0, 0)
  end

  local gauge = oilExtractorPanel:getModule(x, y, 0)
  local button = oilExtractorPanel:getModule(x + 3, y, 0)
  local display = oilExtractorPanel:getModule(x, y - 2, 0)
  local name = "Oil Extractor " .. number
  local extractor = component.proxy(component.findComponent(name)[1])   

  local mapping = {gauge=gauge, button=button, display=display, building=extractor, buttonAction=buttonAction, update=update, disable=disable}

  table.insert(mappings, mapping)
  mappingsByButton[button.Hash] = mapping

  event.listen(button)
  gauge.limit = 1.0
end

function setupFlow(name, panel, x, y)
  function update(mapping)
    if panelActive then
      local pipe = mapping.pipe
      local display = mapping.display
      local gauge = mapping.gauge
      local average = mapping.average
      local throughput = 600

      local percent = 0
      local flow = "0"
      if (pipe.fluidBoxFlowLimit > 0) then
        local flowPercent = pipe.fluidBoxFlowThrough / pipe.fluidBoxFlowLimit
        local average = math.abs(average(flowPercent))
        percent = average
        flow = math.floor(average * throughput)
      end

      display:setText(flow .. " m³/m")
      gauge.percent = percent
    end
  end

  function disable(mapping)
    local gauge = mapping.gauge
    local display = mapping.display
    gauge.percent = 0
    display:setText("")
  end

  local gauge = panel:getModule(x, y, 0)
  local display = panel:getModule(x, y - 2, 0)

  local building = component.proxy(component.findComponent(name)[1])   
  local pipe = building:getPipeConnectors()[1]

  local mapping = {gauge=gauge, display=display, building=building, pipe=pipe, average=sma(50), update=update, disable=disable}

  table.insert(mappings, mapping)
  gauge.limit = 1.0
end

function setupOilExtractorPanel()
  setupOilExtractor(1, 2, 10)
  setupOilExtractor(2, 2, 6)
  setupOilExtractor(3, 2, 2)
  setupFlow("Oil Pump 1", oilExtractorPanel, 9, 8)
  setupFlow("Oil Pump 2", oilExtractorPanel, 9, 4)
  setupFlow("Fuel Out 1", fuelOutPanel, 2, 8)
  setupFlow("Fuel Out 2", fuelOutPanel, 2, 4)
end

function disableAllControls()
  print("Disable")
  for _, mapping in pairs(mappings) do
    if mapping["disable"] ~= nil then
      mapping:disable()
    end
  end  
end

function setupMainPanelSwitch()
  function action(mapping)
    local newState = mapping.switch.state

    if (panelActive ~= newState) then
      if newState then
        panelActive = true
      else
        panelActive = false
        disableAllControls()
      end
    end
  end

  event.listen(displaySwitch)

  mappingsByButton[displaySwitch.Hash] = {switch=displaySwitch, buttonAction=action}
end

function updateAllTheThings()
  for _, mapping in ipairs(mappings) do
    mapping.update(mapping)
  end
end

function setup()
  event.ignoreAll()

  mappings = {}
  mappingsByButton = {}
  circuitFuses = {}

  setupPowerControls()
  setupHeavyOilRefineries()
  setupMidPanelFuelRefineries()
  setupTopPanelFuelRefineries()
  setupOilExtractorPanel()
  setupMainPanelSwitch()
end

setup()

while true do
  local e, component = event.pull(0.5)

  local status, err = pcall(function ()
    if (e) then
      local mapping = mappingsByButton[component.Hash]
      mapping.buttonAction(mapping)
      event.pull(0.05)
    end

    updateAllTheThings()
  end)

  if (err) then
    print(e, err)
    setup()
  end
end