local QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
local RegisteredStashes = {}

-- Yetki Kontrolü Fonksiyonu
local function HasAdminPermission(source)
    if source == 0 then return true end
    if IsPlayerAceAllowed(source, Config.CommandPrincipal) or IsPlayerAceAllowed(source, 'command.' .. Config.Commands.addStash) then
        return true
    end

    if QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local permission = QBCore.Functions.GetPermission(source)
            if type(permission) == 'string' and Config.AdminGroups[permission] then
                return true
            elseif type(permission) == 'table' then
                for group, hasGroup in pairs(permission) do
                    if hasGroup and Config.AdminGroups[group] then
                        return true
                    end
                end
            end
            local playerGroup = Player.PlayerData.group
            if playerGroup and Config.AdminGroups[playerGroup] then
                return true
            end
        end
    end

    return false
end

-- ox_inventory'ye Kasayı Kaydetme
local function RegisterStashToInventory(stash)
    local groups = nil
    if stash.job and stash.job ~= '' and stash.job ~= 'none' then
        groups = { [stash.job] = stash.grade or 0 }
    end

    local coords = nil
    if stash.coords then
        if type(stash.coords) == 'string' then
            local decoded = json.decode(stash.coords)
            if decoded then
                coords = vec3(decoded.x, decoded.y, decoded.z)
            end
        elseif type(stash.coords) == 'vector3' or type(stash.coords) == 'table' then
            coords = vec3(stash.coords.x, stash.coords.y, stash.coords.z)
        end
    end

    -- ox_inventory:RegisterStash(name, label, slots, maxWeight, owner, groups, coords)
    -- weight gram cinsinden kaydedilir (KG * 1000)
    local maxWeight = stash.weight
    if maxWeight < 1000 then
        maxWeight = maxWeight * 1000 -- Eğer KG olarak kaydedildiyse grama çevir
    end

    local isPersonal = stash.is_personal == 1 or stash.is_personal == true
    exports.ox_inventory:RegisterStash(
        stash.stash_id,
        stash.label or stash.stash_id,
        stash.slots or Config.Defaults.slots,
        maxWeight,
        isPersonal,
        groups,
        coords
    )
end

-- Veritabanı Tablosunu Oluştur ve Kasaları Yükle
CreateThread(function()
    Wait(500)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `ox_stashes` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `stash_id` VARCHAR(100) NOT NULL UNIQUE,
            `label` VARCHAR(100) NOT NULL,
            `slots` INT(11) NOT NULL DEFAULT 50,
            `weight` INT(11) NOT NULL DEFAULT 100000,
            `model` VARCHAR(100) DEFAULT NULL,
            `coords` LONGTEXT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `job` VARCHAR(50) DEFAULT NULL,
            `grade` INT(11) NOT NULL DEFAULT 0,
            `is_personal` TINYINT(1) NOT NULL DEFAULT 0,
            `pin_code` VARCHAR(50) DEFAULT NULL,
            `distance` FLOAT NOT NULL DEFAULT 2.0,
            `created_by` VARCHAR(100) DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        -- Kayıtlı tüm kasaları veritabanından çek
        local results = MySQL.query.await('SELECT * FROM `ox_stashes`')
        if results and #results > 0 then
            for _, row in ipairs(results) do
                RegisteredStashes[row.stash_id] = row
                RegisterStashToInventory(row)
            end
            print(('[^2ox_stashcreator^7] ^3%d^7 adet kasa basariyla yuklendi ve ox_inventory\'ye kaydedildi.'):format(#results))
        else
            print('^2[ox_stashcreator]^7 Veritabaninda kayitli kasa bulunamadi veya tablo bos.')
        end
    end)
end)

-- Callback: Kasaları İstemciye Gönder
lib.callback.register('ox_stashcreator:server:getStashes', function(source)
    return RegisteredStashes
end)

-- Callback: Yetki Kontrolü
lib.callback.register('ox_stashcreator:server:checkPermission', function(source)
    return HasAdminPermission(source)
end)

-- Event: Yeni Kasa Oluştur
RegisterNetEvent('ox_stashcreator:server:createStash', function(data)
    local src = source
    if not HasAdminPermission(src) then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Locales['no_permission'] })
    end

    if not data.stash_id or not data.label or not data.slots or not data.weight or not data.coords then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Locales['missing_fields'] })
    end

    -- ID çakışması kontrolü
    if RegisteredStashes[data.stash_id] then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Locales['already_exists'] })
    end

    local weightInGrams = tonumber(data.weight) or 100
    if weightInGrams < 1000 then
        weightInGrams = weightInGrams * 1000
    end

    local coordsJson = json.encode({
        x = data.coords.x,
        y = data.coords.y,
        z = data.coords.z
    })

    local creatorName = GetPlayerName(src) or 'Admin'

    local insertId = MySQL.insert.await([[
        INSERT INTO `ox_stashes` (`stash_id`, `label`, `slots`, `weight`, `model`, `coords`, `heading`, `job`, `grade`, `is_personal`, `pin_code`, `distance`, `created_by`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.stash_id,
        data.label,
        tonumber(data.slots) or Config.Defaults.slots,
        weightInGrams,
        tostring(data.model or ''),
        coordsJson,
        tonumber(data.heading) or 0.0,
        (data.job and data.job ~= '' and data.job ~= 'none') and data.job or nil,
        tonumber(data.grade) or 0,
        (data.is_personal and 1 or 0),
        (data.pin_code and data.pin_code ~= '') and data.pin_code or nil,
        tonumber(data.distance) or Config.Defaults.distance,
        creatorName
    })

    if insertId then
        local newStash = {
            id = insertId,
            stash_id = data.stash_id,
            label = data.label,
            slots = tonumber(data.slots) or Config.Defaults.slots,
            weight = weightInGrams,
            model = tostring(data.model or ''),
            coords = coordsJson,
            heading = tonumber(data.heading) or 0.0,
            job = (data.job and data.job ~= '' and data.job ~= 'none') and data.job or nil,
            grade = tonumber(data.grade) or 0,
            is_personal = (data.is_personal and 1 or 0),
            pin_code = (data.pin_code and data.pin_code ~= '') and data.pin_code or nil,
            distance = tonumber(data.distance) or Config.Defaults.distance,
            created_by = creatorName
        }

        RegisteredStashes[data.stash_id] = newStash
        RegisterStashToInventory(newStash)

        -- Tüm istemcilere senkronize et
        TriggerClientEvent('ox_stashcreator:client:syncStashes', -1, RegisteredStashes)
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'success',
            description = (Config.Locales['create_success']):format(data.stash_id)
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = (Config.Locales['create_failed']):format('Veritabani hatasi')
        })
    end
end)

-- Event: Kasa Güncelle
RegisterNetEvent('ox_stashcreator:server:updateStash', function(stashId, data)
    local src = source
    if not HasAdminPermission(src) then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Locales['no_permission'] })
    end

    local existing = RegisteredStashes[stashId]
    if not existing then return end

    local weightInGrams = tonumber(data.weight) or 100
    if weightInGrams < 1000 then
        weightInGrams = weightInGrams * 1000
    end

    MySQL.update.await([[
        UPDATE `ox_stashes`
        SET `label` = ?, `slots` = ?, `weight` = ?, `job` = ?, `grade` = ?, `is_personal` = ?, `pin_code` = ?, `distance` = ?
        WHERE `stash_id` = ?
    ]], {
        data.label or existing.label,
        tonumber(data.slots) or existing.slots,
        weightInGrams,
        (data.job and data.job ~= '' and data.job ~= 'none') and data.job or nil,
        tonumber(data.grade) or 0,
        (data.is_personal and 1 or 0),
        (data.pin_code and data.pin_code ~= '') and data.pin_code or nil,
        tonumber(data.distance) or existing.distance,
        stashId
    })

    existing.label = data.label or existing.label
    existing.slots = tonumber(data.slots) or existing.slots
    existing.weight = weightInGrams
    existing.job = (data.job and data.job ~= '' and data.job ~= 'none') and data.job or nil
    existing.grade = tonumber(data.grade) or 0
    existing.is_personal = (data.is_personal and 1 or 0)
    existing.pin_code = (data.pin_code and data.pin_code ~= '') and data.pin_code or nil
    existing.distance = tonumber(data.distance) or existing.distance

    RegisteredStashes[stashId] = existing
    RegisterStashToInventory(existing)

    TriggerClientEvent('ox_stashcreator:client:syncStashes', -1, RegisteredStashes)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = Config.Locales['update_success'] })
end)

-- Event: Kasa Sil
RegisterNetEvent('ox_stashcreator:server:deleteStash', function(stashId)
    local src = source
    if not HasAdminPermission(src) then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Config.Locales['no_permission'] })
    end

    if not RegisteredStashes[stashId] then return end

    MySQL.query.await('DELETE FROM `ox_stashes` WHERE `stash_id` = ?', { stashId })
    -- İsteğe bağlı olarak ox_inventory tablosundan da eşyaları temizle
    MySQL.query.await('DELETE FROM `ox_inventory` WHERE `name` = ?', { stashId })

    RegisteredStashes[stashId] = nil

    TriggerClientEvent('ox_stashcreator:client:syncStashes', -1, RegisteredStashes)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = Config.Locales['delete_success'] })
end)

-- Event: Kasaya Işınlan
RegisterNetEvent('ox_stashcreator:server:teleportToStash', function(stashId)
    local src = source
    if not HasAdminPermission(src) then return end

    local stash = RegisteredStashes[stashId]
    if not stash or not stash.coords then return end

    local coords = json.decode(stash.coords)
    if coords then
        local ped = GetPlayerPed(src)
        SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.5, false, false, false, false)
    end
end)

-- Komutlar
lib.addCommand(Config.Commands.addStash, {
    help = 'Seçilen prop üzerine ox_inventory kasası oluştur (ox_doorlock stili raycast)',
    restricted = Config.CommandPrincipal
}, function(source)
    TriggerClientEvent('ox_stashcreator:client:startRaycast', source)
end)

lib.addCommand(Config.Commands.stashMenu, {
    help = 'Kasa oluşturma ve yönetim menüsünü aç',
    restricted = Config.CommandPrincipal
}, function(source)
    TriggerClientEvent('ox_stashcreator:client:openAdminMenu', source)
end)

lib.addCommand(Config.Commands.stashAdmin, {
    help = 'Kasa oluşturma ve yönetim menüsünü aç (Alternatif)',
    restricted = Config.CommandPrincipal
}, function(source)
    TriggerClientEvent('ox_stashcreator:client:openAdminMenu', source)
end)

-- QBCore fallback komut desteği
if QBCore then
    QBCore.Commands.Add(Config.Commands.addStash, 'Seçilen prop üzerine kasa oluştur (ox_doorlock stili)', {}, false, function(source)
        TriggerClientEvent('ox_stashcreator:client:startRaycast', source)
    end, 'admin')

    QBCore.Commands.Add(Config.Commands.stashMenu, 'Kasa oluşturma ve yönetim menüsü', {}, false, function(source)
        TriggerClientEvent('ox_stashcreator:client:openAdminMenu', source)
    end, 'admin')
end
