local ESX = exports['es_extended']:getSharedObject()

local playerJobName = nil

local isHeliCamActive = false
local heliCam = nil
local heliEntity = nil

local lockedEntity = nil
local spotlightOn = false
local nightVisionOn = false
local thermalOn = false
local recordingOn = false

local currentFov = nil
local targetFov = nil
local camHeading = 0.0
local camPitch = 0.0

local lastAnprAt = 0
local lastAnprPlate = nil
local lastAnprSentAt = 0

local updateNui

local function notify(msg)
    if lib and lib.notify then
        lib.notify({
            title = 'ANPG',
            description = msg,
            type = 'inform'
        })
        return
    end

    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(msg)
        return
    end

    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

local function toggleRecording()
    recordingOn = not recordingOn
    updateNui({ recording = recordingOn })
    if recordingOn then
        notify('HeliCam: REC')
    else
        notify('HeliCam: NORMAL')
    end
end

local function getVehicleInCamDirection(cam)
    local camCoord = GetCamCoord(cam)
    local camRot = GetCamRot(cam, 2)
    local camDir = RotAnglesToVec(camRot)
    local dest = camCoord + (camDir * Config.Targeting.MaxDistance)

    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, Config.Targeting.RaycastFlags, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)

    if hit == 1 and entityHit and entityHit ~= 0 and IsEntityAVehicle(entityHit) then
        return entityHit, endCoords
    end

    return nil, endCoords
end

local function vehicleModelName(veh)
    local model = GetEntityModel(veh)
    return GetDisplayNameFromVehicleModel(model)
end

local function getVehicleSpeedKmh(veh)
    return math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
end

local function setNui(state, payload)
    SendNUIMessage({
        type = 'state',
        active = state,
        payload = payload or {}
    })
    SetNuiFocus(false, false)
end

updateNui = function(payload)
    SendNUIMessage({
        type = 'update',
        payload = payload or {}
    })
end

local function canUseHeliCam()
    local ped = PlayerPedId()
    if not IsPedInAnyHeli(ped) then
        return false, 'Du skal sidde i en helikopter.'
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        return false, 'Kunne ikke finde helikopter.'
    end

    local model = GetEntityModel(veh)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))
    if not Config.AllowedHelis[modelName] then
        return false, 'Denne helikopter er ikke godkendt til HeliCam.'
    end

    if Config.RequireSeat then
        local seatPed = GetPedInVehicleSeat(veh, -1)
        if seatPed ~= ped then
            return false, 'Du skal være pilot for at bruge HeliCam.'
        end
    end

    if playerJobName == nil then
        return false, 'Kunne ikke læse dit job endnu.'
    end

    if not Config.AllowedJobs[playerJobName] then
        return false, 'HeliCam er kun tilgængelig for politiet.'
    end

    return true
end

local function setVision()
    SetNightvision(nightVisionOn)
    SetSeethrough(thermalOn)
end

local function resetVision()
    nightVisionOn = false
    thermalOn = false
    SetNightvision(false)
    SetSeethrough(false)
end

local function getAltitudeMeters(entity)
    if not entity or entity == 0 then return 0.0 end
    return GetEntityHeightAboveGround(entity)
end

local function stopHeliCam()
    isHeliCamActive = false

    if heliCam then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(heliCam, false)
        heliCam = nil
    end

    lockedEntity = nil
    spotlightOn = false
    recordingOn = false
    if heliEntity and heliEntity ~= 0 then
        SetVehicleSearchlight(heliEntity, false, false)
    end

    resetVision()

    ClearTimecycleModifier()
    SetTimecycleModifierStrength(0.0)

    setNui(false, {})
end

local function startHeliCam()
    local ok, err = canUseHeliCam()
    if not ok then
        notify(err)
        return
    end

    local ped = PlayerPedId()
    heliEntity = GetVehiclePedIsIn(ped, false)

    isHeliCamActive = true

    currentFov = Config.Zoom.MaxFov
    targetFov = currentFov
    camHeading = GetEntityHeading(heliEntity)
    camPitch = -10.0

    heliCam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToEntity(heliCam, heliEntity, 0.0, 0.0, -1.5, true)
    SetCamRot(heliCam, camPitch, 0.0, camHeading, 2)
    SetCamFov(heliCam, currentFov)

    RenderScriptCams(true, true, 250, true, true)

    SetTimecycleModifier('scanline_cam_cheap')
    SetTimecycleModifierStrength(0.75)

    setNui(true, {
        locked = false,
        recording = recordingOn,
        spotlight = spotlightOn,
        nightVision = nightVisionOn,
        thermal = thermalOn,
    })
end

local function toggleLock()
    if lockedEntity and DoesEntityExist(lockedEntity) then
        lockedEntity = nil

        if heliCam then
            StopCamPointing(heliCam)
            local rot = GetCamRot(heliCam, 2)
            camPitch = rot.x
            camHeading = rot.z
            SetCamRot(heliCam, camPitch, 0.0, camHeading, 2)
        end

        updateNui({ locked = false })
        return
    end

    local ent = nil
    if heliCam then
        ent = select(1, getVehicleInCamDirection(heliCam))
    end

    if ent and DoesEntityExist(ent) then
        lockedEntity = ent
        updateNui({ locked = true })

        if Config and Config.Ownership and Config.Ownership.Enabled and lib and lib.callback then
            local plate = GetVehicleNumberPlateText(ent)
            if plate and plate ~= '' then
                plate = plate:gsub('^%s+', ''):gsub('%s+$', '')
                CreateThread(function()
                    local owner = lib.callback.await('dp_heli_cam:getVehicleOwner', false, plate)
                    if owner and type(owner) == 'table' then
                        local display = owner.name or owner.identifier or 'UKENDT'
                        lib.notify({
                            title = 'ANPG - Ejer',
                            description = ('%s | %s'):format(plate, display),
                            type = 'success'
                        })
                    else
                        lib.notify({
                            title = 'ANPG',
                            description = ('%s | Brugstjålet'):format(plate),
                            type = 'error'
                        })
                    end
                end)
            end
        end
    end
end

local function toggleSpotlight()
    if not heliEntity or heliEntity == 0 then return end
    spotlightOn = not spotlightOn

    if not NetworkHasControlOfEntity(heliEntity) then
        NetworkRequestControlOfEntity(heliEntity)
        local timeout = GetGameTimer() + 500
        while not NetworkHasControlOfEntity(heliEntity) and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    SetVehicleSearchlight(heliEntity, spotlightOn, true)
    updateNui({ spotlight = spotlightOn })
    if spotlightOn then
        notify('Spotlys: tændt')
    else
        notify('Spotlys: slukket')
    end
end

local function drawCustomSpotlight()
    if not Config.Spotlight or not Config.Spotlight.CustomEnabled then return end
    if not heliCam or not heliEntity or heliEntity == 0 then return end

    local offset = Config.Spotlight.Offset or { x = 0.0, y = 2.0, z = -1.2 }
    local from = GetOffsetFromEntityInWorldCoords(heliEntity, offset.x or 0.0, offset.y or 2.0, offset.z or -1.2)

    local camRot = GetCamRot(heliCam, 2)
    local dir = RotAnglesToVec(camRot)

    local color = Config.Spotlight.Color or { r = 235, g = 255, b = 255 }
    local distance = Config.Spotlight.Distance or 350.0
    local brightness = Config.Spotlight.Brightness or 12.0
    local hardness = Config.Spotlight.Hardness or 8.0
    local radius = Config.Spotlight.Radius or 35.0
    local falloff = Config.Spotlight.Falloff or 1.2

    if DrawSpotLightWithShadow then
        DrawSpotLightWithShadow(
            from.x, from.y, from.z,
            dir.x, dir.y, dir.z,
            color.r or 235, color.g or 255, color.b or 255,
            distance,
            brightness,
            hardness,
            radius,
            falloff,
            1
        )
    else
        DrawSpotLight(
            from.x, from.y, from.z,
            dir.x, dir.y, dir.z,
            color.r or 235, color.g or 255, color.b or 255,
            distance,
            brightness,
            radius,
            falloff
        )
    end
end

local function toggleNightVision()
    nightVisionOn = not nightVisionOn
    if nightVisionOn then
        thermalOn = false
    end
    setVision()
    updateNui({ nightVision = nightVisionOn, thermal = thermalOn })
end

local function toggleThermal()
    thermalOn = not thermalOn
    if thermalOn then
        nightVisionOn = false
    end
    setVision()
    updateNui({ nightVision = nightVisionOn, thermal = thermalOn })
end

local function tryCopyPlate()
    if not lockedEntity or not DoesEntityExist(lockedEntity) then
        notify('Ingen låst mål at kopiere nummerplade fra.')
        return
    end

    local plate = GetVehicleNumberPlateText(lockedEntity)
    if not plate or plate == '' then
        notify('Kunne ikke læse nummerplade.')
        return
    end

    if lib and lib.setClipboard then
        lib.setClipboard(plate)
        notify('Nummerplade kopieret: ' .. plate)
        return
    end

    SendNUIMessage({ type = 'copyPlate', plate = plate })
    notify('Nummerplade kopieret: ' .. plate)
end

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(250)
    end

    local data = ESX.GetPlayerData()
    if data and data.job then
        playerJobName = data.job.name
    end
end)

RegisterNetEvent('esx:setJob', function(job)
    if job and job.name then
        playerJobName = job.name
    end
end)

RegisterNetEvent('dp_heli_cam:anprReceive', function(payload)
    if type(payload) ~= 'table' then return end
    if playerJobName ~= 'police' then return end

    local plate = payload.plate or 'UKENDT'
    local model = payload.model or 'UKENDT'
    local speed = payload.speed or 0

    local msg = ('ANPR: %s (%s) %s km/t'):format(plate, model, speed)

    notify(msg)
end)

RegisterCommand('helicam', function()
    if isHeliCamActive then
        stopHeliCam()
    else
        startHeliCam()
    end
end, false)

RegisterCommand('helicam_exit', function()
    if not isHeliCamActive then return end
    stopHeliCam()
end, false)

RegisterCommand('helicam_lock', function()
    if not isHeliCamActive then return end
    toggleLock()
end, false)

RegisterCommand('helicam_spotlight', function()
    if not isHeliCamActive then return end
    toggleSpotlight()
end, false)

RegisterCommand('helicam_rec', function()
    if not isHeliCamActive then return end
    toggleRecording()
end, false)

RegisterCommand('helicam_nightvision', function()
    if not isHeliCamActive then return end
    toggleNightVision()
end, false)

RegisterCommand('helicam_thermal', function()
    if not isHeliCamActive then return end
    toggleThermal()
end, false)

RegisterCommand('helicam_copyplate', function()
    if not isHeliCamActive then return end
    tryCopyPlate()
end, false)

RegisterKeyMapping('helicam', 'HeliCam: Tænd/Sluk', 'keyboard', 'h')
RegisterKeyMapping('helicam_exit', 'HeliCam: Luk', 'keyboard', 'back')
RegisterKeyMapping('helicam_lock', 'HeliCam: Lås mål', 'keyboard', 'e')
RegisterKeyMapping('helicam_spotlight', 'HeliCam: Spotlight', 'keyboard', 'g')

RegisterKeyMapping('helicam_rec', 'Kamera: REC/NORMAL', 'keyboard', 'r')
RegisterKeyMapping('helicam_nightvision', 'HeliCam: Nightvision', 'keyboard', 'n')
RegisterKeyMapping('helicam_thermal', 'HeliCam: Thermal', 'keyboard', 'l')
RegisterKeyMapping('helicam_copyplate', 'HeliCam: Kopier nummerplade', 'keyboard', 'k')

CreateThread(function()
    while true do
        Wait(0)

        if not isHeliCamActive then
            goto continue
        end

        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 68, true)
        DisableControlAction(0, 69, true)
        DisableControlAction(0, 70, true)
        DisableControlAction(0, 91, true)
        DisableControlAction(0, 92, true)
        DisableControlAction(0, 99, true)
        DisableControlAction(0, 100, true)

        if not IsPedInAnyHeli(PlayerPedId()) then
            stopHeliCam()
            goto continue
        end

        heliEntity = GetVehiclePedIsIn(PlayerPedId(), false)

        local lookX = GetDisabledControlNormal(0, 1)
        local lookY = GetDisabledControlNormal(0, 2)

        camHeading = camHeading - (lookX * Config.Look.SpeedMouse)
        camPitch = camPitch - (lookY * Config.Look.SpeedMouse)
        camPitch = math.max(Config.Look.MinPitch, math.min(Config.Look.MaxPitch, camPitch))

        if IsControlPressed(0, 15) then
            targetFov = math.max(Config.Zoom.MinFov, targetFov - Config.Zoom.Step)
        end
        if IsControlPressed(0, 14) then
            targetFov = math.min(Config.Zoom.MaxFov, targetFov + Config.Zoom.Step)
        end

        currentFov = currentFov + ((targetFov - currentFov) * (1.0 / Config.Zoom.Smooth))

        if heliCam then
            if spotlightOn then
                drawCustomSpotlight()
            end

            if lockedEntity and DoesEntityExist(lockedEntity) then
                local heliPos = GetEntityCoords(heliEntity)
                local tgtPos = GetEntityCoords(lockedEntity)
                local dist = #(heliPos - tgtPos)

                if dist > Config.Targeting.LockBreakDistance then
                    lockedEntity = nil
                    updateNui({ locked = false })
                else
                    PointCamAtEntity(heliCam, lockedEntity, 0.0, 0.0, 0.0, true)
                end
            else
                SetCamRot(heliCam, camPitch, 0.0, camHeading, 2)
            end

            SetCamFov(heliCam, currentFov)

            local hitVeh = select(1, getVehicleInCamDirection(heliCam))
            local target = lockedEntity or hitVeh

            local heliCoords = GetEntityCoords(heliEntity)
            local alt = getAltitudeMeters(heliEntity)
            local hdg = GetEntityHeading(heliEntity)

            local payload = {
                alt = alt,
                hdg = hdg,
                gpsX = heliCoords.x,
                gpsY = heliCoords.y,
                fov = currentFov,
                recording = recordingOn,
                spotlight = spotlightOn,
                nightVision = nightVisionOn,
                thermal = thermalOn,
            }

            if target and DoesEntityExist(target) then
                payload.hasTarget = true
                payload.locked = (lockedEntity ~= nil)
                payload.plate = GetVehicleNumberPlateText(target)
                payload.model = vehicleModelName(target)
                payload.speed = getVehicleSpeedKmh(target)
                payload.dist = #(heliCoords - GetEntityCoords(target))
            else
                payload.hasTarget = false
                payload.locked = (lockedEntity ~= nil)
                payload.plate = nil
                payload.model = nil
                payload.speed = nil
                payload.dist = nil
            end

            updateNui(payload)

            if Config.ANPR and Config.ANPR.Enabled then
                local now = GetGameTimer()
                if (now - lastAnprAt) >= (Config.ANPR.IntervalMs or 2500) then
                    lastAnprAt = now

                    local anprTarget = nil
                    if Config.ANPR.OnlyWhenLocked then
                        anprTarget = lockedEntity
                    else
                        anprTarget = target
                    end

                    if anprTarget and DoesEntityExist(anprTarget) then
                        local plate = GetVehicleNumberPlateText(anprTarget)
                        local canSend = true

                        if lastAnprPlate == plate then
                            if (now - (lastAnprSentAt or 0)) < (Config.ANPR.CooldownMs or 8000) then
                                canSend = false
                            end
                        end

                        if canSend then
                            lastAnprPlate = plate
                            lastAnprSentAt = now

                            local tgtCoords = GetEntityCoords(anprTarget)
                            TriggerServerEvent('dp_heli_cam:anprPing', {
                                plate = plate,
                                model = vehicleModelName(anprTarget),
                                speed = getVehicleSpeedKmh(anprTarget),
                                gpsX = tgtCoords.x,
                                gpsY = tgtCoords.y,
                                dist = #(heliCoords - tgtCoords),
                                time = now,
                            })
                        end
                    end
                end
            end
        end

        ::continue::
    end
end)

RegisterNUICallback('close', function(_, cb)
    if isHeliCamActive then
        stopHeliCam()
    end
    cb('ok')
end)

function RotAnglesToVec(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))

    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end
