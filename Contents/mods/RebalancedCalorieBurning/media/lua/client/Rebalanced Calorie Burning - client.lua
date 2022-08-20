---values and methods taken from `zombie\characters\BodyDamage\Nutrition.java`

---Values from vanilla (41.73)
local caloriesDecrease = {}
caloriesDecrease.Exercise = 0.13
caloriesDecrease.Sleeping = 0.003
caloriesDecrease.Normal = 0.016
---additional rates
caloriesDecrease.Sprinting = caloriesDecrease.Exercise*2
caloriesDecrease.Walking = caloriesDecrease.Exercise/2
caloriesDecrease.Sitting = caloriesDecrease.Normal*0.66


---used for debug checks that don't spam the log
local debugChecks = {state = "", lastState = "", vanillaRateOffsetError = false}


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

    local appliedCaloriesDecrease = caloriesDecrease.Normal
    if player:isPlayerMoving() and player:isRunning() then
        thermoModifier = 1
        appliedCaloriesDecrease = caloriesDecrease.Exercise
    elseif player:isAsleep() then
        appliedCaloriesDecrease = caloriesDecrease.Sleeping
    end

    ---Recreated Vanilla Base Rate:
    --Apply appliedCaloriesDecrease here for vanilla value
    local vanillaBaseRate = baseRate * appliedCaloriesDecrease * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()

    --Apply our own decrease rates
    if player:isPlayerMoving() then
        if player:isSprinting() then
            debugChecks.state = "sprinting"
            thermoModifier = 1
            appliedCaloriesDecrease = caloriesDecrease.Sprinting
        elseif player:isRunning() then
            debugChecks.state = "running"
            thermoModifier = 1
            appliedCaloriesDecrease = caloriesDecrease.Exercise
        else
            debugChecks.state = "moving"
            appliedCaloriesDecrease = caloriesDecrease.Walking
        end
    elseif player:isAsleep() then
        debugChecks.state = "sleeping"
        appliedCaloriesDecrease = caloriesDecrease.Sleeping
    elseif player:isSitOnGround() then
        debugChecks.state = "sitting"
        appliedCaloriesDecrease = caloriesDecrease.Sitting
    else
        debugChecks.state = "idle"
        appliedCaloriesDecrease = caloriesDecrease.Normal
    end

    ---Follow through with calculating base rate:
    baseRate = baseRate * appliedCaloriesDecrease * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()

    if (not debugChecks.vanillaRateOffsetError) and (not player:isPlayerMoving()) and (baseRate~=vanillaBaseRate) then
        debugChecks.vanillaRateOffsetError = true
        print("ERROR: Rebalanced Calorie Burning: Vanilla-Base-Rate does not match expected rate. This is not a real error but needs to be reported. :)")
    end

    --inventory impact
    local carryingRatio = math.max(0,player:getInventoryWeight()/player:getMaxWeight())
    local inventoryModifier = 1+(carryingRatio*0.01)
    baseRate = baseRate / inventoryModifier

    ---Apply sandbox option
    if SandboxVars.RebalancedCalorieBurning.CalorieMultiplier then
        baseRate = baseRate * SandboxVars.RebalancedCalorieBurning.CalorieMultiplier
    end

    ---Compensate for baseline caloric burn
    baseRate = (baseRate-vanillaBaseRate)

    if baseRate ~= 0 then

        if getDebug() and (debugChecks.state~=debugChecks.lastState ) then
            print("Rebalanced Calorie Burning: ["..debugChecks.state.."]  added-burn:"..baseRate)
            debugChecks.lastState = debugChecks.state
        end

        pNutrition:setCalories(pNutrition:getCalories()-baseRate)
    end

    return baseRate
end

Events.OnPlayerUpdate.Add(RCB_updateCalories)