---values and methods taken from `zombie\characters\BodyDamage\Nutrition.java`

local caloriesDecreaseExercise = 0.13 --as per vanilla
local calorieDecreaseSleeping = 0.003
local calorieDecreaseNormal = 0.016

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

    local appliedCaloriesDecrease = calorieDecreaseNormal
    if player:isPlayerMoving() and player:isRunning() then
        thermoModifier = 1
        appliedCaloriesDecrease = caloriesDecreaseExercise
    elseif player:isAsleep() then
        appliedCaloriesDecrease = calorieDecreaseSleeping
    end

    ---Recreated Vanilla Base Rate:
    --Apply appliedCaloriesDecrease here for vanilla value
    local vanillaBaseRate = baseRate * appliedCaloriesDecrease * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()

    --Apply our own decrease rates
    if player:isPlayerMoving() then
        if player:isSprinting() then
            debugChecks.state = "sprinting"
            thermoModifier = 1
            appliedCaloriesDecrease = (caloriesDecreaseExercise*2)
        elseif player:isRunning() then
            debugChecks.state = "running"
            thermoModifier = 1
            appliedCaloriesDecrease = caloriesDecreaseExercise
        else
            debugChecks.state = "moving"
            appliedCaloriesDecrease = (caloriesDecreaseExercise/2)
        end
    elseif player:isAsleep() then
        debugChecks.state = "sleeping"
        appliedCaloriesDecrease = calorieDecreaseSleeping
    elseif player:isSitOnGround() then
        debugChecks.state = "sitting"
        appliedCaloriesDecrease = (calorieDecreaseNormal*0.66)
    else
        debugChecks.state = "idle"
        appliedCaloriesDecrease = calorieDecreaseNormal
    end

    ---Follow through with calculating base rate:
    baseRate = baseRate * appliedCaloriesDecrease * weightModifier * thermoModifier * getGameTime():getGameWorldSecondsSinceLastUpdate()

    if (not debugChecks.vanillaRateOffsetError) and (not player:isPlayerMoving()) and (baseRate~=vanillaBaseRate) then
        debugChecks.vanillaRateOffsetError = true
        print("ERROR: Rebalanced Calorie Burning: Vanilla-Base-Rate does not match expected rate. This is not a real error but needs to be reported. :)")
    end

    --inventory impact
    local inventoryModifier = 1+(PZMath.clamp_01(player:getInventoryWeight() / player:getMaxWeight())*0.1)
    baseRate = baseRate / inventoryModifier

    ---Compensate for baseline caloric burn
    baseRate = math.abs(vanillaBaseRate-baseRate)

    if baseRate > 0 then

        if getDebug() and (debugChecks.state~=debugChecks.lastState ) then
            print("Rebalanced Calorie Burning: ["..debugChecks.state.."]  added-burn:"..baseRate)
            debugChecks.lastState = debugChecks.state
        end

        pNutrition:setCalories(pNutrition:getCalories()-baseRate)
    end

    return baseRate
end

Events.OnPlayerUpdate.Add(RCB_updateCalories)