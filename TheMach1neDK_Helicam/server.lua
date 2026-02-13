local ESX = exports['es_extended']:getSharedObject()

ESX.RegisterServerCallback('dp_heli_cam:getPlayerJob', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(nil)
        return
    end

    cb(xPlayer.job)
end)

if lib and lib.callback then
    lib.callback.register('dp_heli_cam:getVehicleOwner', function(source, plate)
        if not Config or not Config.Ownership or not Config.Ownership.Enabled then
            return nil
        end

        if type(plate) ~= 'string' then
            return nil
        end

        plate = plate:gsub('^%s+', ''):gsub('%s+$', '')
        if plate == '' then
            return nil
        end

        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or not xPlayer.job or xPlayer.job.name ~= 'police' then
            return nil
        end

        local ovTable = Config.Ownership.OwnedVehiclesTable
        local ovPlateCol = Config.Ownership.OwnedVehiclesPlateColumn
        local ovOwnerCol = Config.Ownership.OwnedVehiclesOwnerColumn
        local usersTable = Config.Ownership.UsersTable
        local usersIdCol = Config.Ownership.UsersIdentifierColumn
        local usersFnCol = Config.Ownership.UsersFirstNameColumn
        local usersLnCol = Config.Ownership.UsersLastNameColumn

        local q1 = ('SELECT `%s` AS owner FROM `%s` WHERE `%s` = ? LIMIT 1'):format(ovOwnerCol, ovTable, ovPlateCol)
        local row = MySQL.single.await(q1, { plate })
        if not row or not row.owner or row.owner == '' then
            return nil
        end

        local identifier = row.owner
        local q2 = ('SELECT `%s` AS firstname, `%s` AS lastname FROM `%s` WHERE `%s` = ? LIMIT 1'):format(usersFnCol, usersLnCol, usersTable, usersIdCol)
        local u = MySQL.single.await(q2, { identifier })
        if not u then
            return { identifier = identifier }
        end

        local firstname = tostring(u.firstname or '')
        local lastname = tostring(u.lastname or '')
        local fullname = (firstname .. ' ' .. lastname):gsub('^%s+', ''):gsub('%s+$', '')

        if fullname == '' then
            return { identifier = identifier }
        end

        return { identifier = identifier, name = fullname }
    end)
end

RegisterNetEvent('dp_heli_cam:anprPing', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job or xPlayer.job.name ~= 'police' then
        return
    end

    if Config and Config.Database and Config.Database.LogANPR then
        local identifier = xPlayer.identifier or 'unknown'
        local plate = tostring(payload.plate or '')
        local model = tostring(payload.model or '')
        local speed = tonumber(payload.speed or 0) or 0
        local gpsX = tonumber(payload.gpsX or 0.0) or 0.0
        local gpsY = tonumber(payload.gpsY or 0.0) or 0.0
        local dist = tonumber(payload.dist or 0.0) or 0.0

        pcall(function()
            MySQL.insert('INSERT INTO dp_heli_cam_anpr (officer_identifier, plate, model, speed, gps_x, gps_y, distance) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                identifier,
                plate,
                model,
                speed,
                gpsX,
                gpsY,
                dist
            })
        end)
    end

    local players = {}
    if ESX.GetExtendedPlayers then
        players = ESX.GetExtendedPlayers()
        for i = 1, #players do
            local xp = players[i]
            if xp and xp.source and xp.job and xp.job.name == 'police' then
                TriggerClientEvent('dp_heli_cam:anprReceive', xp.source, payload)
            end
        end
        return
    end

    if ESX.GetPlayers then
        local ids = ESX.GetPlayers()
        for i = 1, #ids do
            local id = ids[i]
            local xp = ESX.GetPlayerFromId(id)
            if xp and xp.job and xp.job.name == 'police' then
                TriggerClientEvent('dp_heli_cam:anprReceive', id, payload)
            end
        end
    end
end)
