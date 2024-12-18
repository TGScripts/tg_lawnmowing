ESX = nil
local jobInProgress = false
local progressCompleted = false
local progressHandle = nil
local isMowing = false
local mowingProgress = 0
local mowingPaused = false
local lastMoveTime = 0
local isMoving = false

local tractor
local spawnedVehicle = nil

local playerPed = PlayerPedId()
local npcPed = nil
local blips = {}

Citizen.CreateThread(function()
    while ESX == nil do
        ESX = exports["es_extended"]:getSharedObject()
        Citizen.Wait(0)
    end
end)

function isPointInPolygon(point, polygon)
    local x, y = point.x, point.y
    local inside = false
    for i = 1, #polygon do
        local j = i % #polygon + 1
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        local intersect = ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        if intersect then inside = not inside end
    end
    return inside
end

function SpawnNPC()
    local model = GetHashKey(Config.NPC.model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Citizen.Wait(500)
    end

    npcPed = CreatePed(4, model, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z, Config.NPC.heading, false, true)
    SetEntityAsMissionEntity(npcPed, true, true)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    TaskSetBlockingOfNonTemporaryEvents(npcPed, true)

    if Config.NPC.blip.enabled == true then
        local blip = AddBlipForCoord(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)
        SetBlipSprite(blip, Config.NPC.blip.sprite)
        SetBlipColour(blip, Config.NPC.blip.color)
        SetBlipScale(blip, Config.NPC.blip.scale)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.NPC.blip.name)
        EndTextCommandSetBlipName(blip)
    end
end

function SpawnVehicle()
    local playerPed = PlayerPedId()
    local vehicleModel = GetHashKey(Config.AllowedVehicle)

    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Citizen.Wait(500)
    end

    spawnedVehicle = CreateVehicle(vehicleModel, Config.VehicleSpawnCoords.x, Config.VehicleSpawnCoords.y, Config.VehicleSpawnCoords.z, Config.VehicleSpawnCoords.heading, true, false)
    SetEntityAsMissionEntity(spawnedVehicle, true, true)
    TaskWarpPedIntoVehicle(playerPed, spawnedVehicle, -1)
end

function IsVehicleInRange(vehicle, radius)
    local playerPed = PlayerPedId()
    local vehicleCoords = GetEntityCoords(vehicle)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = Vdist(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, playerCoords.x, playerCoords.y, playerCoords.z)

    return distance <= radius
end

function DeleteJobVehicle()
    if spawnedVehicle and DoesEntityExist(spawnedVehicle) then
        if IsVehicleInRange(spawnedVehicle, 10.0) then
            DeleteVehicle(spawnedVehicle)
            spawnedVehicle = nil
        else
            tg_shownotification(tg_translate('vehicle_range'))
        end
    end
end

function InteractWithNPC()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    if Vdist(coords.x, coords.y, coords.z, Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z) < 3.0 then
        if not jobInProgress then
            ESX.ShowHelpNotification(tg_translate('input_start'))
            
            if IsControlJustReleased(0, 38) then  -- E-Taste
                jobInProgress = true
                mowingProgress = 0
                tg_shownotification(tg_translate('welcome_info'))
                SpawnVehicle()
                CreateMowingBlips()
            end
        else
            ESX.ShowHelpNotification(tg_translate('input_end'))
            
            if IsControlJustReleased(0, 47) then  -- G-Taste
                end_job()
            end
        end
    end
end

function end_job()
    if IsVehicleInRange(spawnedVehicle, 10.0) then
        isMowing = false
        jobInProgress = false
        tg_shownotification(tg_translate('job_end'))
        TriggerServerEvent('tg_lawnmowing:pay', Config.PerPercentPayment * mowingProgress)
        DeleteJobVehicle()
        RemoveMowingBlips()
    else
        tg_shownotification(tg_translate('vehicle_range'))
    end
end

function StartMowing()
    if jobInProgress then
        local playerPed = PlayerPedId()
        local playerVeh = GetVehiclePedIsIn(playerPed, false)

        if playerVeh and GetEntityModel(playerVeh) == GetHashKey(Config.AllowedVehicle) then

            isMowing = true
            tractor = playerVeh
            
            Citizen.CreateThread(function()
                while isMowing do
                    Citizen.Wait(0)

                    local coords = GetEntityCoords(playerPed)
                    if isPointInPolygon(coords, Config.LawnZone.points) then
                        local speed = GetEntitySpeed(playerPed)

                        if mowingPaused then
                            mowingPaused = false
                            tg_shownotification(tg_translate('mowing_restart'))
                        end

                        if speed > 0.1 and not progressCompleted then
                            if lastMoveTime == 0 or GetGameTimer() - lastMoveTime > 3000 then
                                mowingProgress = mowingProgress + 1
                                UpdateProgressNotification(mowingProgress)
                                lastMoveTime = GetGameTimer()
                            end
                        else
                            lastMoveTime = GetGameTimer()
                        end

                        if mowingProgress >= 100 and not progressCompleted then
                            tg_shownotification(tg_translate('job_finished'))
                            progressCompleted = true
                        end
                    else
                        if not mowingPaused then
                            tg_shownotification(tg_translate('zone_left'))
                        end
                        isMowing = false
                        mowingPaused = true
                        break
                    end

                    CheckIfPlayerExited()
                end
            end)
        end
    end
end

function CheckIfPlayerExited()
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)

    if playerVeh == 0 then
        if isMowing then
            tg_shownotification(tg_translate('left_vehicle_pause'))
            isMowing = false
            mowingPaused = true
        end
    end
end

function RemoveMowingBlips()
    for i in pairs(blips) do
        RemoveBlip(blips[i])
    end
end

function CreateMowingBlips()
    if Config.ShowBoundaries then
        local polygon = Config.LawnZone.points
        local interpolationSteps = 5

        for i = 1, #polygon do
            local startPoint = polygon[i]
            local endPoint = polygon[i % #polygon + 1]

            for step = 0, interpolationSteps do
                local t = step / interpolationSteps
                local interX = startPoint.x + (endPoint.x - startPoint.x) * t
                local interY = startPoint.y + (endPoint.y - startPoint.y) * t
                local interZ = startPoint.z + (endPoint.z - startPoint.z) * t

                local blip = AddBlipForCoord(interX, interY, interZ)
                SetBlipSprite(blip, 730)
                SetBlipColour(blip, 17)
                SetBlipScale(blip, 1.0)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(tg_translate('blips_boundary'))
                EndTextCommandSetBlipName(blip)

                table.insert(blips, blip)
            end
        end
    end
end

Citizen.CreateThread(function()
    SpawnNPC()

    while true do
        Citizen.Wait(0)

        InteractWithNPC()

        if jobInProgress then
            Citizen.Wait(0)
            local playerPed = PlayerPedId()
            local playerVeh = GetVehiclePedIsIn(playerPed, false)

            if playerVeh and GetEntityModel(playerVeh) == GetHashKey(Config.AllowedVehicle) then
                if not isMowing then
                    StartMowing()
                end
            end
        end
    end
end)

function UpdateProgressNotification(progress)
    local textureDict = "TG_Textures"
    RequestStreamedTextureDict(textureDict, true)

    while not HasStreamedTextureDictLoaded(textureDict) do
        Wait(0)
    end

    if not progressHandle then
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(tg_translate('progress_counter', progress))
        progressHandle = EndTextCommandThefeedPostMessagetext(textureDict, "TG_Logo", false, 0, "TG Lawnmowing Script", "")
    else
        ThefeedRemoveItem(progressHandle)
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(tg_translate('progress_counter', progress))
        progressHandle = EndTextCommandThefeedPostMessagetext(textureDict, "TG_Logo", false, 0, "TG Lawnmowing Script", "")
    end

    SetStreamedTextureDictAsNoLongerNeeded(textureDict)
end

RegisterNetEvent('tg_lawnmowing:tg_shownotification')
AddEventHandler('tg_lawnmowing:tg_shownotification', function(message)
    tg_shownotification(message)
end)

function tg_shownotification(message)
    local textureDict = "TG_Textures"
    RequestStreamedTextureDict(textureDict, true)

    while not HasStreamedTextureDictLoaded(textureDict) do
        Wait(0)
    end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostMessagetext(textureDict, "TG_Logo", false, 0, "TG Lawnmowing Script", "")

    SetStreamedTextureDictAsNoLongerNeeded(textureDict)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if jobInProgress then
            end_job()
        end
    end
end)