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
    --the vanilla method ignores thermoregulation for running, lets also add a negate for sprinting
    if not player:isRunning() and not player:isSprinting() then
        local pBodyDamage = player:getBodyDamage()
        if pBodyDamage then
            local pbdThermoregulator = pBodyDamage:getThermoregulator()
            if pbdThermoregulator then
                thermoModifier = pbdThermoregulator:getEnergyMultiplier()
            end
        end
    end

    --weightModifier
    local weightModifier = (pNutrition:getWeight() / 80)

    if player:isCurrentState(SwipeStatePlayer.instance()) or player:isCurrentState(ClimbOverFenceState.instance()) or player:isCurrentState(ClimbThroughWindowState.instance()) then
        baseRate = 8
    end

    if player:isPlayerMoving() and player:isRunning() then
        baseRate = baseRate * caloriesDecreaseExercise
    elseif player:isAsleep() then
        baseRate = baseRate * calorieDecreaseSleeping
    else
        baseRate = baseRate * calorieDecreaseNormal
    end

    ---Recreated Vanilla Base Rate
    local vanillaBaseRate = baseRate

    if player:isPlayerMoving() then
        --undo baseline calorieDecreaseNormal if player is moving
        baseRate = baseRate / calorieDecreaseNormal
        if player:isSprinting() then
            baseRate = baseRate * (caloriesDecreaseExercise*2)
        elseif not player:isRunning() then
            baseRate = baseRate * (caloriesDecreaseExercise/2)
        end
    end

    --inventory impact, but only if over capacity
    local inventoryModifier = math.min(maxRateForHeavyLoad, math.max(1, player:getInventoryWeight() / player:getMaxWeight()))
    baseRate = baseRate * inventoryModifier

    ---Compensate for baseline calorie burn
    baseRate = math.abs(vanillaBaseRate-baseRate)

    if baseRate > 0 then
        baseRate = baseRate * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()
        pNutrition:setCalories(pNutrition:getCalories()-baseRate)
    end

    return baseRate
end

Events.OnPlayerUpdate.Add(RCB_updateCalories)