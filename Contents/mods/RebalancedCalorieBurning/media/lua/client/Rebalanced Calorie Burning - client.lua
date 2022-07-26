local caloriesDecreaseExercise = 0.13 --as per vanilla
local calorieDecreaseSleeping = 0.003
local calorieDecreaseNormal = 0.016

local maxRateForHeavyLoad = 2.8

---@param player IsoPlayer|IsoGameCharacter
local function RCB_updateCalories(player)
    if not player then return end

    local pNutrition = player:getNutrition()
    if not pNutrition then return end

    ---Recreating the Vanilla Function
    --base caloric burning rate
    local baseRate = 1

    --thermoModifier
    local thermoModifier = 1
    local pBodyDamage = player:getBodyDamage()
    if pBodyDamage then
        local pbdThermoregulator = pBodyDamage:getThermoregulator()
        if pbdThermoregulator then
            thermoModifier = pbdThermoregulator:getEnergyMultiplier()
        end
    end

    --weightModifier
    local weightModifier = (pNutrition:getWeight() / 80)

    if player:isCurrentState(SwipeStatePlayer.instance()) or player:isCurrentState(ClimbOverFenceState.instance()) or player:isCurrentState(ClimbThroughWindowState.instance()) then
        baseRate = 8
    end

    if player:isMoving() and player:isRunning() then
        baseRate = baseRate * (caloriesDecreaseExercise/2)
    elseif player:isAsleep() then
        baseRate = baseRate * calorieDecreaseSleeping
    else
        baseRate = baseRate * calorieDecreaseNormal
    end

    ---Recreated Vanilla Base Rate
    baseRate = baseRate * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()
    local vanillaBaseRate = baseRate

    --is moving but NOT running
    if player:isMoving() and not player:isRunning() then
        baseRate = baseRate * (caloriesDecreaseExercise/2)
    end

    --inventory impact, but only if over capacity
    local inventoryModifier = math.min(maxRateForHeavyLoad, math.max(1, player:getInventoryWeight() / player:getMaxWeight()))
    baseRate = baseRate * inventoryModifier

    ---Compensate for baseline calorie burn
    baseRate = math.abs(vanillaBaseRate-baseRate)

    pNutrition:setCalories(pNutrition:getCalories()-baseRate)
    return baseRate
end

Events.OnPlayerUpdate.Add(RCB_updateCalories)