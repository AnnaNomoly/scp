--[[
* high_scores.lua
* Author: AnnaNomoly
* SPDX-License-Identifier: GPL-3.0-or-later
*
* Packet-based high score tracking for SCP. Watches inbound 0x28 action packets
* for skillchain damage added effects and magic burst damage messages.
--]]

require('common');

local high_scores = {};

local SKILLCHAIN_MESSAGE_NAMES = {
    [196] = 'Skillchain',
    [223] = 'Skillchain',
    [288] = 'Light',
    [289] = 'Darkness',
    [290] = 'Gravitation',
    [291] = 'Fragmentation',
    [292] = 'Distortion',
    [293] = 'Fusion',
    [294] = 'Compression',
    [295] = 'Liquefaction',
    [296] = 'Induration',
    [297] = 'Reverberation',
    [298] = 'Transfixion',
    [299] = 'Scission',
    [300] = 'Detonation',
    [301] = 'Impaction',
    [302] = 'Cosmic Elucidation',
    [767] = 'Radiance',
    [768] = 'Umbra',
};

local MAGIC_BURST_DAMAGE_MESSAGES = {
    [252] = true,
    [265] = true,
    [379] = true,
    [650] = true,
    [747] = true,
};

-- Swipe/Lunge-style bursts can use a normal damage message plus the MB flag.
local DIRECT_DAMAGE_MESSAGES = {
    [77]  = true,
    [110] = true,
    [157] = true,
    [185] = true,
    [197] = true,
    [264] = true,
};

local SKILLCHAIN_PROPERTY_BY_EFFECT = {
    [1] = 'Light',
    [2] = 'Darkness',
    [3] = 'Gravitation',
    [4] = 'Fragmentation',
    [5] = 'Distortion',
    [6] = 'Fusion',
    [7] = 'Compression',
    [8] = 'Liquefaction',
    [9] = 'Induration',
    [10] = 'Reverberation',
    [11] = 'Transfixion',
    [12] = 'Scission',
    [13] = 'Detonation',
    [14] = 'Impaction',
    [15] = 'Radiance',
    [16] = 'Umbra',
};

local TRACKED_ACTION_TYPES = {
    [3] = true,  -- Weapon Skill finish
    [4] = true,  -- Spell finish
    [6] = true,  -- Job ability
    [11] = true, -- NPC TP finish
    [13] = true, -- Avatar TP finish
    [14] = true, -- Dancer ability
    [15] = true, -- Rune ability
};

local name_cache = {};
local recent = {};

local function idString(id)
    return string.format('0x%08X', tonumber(id) or 0);
end

local function cleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('%z+$', '');
    if name == '' then return nil end
    return name;
end

local function resourceName(resource)
    if type(resource) ~= 'table' then return nil end
    if type(resource.Name) == 'table' then
        return cleanName(resource.Name[1]) or cleanName(resource.Name[2]);
    end
    return cleanName(resource.Name);
end

local function getResourceName(category, actionId)
    local id = bit.band(tonumber(actionId) or 0, 0xFFFF);
    if id == 0 then return nil end

    local ok, rm = pcall(function ()
        return AshitaCore:GetResourceManager();
    end);
    if (not ok) or (rm == nil) then return nil end

    if category == 4 then
        local success, resource = pcall(function () return rm:GetSpellById(id); end);
        if success then return resourceName(resource); end
    elseif category == 3 then
        local success, resource = pcall(function () return rm:GetAbilityById(id); end);
        if success then return resourceName(resource); end
    elseif category == 6 or category == 14 or category == 15 then
        local success, resource = pcall(function () return rm:GetAbilityById(id + 0x200); end);
        if success then return resourceName(resource); end
    elseif category == 11 or category == 13 then
        if id > 256 then
            local success, name = pcall(function () return rm:GetString('monsters.abilities', id - 256); end);
            if success then
                local cleaned = cleanName(name);
                if cleaned ~= nil then return cleaned; end
            end
        end

        local success, resource = pcall(function () return rm:GetAbilityById(id); end);
        if success then return resourceName(resource); end
    end

    return nil;
end

local function getIndexFromId(id)
    local ok, entMgr = pcall(function ()
        return AshitaCore:GetMemoryManager():GetEntity();
    end);
    if (not ok) or (entMgr == nil) then return 0 end

    if bit.band(id, 0x1000000) ~= 0 then
        local index = bit.band(id, 0xFFF);
        if index >= 0x900 then
            index = index - 0x100;
        end

        if index < 0x900 then
            local success, serverId = pcall(function () return entMgr:GetServerId(index); end);
            if success and serverId == id then
                return index;
            end
        end
    end

    for i = 1, 0x8FF do
        local success, serverId = pcall(function () return entMgr:GetServerId(i); end);
        if success and serverId == id then
            return i;
        end
    end

    return 0;
end

local function entityName(id)
    id = tonumber(id) or 0;
    if id == 0 then return '' end
    if name_cache[id] then return name_cache[id] end

    local ok, party = pcall(function ()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    if ok and party ~= nil then
        for i = 0, 17 do
            local success, serverId = pcall(function () return party:GetMemberServerId(i); end);
            if success and serverId == id then
                local nameOk, name = pcall(function () return party:GetMemberName(i); end);
                name = nameOk and cleanName(tostring(name or '')) or nil;
                if name ~= nil then
                    name_cache[id] = name;
                    return name;
                end
            end
        end
    end

    local index = getIndexFromId(id);
    if index ~= 0 then
        local entOk, entMgr = pcall(function ()
            return AshitaCore:GetMemoryManager():GetEntity();
        end);
        if entOk and entMgr ~= nil then
            local nameOk, name = pcall(function () return entMgr:GetName(index); end);
            name = nameOk and cleanName(tostring(name or '')) or nil;
            if name ~= nil then
                name_cache[id] = name;
                return name;
            end
        end
    end

    local fallback = idString(id);
    name_cache[id] = fallback;
    return fallback;
end

local function isPartyMember(id)
    id = tonumber(id) or 0;
    if id == 0 then return false end

    local ok, party = pcall(function ()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    if (not ok) or (party == nil) then return false end

    for i = 0, 5 do
        local activeOk, active = pcall(function () return party:GetMemberIsActive(i); end);
        if activeOk and active == 1 then
            local idOk, serverId = pcall(function () return party:GetMemberServerId(i); end);
            if idOk and serverId == id then
                return true;
            end
        end
    end

    return false;
end

local function isPartyPet(id)
    id = tonumber(id) or 0;
    if id == 0 then return false end

    local ok, party = pcall(function ()
        return AshitaCore:GetMemoryManager():GetParty();
    end);
    local entOk, entity = pcall(function ()
        return AshitaCore:GetMemoryManager():GetEntity();
    end);
    if (not ok) or (not entOk) or (party == nil) or (entity == nil) then
        return false;
    end

    for i = 0, 5 do
        local activeOk, active = pcall(function () return party:GetMemberIsActive(i); end);
        if activeOk and active == 1 then
            local indexOk, playerIndex = pcall(function () return party:GetMemberTargetIndex(i); end);
            if indexOk then
                local petOk, petIndex = pcall(function () return entity:GetPetTargetIndex(playerIndex); end);
                if petOk and petIndex ~= nil and petIndex ~= 0 then
                    local idOk, petId = pcall(function () return entity:GetServerId(petIndex); end);
                    if idOk and petId == id then
                        return true;
                    end
                end
            end
        end
    end

    return false;
end

local function isPartyActor(id)
    return isPartyMember(id) or isPartyPet(id);
end

local function parseActionPacket(e)
    local bitData = e.data_raw;
    local bitOffset = 40;
    local maxLength = (tonumber(e.size) or 0) * 8;
    local malformed = false;

    local function unpackBits(length)
        if (bitOffset + length) > maxLength then
            malformed = true;
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local packet = {
        userId = unpackBits(32),
        targets = {},
    };

    local targetCount = unpackBits(6);
    bitOffset = bitOffset + 4; -- Unknown
    packet.type = unpackBits(4);
    packet.id = unpackBits(32); -- {unknown[15:0], param[15:0]}
    bitOffset = bitOffset + 32; -- Recast / unknown

    for i = 1, targetCount do
        local target = {
            id = unpackBits(32),
            actions = {},
        };
        local actionCount = unpackBits(4);

        for j = 1, actionCount do
            local action = {
                reaction = unpackBits(5),
                animation = unpackBits(12),
                specialEffect = unpackBits(7),
                knockback = unpackBits(3),
                param = unpackBits(17),
                message = unpackBits(10),
                flags = unpackBits(31),
            };

            if unpackBits(1) == 1 then
                action.additionalEffect = {
                    damage = unpackBits(10), -- {effect[3:0], animation[5:0]}
                    param = unpackBits(17),
                    message = unpackBits(10),
                };
            end

            if unpackBits(1) == 1 then
                action.spikesEffect = {
                    damage = unpackBits(10),
                    param = unpackBits(14),
                    message = unpackBits(10),
                };
            end

            target.actions[#target.actions + 1] = action;
        end

        packet.targets[#packet.targets + 1] = target;
    end

    if malformed then return nil end
    return packet;
end

local function resetScore(score, kind)
    for k in pairs(score) do
        score[k] = nil;
    end
    score.kind = kind;
    score.damage = 0;
end

function high_scores.ensure(settings)
    if type(settings.highScores) ~= 'table' then
        settings.highScores = T{};
    end
    local scores = settings.highScores;

    if type(scores.skillchain) ~= 'table' then scores.skillchain = T{}; end
    if type(scores.magicBurst) ~= 'table' then scores.magicBurst = T{}; end

    if type(scores.skillchain.damage) ~= 'number' then resetScore(scores.skillchain, 'skillchain'); end
    if type(scores.magicBurst.damage) ~= 'number' then resetScore(scores.magicBurst, 'magicBurst'); end
    scores.skillchain.kind = 'skillchain';
    scores.magicBurst.kind = 'magicBurst';

    return scores;
end

function high_scores.reset(settings)
    local scores = high_scores.ensure(settings);
    resetScore(scores.skillchain, 'skillchain');
    resetScore(scores.magicBurst, 'magicBurst');
end

local function propertyName(additionalEffect)
    if additionalEffect == nil then return nil end
    return SKILLCHAIN_PROPERTY_BY_EFFECT[bit.band(additionalEffect.damage or 0, 0x3F)];
end

local function isMagicBurst(action)
    if MAGIC_BURST_DAMAGE_MESSAGES[action.message] then
        return true;
    end
    return bit.band(action.flags or 0, 4) == 4 and DIRECT_DAMAGE_MESSAGES[action.message] == true;
end

local function isDuplicate(kind, actorId, targetId, damage, messageId, actionId)
    local now = os.clock();
    for key, when in pairs(recent) do
        if (now - when) > 2.0 then
            recent[key] = nil;
        end
    end

    local key = table.concat({
        kind,
        tostring(actorId or 0),
        tostring(targetId or 0),
        tostring(damage or 0),
        tostring(messageId or 0),
        tostring(actionId or 0),
    }, ':');

    if recent[key] ~= nil and (now - recent[key]) < 0.5 then
        return true;
    end

    recent[key] = now;
    return false;
end

local function setScore(score, kind, damage, name, packet, target, action, actionId)
    resetScore(score, kind);
    score.damage = damage;
    score.name = name;
    score.actorId = packet.userId;
    score.actorName = entityName(packet.userId);
    score.targetId = target.id;
    score.targetName = entityName(target.id);
    score.actionId = actionId;
    score.actionName = getResourceName(packet.type, actionId);
    score.messageId = action.message;
    score.time = os.time();
end

function high_scores.handlePacket(e, settings)
    if e.id ~= 0x28 then return false end

    local ok, packetType = pcall(function ()
        return ashita.bits.unpack_be(e.data_raw, 82, 4);
    end);
    if (not ok) or (not TRACKED_ACTION_TYPES[packetType]) then
        return false;
    end

    local packet = parseActionPacket(e);
    if packet == nil then return false end
    if not isPartyActor(packet.userId) then return false end

    local scores = high_scores.ensure(settings);
    local actionId = bit.band(packet.id or 0, 0xFFFF);
    local changed = false;

    for _, target in ipairs(packet.targets) do
        for _, action in ipairs(target.actions) do
            local add = action.additionalEffect;
            if add ~= nil and SKILLCHAIN_MESSAGE_NAMES[add.message] ~= nil and (add.param or 0) > scores.skillchain.damage then
                if not isDuplicate('skillchain', packet.userId, target.id, add.param, add.message, actionId) then
                    local name = SKILLCHAIN_MESSAGE_NAMES[add.message] or propertyName(add) or 'Skillchain';
                    if name == 'Skillchain' then
                        name = propertyName(add) or name;
                    end
                    setScore(scores.skillchain, 'skillchain', add.param, name, packet, target, action, actionId);
                    scores.skillchain.messageId = add.message;
                    changed = true;
                end
            end

            if isMagicBurst(action) and (action.param or 0) > scores.magicBurst.damage then
                if not isDuplicate('magicBurst', packet.userId, target.id, action.param, action.message, actionId) then
                    setScore(scores.magicBurst, 'magicBurst', action.param, 'Magic Burst', packet, target, action, actionId);
                    changed = true;
                end
            end
        end
    end

    return changed;
end

function high_scores.formatScore(score, empty)
    if type(score) ~= 'table' or (score.damage or 0) <= 0 then
        return empty;
    end

    local label = score.name or 'Unknown';
    if score.kind == 'magicBurst' and score.actionName ~= nil then
        label = score.actionName;
    end

    local at = score.time and os.date('%H:%M:%S', score.time) or '--:--:--';
    return string.format('%d %s | %s -> %s | %s',
        score.damage or 0,
        label,
        score.actorName or idString(score.actorId),
        score.targetName or idString(score.targetId),
        at);
end

return high_scores;
