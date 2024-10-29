---- Cannon Charging Computer ----

-- Will make sure batteries are loaded while the main grid is okay

local chargingSwitch = component.proxy("FE87D5744A788FEA159E8585370FF070")
local cannonSwitch = component.proxy("0664806D4E17B3FD21B434A7AB1FD1C8")
local controlPanel = component.proxy("D94DDACA4C325B1C0C78339BD1ACA9E5")

local powerConnectors = chargingSwitch:getPowerConnectors()
local batteryCircuit = powerConnectors[1]:getCircuit()
local mainCircuit = powerConnectors[2]:getCircuit()
local button = controlPanel:getModules()[1]

local chargeGoal = 1.0
local dischargeLimit = 1.0

function checkForUpdates()
  local batteryStorePercent = batteryCircuit.batteryStorePercent
  if chargingSwitch.isSwitchOn then
    if batteryStorePercent >= chargeGoal then
      chargingSwitch:setIsSwitchOn(false)
    end
  else 
    if not mainCircuit.isFuesed and batteryStorePercent < dischargeLimit then
      chargingSwitch:setIsSwitchOn(true)
    end
  end
end

event.listen(button)

while true do
  local status, err = pcall(function ()
    checkForUpdates()
    local e, component = event.pull(10)

    if e then
      cannonSwitch:setIsSwitchOn(true)
      event.pull(10)
      cannonSwitch:setIsSwitchOn(false)
    else
      checkForUpdates()
    end

  end)

  if (err) then
    print(err)
  end
end