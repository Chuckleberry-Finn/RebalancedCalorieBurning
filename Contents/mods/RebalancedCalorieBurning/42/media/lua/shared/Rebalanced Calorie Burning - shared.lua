---values and methods taken from `zombie\characters\BodyDamage\Nutrition.java`

---Values from vanilla (42.13.1)
local caloriesDecrease = {}
caloriesDecrease.Exercise = 0.13
caloriesDecrease.Sleeping = 0.003
caloriesDecrease.Normal = 0.016
---additional rates
caloriesDecrease.Sitting = 0.010 --(Normal * 0.66)


---used for debug checks that don't spam the log
local debugChecks = {state = "", lastState = ""}


---@param player IsoPlayer|IsoGameCharacter
local function RCB_updateCalories(player)
    if not player then return end

    local pNutrition = player:getNutrition()
    if not pNutrition then return end

    ---Recreating the Vanilla Function
    --base caloric burning rate
    local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
    local currentAction = actionQueue.queue[1]
    local baseRate = (currentAction and currentAction.caloriesModifier) or 1
    local laboriousState = player:isCurrentState(SwipeStatePlayer.instance()) or player:isCurrentState(ClimbOverFenceState.instance()) or player:isCurrentState(ClimbThroughWindowState.instance())
    if laboriousState then
        baseRate = 8
    end

    --thermoModifier
    local thermoModifier = 1
    --the vanilla method ignores thermoregulation for running, lets also add a negate for sprinting
    local pBodyDamage = player:getBodyDamage()
    if pBodyDamage then
        local pbdThermoregulator = pBodyDamage:getThermoregulator()
        if pbdThermoregulator then
            thermoModifier = pbdThermoregulator:getEnergyMultiplier()
        end
    end

    --weightModifier
    local weightModifier = (pNutrition:getWeight() / 80)
    local appliedCaloriesDecrease = caloriesDecrease.Normal

    if player:isRunning() and player:isPlayerMoving() then
        baseRate = 1.0
        thermoModifier = 1
        appliedCaloriesDecrease = caloriesDecrease.Exercise
    elseif player:isSprinting() and player:isPlayerMoving() then
        baseRate = 1.3
        thermoModifier = 1
        appliedCaloriesDecrease = caloriesDecrease.Exercise
    elseif player:isPlayerMoving() then
        baseRate = 0.6
        thermoModifier = 1
        appliedCaloriesDecrease = caloriesDecrease.Exercise
    elseif player:isAsleep() then
        appliedCaloriesDecrease = caloriesDecrease.Sleeping
    else
        appliedCaloriesDecrease = caloriesDecrease.Normal
    end

    ---Recreated Vanilla Base Rate:
    --Apply appliedCaloriesDecrease here for vanilla value
    local vanillaBaseRate = baseRate * appliedCaloriesDecrease * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()

    --Apply our own decrease rates
    if currentAction and currentAction.caloriesModifier then
        debugChecks.state = "timed action"
        baseRate = currentAction.caloriesModifier * (SandboxVars.RebalancedCalorieBurning.TimedActionMultiplier or 1)
    elseif laboriousState then
        debugChecks.state = "climbing"
        baseRate = 8 * (SandboxVars.RebalancedCalorieBurning.TimedActionMultiplier or 1)
    elseif player:isPlayerMoving() then
        if player:isSprinting() then
            debugChecks.state = "sprinting"
            baseRate = (SandboxVars.RebalancedCalorieBurning.SprintingMultiplier or 1) * 1.3

        elseif player:isRunning() then
            debugChecks.state = "running"
            baseRate = SandboxVars.RebalancedCalorieBurning.RunningMultiplier or 1
        else
            debugChecks.state = "moving"
            baseRate = (SandboxVars.RebalancedCalorieBurning.WalkingMultiplier or 1) * 0.6
        end

    elseif player:isAsleep() then
        debugChecks.state = "sleeping"
        baseRate = SandboxVars.RebalancedCalorieBurning.AsleepMultiplier or 1

    elseif player:isSitOnGround() then
        debugChecks.state = "sitting"
        baseRate = SandboxVars.RebalancedCalorieBurning.SittingMultiplier or 1
        appliedCaloriesDecrease = caloriesDecrease.Sitting
    else
        debugChecks.state = "idle"
        baseRate = SandboxVars.RebalancedCalorieBurning.IdleMultiplier or 1
    end

    local rebalancedRate = baseRate * appliedCaloriesDecrease * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()

    --inventory impact
    local carryingRatio = player:getInventoryWeight()/player:getMaxWeight()
    local inventoryModifier = 1+(carryingRatio*0.1 *SandboxVars.RebalancedCalorieBurning.CarryMultiplier)
    rebalancedRate = rebalancedRate * inventoryModifier


    ---Apply sandbox option
    if SandboxVars.RebalancedCalorieBurning.CalorieMultiplier then rebalancedRate = rebalancedRate * SandboxVars.RebalancedCalorieBurning.CalorieMultiplier end

    ---Compensate for baseline caloric burn
    local burnRate = (rebalancedRate-vanillaBaseRate)

    if burnRate ~= 0 then
        --if getDebug() and (debugChecks.state~=debugChecks.lastState ) and player==getSpecificPlayer(0) then
        --    print("Rebalanced Calorie Burning: ["..debugChecks.state.."]  vanilla:"..vanillaBaseRate.."  added-burn:"..burnRate)
        --    debugChecks.lastState = debugChecks.state
        --end
        pNutrition:setCalories(pNutrition:getCalories()-burnRate)
    end

    return burnRate
end

Events.OnPlayerUpdate.Add(RCB_updateCalories)