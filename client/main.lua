local QBCore = exports['qb-core'] and exports['qb-core']:GetCoreObject() or nil
local isSelectingProp = false
local currentStashes = {}
local activeTargetZones = {}
local activePoints = {}

-- Meslek ve Yetki Kontrolü
local function CheckJobAccess(jobName, minGrade)
    if not jobName or jobName == '' or jobName == 'none' then
        return true
    end

    if QBCore then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData and PlayerData.job then
            if PlayerData.job.name == jobName then
                if minGrade and tonumber(minGrade) > 0 then
                    return (PlayerData.job.grade.level or 0) >= tonumber(minGrade)
                end
                return true
            end
        end
    end

    return false
end

-- Kasayı Açma Fonksiyonu
local function OpenStash(stash)
    if stash.job and stash.job ~= '' and stash.job ~= 'none' then
        if not CheckJobAccess(stash.job, stash.grade) then
            return lib.notify({ type = 'error', description = Config.Locales['no_job_access'] })
        end
    end

    if stash.pin_code and stash.pin_code ~= '' then
        local input = lib.inputDialog(Config.Locales['pin_prompt_title'], {
            {
                type = 'input',
                label = Config.Locales['pin_prompt_desc'],
                password = true,
                required = true
            }
        })

        if not input or input[1] ~= tostring(stash.pin_code) then
            return lib.notify({ type = 'error', description = Config.Locales['wrong_pin'] })
        end
    end

    exports.ox_inventory:openInventory('stash', stash.stash_id)
end

-- Tüm Target Alanlarını Temizle
local function ClearAllTargets()
    for zoneName, zoneId in pairs(activeTargetZones) do
        if GetResourceState('ox_target') == 'started' then
            pcall(function()
                if type(zoneId) == 'number' or type(zoneId) == 'string' then
                    exports.ox_target:removeZone(zoneId)
                else
                    exports.ox_target:removeZone(zoneName)
                end
            end)
        elseif GetResourceState('qb-target') == 'started' then
            pcall(function()
                exports['qb-target']:RemoveZone(zoneName)
            end)
        end
    end
    activeTargetZones = {}

    for _, point in pairs(activePoints) do
        if point and point.remove then
            point:remove()
        end
    end
    activePoints = {}
end

-- Target ve Point Kurulumu
local function SetupStashTargets(stashes)
    ClearAllTargets()
    if not stashes then return end

    local hasOxTarget = GetResourceState('ox_target') == 'started'
    local hasQbTarget = GetResourceState('qb-target') == 'started'

    for stashId, stash in pairs(stashes) do
        local coords = nil
        if type(stash.coords) == 'string' then
            local decoded = json.decode(stash.coords)
            if decoded then
                coords = vec3(decoded.x, decoded.y, decoded.z)
            end
        elseif type(stash.coords) == 'vector3' or type(stash.coords) == 'table' then
            coords = vec3(stash.coords.x, stash.coords.y, stash.coords.z)
        end

        if coords then
            local zoneName = 'ox_stash_' .. tostring(stash.id or stash.stash_id)
            local heading = tonumber(stash.heading) or 0.0
            local distance = tonumber(stash.distance) or Config.Defaults.distance

            -- 1. ox_target Desteği (Öncelikli)
            if hasOxTarget then
                local zoneId = exports.ox_target:addBoxZone({
                    coords = coords,
                    size = vec3(1.2, 1.2, 1.5),
                    rotation = heading,
                    debug = false,
                    options = {
                        {
                            name = zoneName,
                            icon = 'fas fa-box-archive',
                            label = (Config.Locales['open_stash_target']):format(stash.label or 'Kasa'),
                            onSelect = function()
                                OpenStash(stash)
                            end,
                            distance = distance
                        }
                    }
                })
                activeTargetZones[zoneName] = zoneId or zoneName
            -- 2. qb-target Desteği (Yalnızca qb-target çalışıyorsa)
            elseif hasQbTarget then
                exports['qb-target']:AddBoxZone(zoneName, coords, 1.2, 1.2, {
                    name = zoneName,
                    heading = heading,
                    debugPoly = false,
                    minZ = coords.z - 1.0,
                    maxZ = coords.z + 1.2,
                }, {
                    options = {
                        {
                            type = 'client',
                            icon = 'fas fa-box-archive',
                            label = (Config.Locales['open_stash_target']):format(stash.label or 'Kasa'),
                            action = function()
                                OpenStash(stash)
                            end
                        }
                    },
                    distance = distance
                })
                activeTargetZones[zoneName] = true
            -- 3. ox_lib Point Fallback (Target sistemi yoksa [E] tuşu ile)
            else
                local point = lib.points.new({
                    coords = coords,
                    distance = distance + 0.5,
                    onEnter = function()
                        lib.showTextUI(('[E] - %s'):format(stash.label or 'Kasa Aç'))
                    end,
                    onExit = function()
                        lib.hideTextUI()
                    end,
                    nearby = function()
                        if IsControlJustPressed(0, 38) then -- E tuşu
                            OpenStash(stash)
                        end
                    end
                })
                table.insert(activePoints, point)
            end
        end
    end
end

-- Sunucudan Senkronizasyon Eventi
RegisterNetEvent('ox_stashcreator:client:syncStashes', function(stashes)
    currentStashes = stashes or {}
    SetupStashTargets(currentStashes)
end)

-- İlk Yükleme
CreateThread(function()
    Wait(1500)
    local stashes = lib.callback.await('ox_stashcreator:server:getStashes', false)
    if stashes then
        currentStashes = stashes
        SetupStashTargets(currentStashes)
    end
end)

-- Kasa Oluşturma Formu
local function OpenStashCreationDialog(propData)
    local randomId = 'stash_' .. tostring(math.random(1000, 9999))

    local input = lib.inputDialog(Config.Locales['dialog_title'], {
        {
            type = 'input',
            label = Config.Locales['stash_id_label'],
            description = Config.Locales['stash_id_desc'],
            default = randomId,
            required = true
        },
        {
            type = 'input',
            label = Config.Locales['stash_label'],
            description = Config.Locales['stash_label_desc'],
            default = 'Kasa',
            required = true
        },
        {
            type = 'number',
            label = Config.Locales['slots_label'],
            description = Config.Locales['slots_desc'],
            default = Config.Defaults.slots,
            min = 1,
            max = 500,
            required = true
        },
        {
            type = 'number',
            label = Config.Locales['weight_label'],
            description = Config.Locales['weight_desc'],
            default = Config.Defaults.weight,
            min = 1,
            max = 50000,
            required = true
        },
        {
            type = 'input',
            label = Config.Locales['job_label'],
            description = Config.Locales['job_desc'],
            placeholder = 'police, ambulance veya boş'
        },
        {
            type = 'number',
            label = Config.Locales['grade_label'],
            description = Config.Locales['grade_desc'],
            default = 0,
            min = 0,
            max = 100
        },
        {
            type = 'checkbox',
            label = Config.Locales['personal_label'],
            description = Config.Locales['personal_desc'],
            checked = false
        },
        {
            type = 'input',
            label = Config.Locales['pincode_label'],
            description = Config.Locales['pincode_desc'],
            password = false,
            placeholder = 'Örn: 1234 (Boş bırakılabilir)'
        },
        {
            type = 'number',
            label = Config.Locales['distance_label'],
            description = Config.Locales['distance_desc'],
            default = Config.Defaults.distance,
            min = 1,
            max = 10
        }
    })

    if not input then
        return lib.notify({ type = 'error', description = Config.Locales['raycast_canceled'] })
    end

    local stashData = {
        stash_id = input[1],
        label = input[2],
        slots = tonumber(input[3]) or Config.Defaults.slots,
        weight = tonumber(input[4]) or Config.Defaults.weight,
        job = input[5] ~= '' and input[5] or nil,
        grade = tonumber(input[6]) or 0,
        is_personal = input[7] == true,
        pin_code = input[8] ~= '' and input[8] or nil,
        distance = tonumber(input[9]) or Config.Defaults.distance,
        coords = propData.coords,
        heading = propData.heading,
        model = propData.model
    }

    TriggerServerEvent('ox_stashcreator:server:createStash', stashData)
end

-- ox_doorlock Usulü Raycast / Prop Hedefleme Modu
local function StartPropRaycast()
    if isSelectingProp then return end
    isSelectingProp = true

    CreateThread(function()
        local lastEntity = 0

        lib.showTextUI(Config.Locales['raycast_textui'], {
            position = 'top-center',
            icon = 'crosshairs'
        })

        while isSelectingProp do
            Wait(0)
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, 24, true)  -- Sol Tık (Attack)
            DisableControlAction(0, 25, true)  -- Sağ Tık (Aim)
            DisableControlAction(0, 38, true)  -- E
            DisableControlAction(0, 200, true) -- ESC
            DisableControlAction(0, 177, true) -- Backspace

            local hit, entity, coords = lib.raycast.cam(1 | 16)
            local changedEntity = lastEntity ~= entity

            if changedEntity and lastEntity ~= 0 and DoesEntityExist(lastEntity) then
                SetEntityDrawOutline(lastEntity, false)
            end
            lastEntity = entity

            -- Nokta Çizimi (Marker)
            if hit and coords then
                DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.2, 0.2, 0.2,
                    255, 42, 24, 100,
                    false, false, 0, true, false, false, false
                )
            end

            -- Obje / Prop Algılama
            local isValidEntity = hit and entity > 0 and DoesEntityExist(entity)
            if isValidEntity then
                local entityType = GetEntityType(entity)
                if entityType == 3 or entityType == 1 or entityType == 2 then
                    if changedEntity then
                        SetEntityDrawOutline(entity, true)
                    end

                    -- Sol Tık veya E ile Seçim
                    if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 38) then
                        SetEntityDrawOutline(entity, false)
                        isSelectingProp = false
                        lib.hideTextUI()

                        local targetCoords = coords
                        local targetHeading = 0.0
                        local modelName = 'custom_prop'

                        local successCoords, entCoords = pcall(GetEntityCoords, entity)
                        if successCoords and entCoords then targetCoords = entCoords end

                        local successHeading, entHeading = pcall(GetEntityHeading, entity)
                        if successHeading and entHeading then targetHeading = math.floor(entHeading + 0.5) end

                        local successModel, entModel = pcall(GetEntityModel, entity)
                        if successModel and entModel then modelName = tostring(entModel) end

                        lib.notify({
                            type = 'inform',
                            description = (Config.Locales['prop_selected']):format(modelName)
                        })

                        OpenStashCreationDialog({
                            coords = targetCoords,
                            heading = targetHeading,
                            model = modelName
                        })
                        return
                    end
                end
            elseif hit and coords then
                -- Entity olmadan sadece yüzeye tıklanırsa (fallback)
                if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 38) then
                    isSelectingProp = false
                    lib.hideTextUI()

                    lib.notify({
                        type = 'inform',
                        description = (Config.Locales['prop_selected']):format('Konum')
                    })

                    OpenStashCreationDialog({
                        coords = coords,
                        heading = 0.0,
                        model = 'custom_coords'
                    })
                    return
                end
            end

            -- Sağ Tık, ESC veya Backspace ile İptal
            if IsDisabledControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) then
                if entity > 0 and DoesEntityExist(entity) then
                    SetEntityDrawOutline(entity, false)
                end
                if lastEntity > 0 and DoesEntityExist(lastEntity) then
                    SetEntityDrawOutline(lastEntity, false)
                end
                isSelectingProp = false
                lib.hideTextUI()
                lib.notify({ type = 'error', description = Config.Locales['raycast_canceled'] })
                return
            end
        end
    end)
end

-- Kasa Düzenleme Formu
local function OpenEditStashDialog(stash)
    local weightInKg = math.floor((stash.weight or 100000) / 1000)
    if weightInKg <= 0 then weightInKg = stash.weight end

    local input = lib.inputDialog(('✏️ %s Düzenle'):format(stash.label or stash.stash_id), {
        {
            type = 'input',
            label = Config.Locales['stash_label'],
            default = stash.label,
            required = true
        },
        {
            type = 'number',
            label = Config.Locales['slots_label'],
            default = stash.slots,
            min = 1,
            max = 500,
            required = true
        },
        {
            type = 'number',
            label = Config.Locales['weight_label'],
            default = weightInKg,
            min = 1,
            max = 50000,
            required = true
        },
        {
            type = 'input',
            label = Config.Locales['job_label'],
            default = stash.job or '',
            placeholder = 'police, ambulance veya boş'
        },
        {
            type = 'number',
            label = Config.Locales['grade_label'],
            default = stash.grade or 0,
            min = 0,
            max = 100
        },
        {
            type = 'checkbox',
            label = Config.Locales['personal_label'],
            checked = stash.is_personal == 1 or stash.is_personal == true
        },
        {
            type = 'input',
            label = Config.Locales['pincode_label'],
            default = stash.pin_code or '',
            placeholder = 'Boş = Şifresiz'
        },
        {
            type = 'number',
            label = Config.Locales['distance_label'],
            default = stash.distance or Config.Defaults.distance,
            min = 1,
            max = 10
        }
    })

    if not input then return end

    local updatedData = {
        label = input[1],
        slots = tonumber(input[2]),
        weight = tonumber(input[3]),
        job = input[4] ~= '' and input[4] or nil,
        grade = tonumber(input[5]) or 0,
        is_personal = input[6] == true,
        pin_code = input[7] ~= '' and input[7] or nil,
        distance = tonumber(input[8]) or Config.Defaults.distance
    }

    TriggerServerEvent('ox_stashcreator:server:updateStash', stash.stash_id, updatedData)
end

-- Kasa Detay Alt Menüsü
local function OpenStashDetailsMenu(stash)
    local weightInKg = math.floor((stash.weight or 100000) / 1000)
    if weightInKg <= 0 then weightInKg = stash.weight end

    local jobText = (stash.job and stash.job ~= '') and (stash.job .. ' (Rütbe: ' .. (stash.grade or 0) .. '+)') or 'Herkese Açık'
    local personalText = (stash.is_personal == 1 or stash.is_personal == true) and 'Evet' or 'Hayır'
    local pinText = (stash.pin_code and stash.pin_code ~= '') and 'Aktif (Korumalı)' or 'Yok (Şifresiz)'

    lib.registerContext({
        id = 'stash_details_menu',
        title = ('📦 %s'):format(stash.label or stash.stash_id),
        menu = 'stashes_list_menu',
        options = {
            {
                title = 'Kasa Bilgileri',
                description = (Config.Locales['stash_info']):format(
                    stash.stash_id,
                    stash.slots,
                    weightInKg,
                    jobText,
                    personalText,
                    pinText
                ),
                icon = 'info-circle',
                disabled = true
            },
            {
                title = Config.Locales['teleport_to_stash'],
                description = 'Bu kasanın bulunduğu konuma ışınlanın',
                icon = 'map-marker-alt',
                onSelect = function()
                    TriggerServerEvent('ox_stashcreator:server:teleportToStash', stash.stash_id)
                end
            },
            {
                title = Config.Locales['open_stash_admin'],
                description = 'Kasa envanterini doğrudan açıp yönetin',
                icon = 'box-open',
                onSelect = function()
                    exports.ox_inventory:openInventory('stash', stash.stash_id)
                end
            },
            {
                title = Config.Locales['edit_stash'],
                description = 'Slot, ağırlık, isim veya meslek yetkisini değiştirin',
                icon = 'edit',
                onSelect = function()
                    OpenEditStashDialog(stash)
                end
            },
            {
                title = Config.Locales['delete_stash'],
                description = 'Bu kasayı kalıcı olarak silin',
                icon = 'trash',
                colorScheme = 'red',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = Config.Locales['delete_confirm_title'],
                        content = (Config.Locales['delete_confirm_desc']):format(stash.label or stash.stash_id),
                        centered = true,
                        cancel = true
                    })

                    if alert == 'confirm' then
                        TriggerServerEvent('ox_stashcreator:server:deleteStash', stash.stash_id)
                    end
                end
            }
        }
    })
    lib.showContext('stash_details_menu')
end

-- Kayıtlı Kasaları Listeleme Menüsü
local function OpenStashesListMenu()
    local options = {}
    local count = 0

    for stashId, stash in pairs(currentStashes) do
        count = count + 1
        local weightInKg = math.floor((stash.weight or 100000) / 1000)
        if weightInKg <= 0 then weightInKg = stash.weight end

        local desc = ('Slot: %d | Ağırlık: %d KG | Meslek: %s'):format(
            stash.slots or Config.Defaults.slots,
            weightInKg,
            (stash.job and stash.job ~= '') and stash.job or 'Herkes'
        )

        table.insert(options, {
            title = ('[%d] %s (%s)'):format(count, stash.label or stashId, stashId),
            description = desc,
            icon = 'box-archive',
            onSelect = function()
                OpenStashDetailsMenu(stash)
            end
        })
    end

    if #options == 0 then
        table.insert(options, {
            title = 'Kayıtlı Kasa Bulunamadı',
            description = 'Henüz eklenmiş herhangi bir kasa yok.',
            icon = 'exclamation-circle',
            disabled = true
        })
    end

    lib.registerContext({
        id = 'stashes_list_menu',
        title = '📋 Kayıtlı Kasalar',
        menu = 'stash_admin_main_menu',
        options = options
    })
    lib.showContext('stashes_list_menu')
end

-- Ana Admin Menüsü
local function OpenAdminMenu()
    local hasPerm = lib.callback.await('ox_stashcreator:server:checkPermission', false)
    if not hasPerm then
        return lib.notify({ type = 'error', description = Config.Locales['no_permission'] })
    end

    local totalStashes = 0
    for _ in pairs(currentStashes) do totalStashes = totalStashes + 1 end

    lib.registerContext({
        id = 'stash_admin_main_menu',
        title = Config.Locales['menu_title'],
        options = {
            {
                title = Config.Locales['menu_add_stash'],
                description = Config.Locales['menu_add_stash_desc'],
                icon = 'plus-circle',
                iconColor = '#2ecc71',
                onSelect = function()
                    StartPropRaycast()
                end
            },
            {
                title = (Config.Locales['menu_list_stashes']):format(totalStashes),
                description = Config.Locales['menu_list_stashes_desc'],
                icon = 'list-check',
                iconColor = '#3498db',
                onSelect = function()
                    OpenStashesListMenu()
                end
            }
        }
    })
    lib.showContext('stash_admin_main_menu')
end

-- Event Handler'lar
RegisterNetEvent('ox_stashcreator:client:startRaycast', function()
    local hasPerm = lib.callback.await('ox_stashcreator:server:checkPermission', false)
    if not hasPerm then
        return lib.notify({ type = 'error', description = Config.Locales['no_permission'] })
    end
    StartPropRaycast()
end)

RegisterNetEvent('ox_stashcreator:client:openAdminMenu', function()
    OpenAdminMenu()
end)
