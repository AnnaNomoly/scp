--[[
* scp.lua
* Author: AnnaNomoly
* SPDX-License-Identifier: GPL-3.0-or-later
*
* A Level-75-era (through Chains of Promathia) SKILLCHAIN PLANNER for Ashita v4.
*
* Pick a party (job / level / weapon per member), choose which weaponskills each
* member has, and see every skillchain the party can make -- ranked by skillchain
* tier (Lv.3 Light/Darkness > Lv.2 > Lv.1).
*
* This is an offline-first planner with optional on-demand party sync. It reuses
* the data and resonance rules from the "chains" addon (Ivaar / Sippius /
* NerfOnline).
*
* Default ruleset is Horizon; a Retail (CoP) ruleset is selectable.
*
* Command: /scplanner  (also /scp)
*
* NOTE: built without a way to test in-game.  The most likely things to need a
* tweak are ImGui binding details and the best-effort skill data in jobs.lua /
* ws_data.lua.  See README.md.
--]]

addon.name    = 'scp';
addon.author  = 'AnnaNomoly';
addon.version = '1.0.0';
addon.desc    = 'Level-75-era skillchain planner: pick a party, see ranked skillchains.';

require('common');
local chat     = require('chat');
local imgui    = require('imgui');
local settings = require('settings');

-- Ashita can keep required modules around between addon reloads. These module
-- names are local to SCP, so clear them before loading to pick up file edits.
package.loaded['sc_data'] = nil;
package.loaded['ws_data'] = nil;
package.loaded['jobs'] = nil;
package.loaded['engine'] = nil;
package.loaded['high_scores'] = nil;

local sc     = require('sc_data');
local ws     = require('ws_data');
local jobs   = require('jobs');
local engine = require('engine');
local high_scores = require('high_scores');

--=============================================================================
-- Defaults / state
--=============================================================================
local default_settings = T{
    visible   = true,
    ruleset   = 'horizon',   -- 'horizon' | 'retail'
    maxSteps  = 3,           -- 2..5
    minTier   = 1,           -- 1 | 2 | 3
    distinct  = false,       -- one WS per member per chain
    color     = true,
    highScores = T{
        skillchain = T{ kind = 'skillchain', damage = 0 },
        magicBurst = T{ kind = 'magicBurst', damage = 0 },
    },
    party     = T{
        T{ enabled = true,  job = 'SAM', level = 75, weapon = 'Great Katana', relic = false },
        T{ enabled = true,  job = 'DRK', level = 75, weapon = 'Scythe',       relic = false },
        T{ enabled = true,  job = 'WAR', level = 75, weapon = 'Great Axe',    relic = false },
        T{ enabled = false, job = 'NIN', level = 75, weapon = 'Katana',       relic = false },
        T{ enabled = false, job = 'MNK', level = 75, weapon = 'Hand-to-Hand', relic = false },
        T{ enabled = false, job = 'RNG', level = 75, weapon = 'Marksmanship', relic = false },
    },
};

local planner = {
    settings = settings.load(default_settings),
    results  = {},
    summary  = { total = 0, t3 = 0, t2 = 0, t1 = 0 },
    capped   = false,
    dirty    = true,
};

local MAX_DISPLAY = 250;  -- cap rendered rows to keep the UI responsive

--=============================================================================
-- Small helpers
--=============================================================================
local function markDirty()
    planner.dirty = true;
end

local normalizeParty;

-- Debounced save: avoid hammering the disk while dragging sliders or spamming
-- toggles. The actual settings.save() is flushed from the present handler.
local function persist()
    planner.saveAt = os.clock() + 0.75;
end

local PREFERRED_WEAPON = {
    WAR = 'Great Axe',
    MNK = 'Hand-to-Hand',
    WHM = 'Club',
    BLM = 'Staff',
    RDM = 'Sword',
    THF = 'Dagger',
    PLD = 'Sword',
    DRK = 'Scythe',
    BST = 'Axe',
    BRD = 'Dagger',
    RNG = 'Marksmanship',
    SMN = 'Staff',
    SAM = 'Great Katana',
    NIN = 'Katana',
    DRG = 'Polearm',
};

-- "Best" weapon for a job = the one with the highest skill grade (A over B...).
local function bestWeapon(job)
    local preferred = PREFERRED_WEAPON[job];
    if preferred ~= nil and jobs.gradeFor(job, preferred) then
        return preferred;
    end

    local usable = jobs.usableWeapons(job);
    local best, bestRank = nil, nil;
    for _, wt in ipairs(usable) do
        local g = jobs.gradeFor(job, wt);
        if g and (bestRank == nil or g < bestRank) then  -- 'A' < 'B' lexically
            best, bestRank = wt, g;
        end
    end
    return best or (usable[1]);
end

-- (Re)derive the auto-suggested weaponskill selection for a member from its
-- job / level / weapon (non-relic WS only; relic is controlled separately).
local function deriveSelected(m)
    m.selected = T{};
    local list = ws.weapons[m.weapon];
    if not list then return end
    for _, e in ipairs(list) do
        if not e.relic then
            m.selected[e.name] = jobs.canLearn(m.job, m.level, m.weapon, e) and true or false;
        end
    end
end

local function setAllSelected(m, value)
    m.selected = m.selected or T{};
    local list = ws.weapons[m.weapon];
    if not list then return end
    for _, e in ipairs(list) do
        if not e.relic then m.selected[e.name] = value and true or false; end
    end
end

local function setJob(m, job)
    if m.job == job then return end
    m.job = job;
    if not jobs.gradeFor(job, m.weapon) then
        m.weapon = bestWeapon(job);
    end
    deriveSelected(m);
    markDirty();
end

local function setWeapon(m, weapon)
    if m.weapon == weapon then return end
    m.weapon = weapon;
    deriveSelected(m);
    markDirty();
end

local JOB_ID_TO_ABBR = {
    [1] = 'WAR',
    [2] = 'MNK',
    [3] = 'WHM',
    [4] = 'BLM',
    [5] = 'RDM',
    [6] = 'THF',
    [7] = 'PLD',
    [8] = 'DRK',
    [9] = 'BST',
    [10] = 'BRD',
    [11] = 'RNG',
    [12] = 'SAM',
    [13] = 'NIN',
    [14] = 'DRG',
    [15] = 'SMN',
};

local function jobFromId(jobId)
    return JOB_ID_TO_ABBR[tonumber(jobId) or 0];
end

local function clampLevel(level)
    return math.max(1, math.min(75, math.floor(tonumber(level) or 75)));
end

local function setValue(t, k, v)
    if t[k] == v then return false end
    t[k] = v;
    return true;
end

local function readPartySnapshot()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if party == nil then
        return nil, 'party manager unavailable';
    end

    local snapshot = T{};

    for slot = 0, 5 do
        local active = party:GetMemberIsActive(slot) == 1;
        local serverId = tonumber(party:GetMemberServerId(slot)) or 0;
        local job = active and jobFromId(party:GetMemberMainJob(slot)) or nil;
        local name = active and tostring(party:GetMemberName(slot) or '') or '';

        snapshot[slot + 1] = {
            active = active and serverId ~= 0 and job ~= nil,
            serverId = serverId,
            name = name,
            job = job,
            level = active and clampLevel(party:GetMemberMainJobLevel(slot)) or 75,
        };
    end

    return snapshot;
end

local function applyPartySnapshot(snapshot)
    normalizeParty();

    local synced = 0;
    local changed = false;

    for i = 1, 6 do
        local row = snapshot[i];
        local m = planner.settings.party[i];

        if row and row.active then
            synced = synced + 1;
            local needsSelected = false;

            changed = setValue(m, 'enabled', true) or changed;
            changed = setValue(m, 'name', row.name) or changed;
            if m.serverId ~= row.serverId then
                m.serverId = row.serverId;
                changed = true;
                needsSelected = true;
            end

            if m.job ~= row.job then
                m.job = row.job;
                changed = true;
                needsSelected = true;
            end

            if m.level ~= row.level then
                m.level = row.level;
                changed = true;
                needsSelected = true;
            end

            local weapon = bestWeapon(m.job);
            if weapon ~= nil and m.weapon ~= weapon then
                m.weapon = weapon;
                changed = true;
                needsSelected = true;
            end

            if type(m.selected) ~= 'table' or needsSelected then
                deriveSelected(m);
                changed = true;
            end
        else
            changed = setValue(m, 'enabled', false) or changed;
            changed = setValue(m, 'name', '') or changed;
            changed = setValue(m, 'serverId', 0) or changed;
        end
    end

    return synced, changed;
end

local function syncPartyFromGame(silent)
    local success, snapshot, err = pcall(readPartySnapshot);
    if (not success) or snapshot == nil then
        print(chat.header(addon.name):append(chat.error(
            'Party sync failed: ' .. tostring(success and err or snapshot))));
        return false;
    end

    local synced, changed = applyPartySnapshot(snapshot);
    if changed then
        markDirty();
        persist();
    end

    if not silent then
        print(chat.header(addon.name):append(chat.message(
            ('Synced %d current party member%s.'):fmt(
                synced, synced == 1 and '' or 's'))));
    end

    return true;
end

-- Return the relic WS entry for a weapon (or nil).
local function relicEntry(weapon)
    local list = ws.weapons[weapon];
    if not list then return nil end
    for _, e in ipairs(list) do
        if e.relic then return e end
    end
    return nil;
end

-- Ensure the loaded party is structurally sane.
normalizeParty = function()
    planner.settings.live = nil;
    high_scores.ensure(planner.settings);
    planner.settings.party = planner.settings.party or T{};
    local p = planner.settings.party;
    for i = 1, 6 do
        local m = p[i];
        if type(m) ~= 'table' then m = T{}; p[i] = m; end
        if m.enabled == nil then m.enabled = false; end
        if type(m.job) ~= 'string' or not jobs.grades[m.job] then m.job = 'WAR'; end
        if type(m.level) ~= 'number' then m.level = 75; end
        m.level = math.max(1, math.min(75, math.floor(m.level)));
        if type(m.weapon) ~= 'string' or not jobs.gradeFor(m.job, m.weapon) then
            m.weapon = bestWeapon(m.job);
        end
        if m.relic == nil then m.relic = false; end
        if type(m.name) ~= 'string' then m.name = ''; end
        if type(m.serverId) ~= 'number' then m.serverId = tonumber(m.serverId) or 0; end
        m.autoWeapon = nil;
        m.source = nil;
        m.weaponSource = nil;
        m.wsSource = nil;
        if type(m.selected) ~= 'table' then deriveSelected(m); end
    end
end

--=============================================================================
-- Recompute the chain list from the current party + filters.
--=============================================================================
local function recompute()
    local ruleset = planner.settings.ruleset;
    local moves = {};
    for i = 1, 6 do
        local m = planner.settings.party[i];
        if m and m.enabled and m.weapon and ws.weapons[m.weapon] then
            local displayName = (type(m.name) == 'string' and m.name ~= '') and m.name or ('P%d'):fmt(i);
            local label = ('%s %s'):fmt(displayName, m.job);
            for _, e in ipairs(ws.weapons[m.weapon]) do
                local include;
                if e.relic then include = m.relic; else include = m.selected and m.selected[e.name]; end
                if include then
                    moves[#moves + 1] = {
                        member = i,
                        label  = label,
                        name   = e.name,
                        props  = ws.propsFor(e, ruleset),
                    };
                end
            end
        end
    end

    local results, capped = engine.findChains(moves, {
        maxSteps        = planner.settings.maxSteps,
        minTier         = planner.settings.minTier,
        distinctMembers = planner.settings.distinct,
    });

    local s = { total = #results, t3 = 0, t2 = 0, t1 = 0 };
    for _, r in ipairs(results) do
        if r.finalTier >= 3 then s.t3 = s.t3 + 1;
        elseif r.finalTier == 2 then s.t2 = s.t2 + 1;
        else s.t1 = s.t1 + 1; end
    end

    planner.results = results;
    planner.summary = s;
    planner.capped  = capped;
    planner.dirty   = false;
end

--=============================================================================
-- UI helpers
--=============================================================================
-- Simple string combo. Returns (changed, newValue).
local function comboString(label, current, options)
    local changed, result = false, current;
    if imgui.BeginCombo(label, current, 0) then
        for _, opt in ipairs(options) do
            local isSel = (opt == current);
            if imgui.Selectable(opt, isSel) then
                result = opt; changed = true;
            end
        end
        imgui.EndCombo();
    end
    return changed, result;
end

local function colorFor(name)
    if planner.settings.color then return sc.color(name); end
    return { 1.0, 1.0, 1.0, 1.0 };
end

local DIM = { 0.6, 0.6, 0.6, 1.0 };
local function textDim(s)
    imgui.TextColored(DIM, s);
end

local function renderHighScores()
    local scores = high_scores.ensure(planner.settings);
    imgui.Text('High Scores');
    imgui.SameLine();
    if imgui.SmallButton('Reset Scores') then
        high_scores.reset(planner.settings);
        persist();
    end

    imgui.Text('Skillchain:');
    imgui.SameLine();
    if (scores.skillchain.damage or 0) > 0 then
        imgui.TextColored(colorFor(scores.skillchain.name), high_scores.formatScore(scores.skillchain, 'none yet'));
    else
        textDim('none yet');
    end

    imgui.Text('Magic Burst:');
    imgui.SameLine();
    if (scores.magicBurst.damage or 0) > 0 then
        imgui.TextColored({ 0.7, 0.9, 1.0, 1.0 }, high_scores.formatScore(scores.magicBurst, 'none yet'));
    else
        textDim('none yet');
    end
end

--=============================================================================
-- Render one party-member slot.
--=============================================================================
local function renderMemberSlot(i, m, ruleset)
    imgui.PushID(i);

    local enRef = { m.enabled and true or false };
    if imgui.Checkbox('##enabled', enRef) then m.enabled = enRef[1]; markDirty(); persist(); end
    imgui.SameLine();
    imgui.Text(('P%d'):fmt(i));
    if m.name and m.name ~= '' then
        imgui.SameLine();
        textDim(m.name);
    end
    imgui.SameLine();

    -- Job
    imgui.PushItemWidth(70);
    local jChanged, jNew = comboString('##job', m.job, jobs.order);
    imgui.PopItemWidth();
    if jChanged then setJob(m, jNew); persist(); end
    imgui.SameLine();

    -- Level
    imgui.PushItemWidth(110);
    local lvlRef = { m.level };
    if imgui.SliderInt('##lvl', lvlRef, 1, 75) then
        m.level = math.max(1, math.min(75, lvlRef[1]));
        deriveSelected(m);  -- re-suggest at the new level (manual edits below can re-toggle)
        markDirty(); persist();
    end
    imgui.PopItemWidth();
    imgui.SameLine();

    -- Weapon (only weapons this job can use)
    local usable = jobs.usableWeapons(m.job);
    imgui.PushItemWidth(120);
    local wChanged, wNew = comboString('##weapon', m.weapon, usable);
    imgui.PopItemWidth();
    if wChanged then
        setWeapon(m, wNew);
        persist();
    end

    -- Weaponskill detail
    if imgui.CollapsingHeader(('Weaponskills (P%d %s / %s)###ws%d'):fmt(i, m.job, m.weapon or '-', i)) then
        if imgui.SmallButton('Auto') then deriveSelected(m); markDirty(); persist(); end
        imgui.SameLine();
        if imgui.SmallButton('All')  then setAllSelected(m, true); markDirty(); persist(); end
        imgui.SameLine();
        if imgui.SmallButton('None') then setAllSelected(m, false); markDirty(); persist(); end
        imgui.SameLine();
        textDim('(Auto = by skill at this level)');

        local list = ws.weapons[m.weapon];
        if list then
            m.selected = m.selected or T{};
            for _, e in ipairs(list) do
                if not e.relic then
                    imgui.PushID(e.id);
                    local r = { m.selected[e.name] and true or false };
                    if imgui.Checkbox(e.name, r) then m.selected[e.name] = r[1]; markDirty(); persist(); end
                    imgui.SameLine();
                    local props = ws.propsFor(e, ruleset);
                    imgui.TextColored(colorFor(props[1]), '[' .. table.concat(props, '/') .. ']');
                    imgui.PopID();
                end
            end
            -- Relic WS (gated by the relic toggle)
            local rel = relicEntry(m.weapon);
            if rel then
                imgui.Separator();
                local rr = { m.relic and true or false };
                if imgui.Checkbox(('Relic: %s'):fmt(rel.name), rr) then m.relic = rr[1]; markDirty(); persist(); end
                imgui.SameLine();
                local rp = ws.propsFor(rel, ruleset);
                imgui.TextColored(colorFor(rp[1]), '[' .. table.concat(rp, '/') .. ']');
            end
        end
    end

    imgui.PopID();
    imgui.Separator();
end

--=============================================================================
-- Render the results panel.
--=============================================================================
local function renderResults()
    local s = planner.summary;
    imgui.Text(('Chains: %d   ('):fmt(s.total));
    imgui.SameLine(0, 0); imgui.TextColored(colorFor('Light'), ('Lv.3: %d'):fmt(s.t3));
    imgui.SameLine(0, 0); imgui.Text('  ');
    imgui.SameLine(0, 0); imgui.TextColored(colorFor('Fusion'), ('Lv.2: %d'):fmt(s.t2));
    imgui.SameLine(0, 0); imgui.Text('  ');
    imgui.SameLine(0, 0); imgui.TextColored(colorFor('Impaction'), ('Lv.1: %d'):fmt(s.t1));
    imgui.SameLine(0, 0); imgui.Text(')');
    if planner.capped then
        imgui.TextColored({ 1.0, 0.6, 0.0, 1.0 }, 'Result cap hit -- narrow the party or lower max steps.');
    end
    imgui.Separator();

    if s.total == 0 then
        textDim('No skillchains. Enable members, pick a weapon, and check some weaponskills.');
        return;
    end

    imgui.BeginChild('scp_results', { 0, 0 }, true);
    local shown = 0;
    for _, r in ipairs(planner.results) do
        shown = shown + 1;
        if shown > MAX_DISPLAY then break end

        -- header: tier + final SC (colored) + steps + burst
        imgui.TextColored(colorFor(r.finalSC), ('%s %s'):fmt(engine.tierLabel(r.finalTier), r.finalSC));
        imgui.SameLine();
        imgui.Text(('(%d steps)'):fmt(r.steps));
        if r.burst and #r.burst > 0 then
            imgui.SameLine();
            textDim('burst:');
            for bi, el in ipairs(r.burst) do
                imgui.SameLine(0, 4);
                imgui.TextColored(colorFor(el), el);
                if bi < #r.burst then imgui.SameLine(0, 0); textDim(','); end
            end
        end

        -- sequence line
        local parts = {};
        for k, step in ipairs(r.sequence) do
            local seg = step.label .. ' ' .. step.wsName;
            if k >= 2 and step.resultSC then seg = seg .. ' = ' .. step.resultSC; end
            parts[k] = seg;
        end
        textDim('   ' .. table.concat(parts, '   >   '));
    end

    if planner.summary.total > MAX_DISPLAY then
        imgui.Separator();
        textDim(('... showing first %d of %d. Use the Lv.2+/Lv.3 filter or "exact SC" to narrow.')
            :fmt(MAX_DISPLAY, planner.summary.total));
    end
    imgui.EndChild();
end

--=============================================================================
-- Main window render.
--=============================================================================
local TIER_OPTIONS = { 'Lv.1+ (all)', 'Lv.2+ only', 'Lv.3 only' };
local function tierIndexToValue(label)
    if label == 'Lv.3 only' then return 3 end
    if label == 'Lv.2+ only' then return 2 end
    return 1;
end
local function tierValueToLabel(v)
    if v == 3 then return 'Lv.3 only' end
    if v == 2 then return 'Lv.2+ only' end
    return 'Lv.1+ (all)';
end

local function renderUI()
    if not planner.settings.visible then return end

    imgui.SetNextWindowSize({ 540, 660 }, ImGuiCond_Appearing);
    local openRef = { planner.settings.visible == true };
    if imgui.Begin('Skillchain Planner###scplanner', openRef, 0) then
        imgui.SetWindowFontScale(1.0);

        -- ===== Controls row 1: ruleset + max steps =====
        imgui.Text('Ruleset:');
        imgui.SameLine();
        imgui.PushItemWidth(150);
        local rsLabel = (planner.settings.ruleset == 'retail') and 'Retail (CoP)' or 'Horizon';
        local rsChanged, rsNew = comboString('##ruleset', rsLabel, { 'Horizon', 'Retail (CoP)' });
        imgui.PopItemWidth();
        if rsChanged then
            planner.settings.ruleset = (rsNew == 'Retail (CoP)') and 'retail' or 'horizon';
            markDirty(); persist();
        end
        imgui.SameLine();
        imgui.PushItemWidth(150);
        local msRef = { planner.settings.maxSteps };
        if imgui.SliderInt('Max steps', msRef, 2, 5) then
            planner.settings.maxSteps = msRef[1]; markDirty(); persist();
        end
        imgui.PopItemWidth();
        imgui.SameLine();
        if imgui.Button('Party Sync') then
            syncPartyFromGame();
        end

        -- ===== Controls row 2: tier filter + distinct + color =====
        imgui.PushItemWidth(150);
        local tChanged, tNew = comboString('##tierfilter', tierValueToLabel(planner.settings.minTier), TIER_OPTIONS);
        imgui.PopItemWidth();
        if tChanged then planner.settings.minTier = tierIndexToValue(tNew); markDirty(); persist(); end
        imgui.SameLine();
        local dRef = { planner.settings.distinct and true or false };
        if imgui.Checkbox('One WS per member', dRef) then planner.settings.distinct = dRef[1]; markDirty(); persist(); end
        imgui.SameLine();
        local cRef = { planner.settings.color and true or false };
        if imgui.Checkbox('Color', cRef) then planner.settings.color = cRef[1]; persist(); end

        imgui.Separator();

        -- ===== Party (scrollable, sized so results stay visible) =====
        imgui.Text('Party');
        imgui.BeginChild('scp_party', { 0, 280 }, true);
        for i = 1, 6 do
            renderMemberSlot(i, planner.settings.party[i], planner.settings.ruleset);
        end
        imgui.EndChild();

        imgui.Separator();
        renderHighScores();

        imgui.Separator();
        renderResults();
    end
    imgui.End();

    if openRef[1] == false then
        planner.settings.visible = false;
        persist();
    end
end

--=============================================================================
-- Settings registration (handles character switches).
--=============================================================================
settings.register('settings', 'scp_settings_update', function (s)
    if s ~= nil then
        planner.settings = s;
        normalizeParty();
        markDirty();
    end
    settings.save();
end);

--=============================================================================
-- Events
--=============================================================================
ashita.events.register('load', 'scp_load', function ()
    normalizeParty();
    markDirty();
    print(chat.header(addon.name):append(chat.message('Loaded. Type /scplanner (or /scp) to open the planner.')));
end);

ashita.events.register('unload', 'scp_unload', function ()
    settings.save();
end);

ashita.events.register('packet_in', 'scp_high_scores_packet_in', function (e)
    if e.id ~= 0x28 then return end

    local ok, changed = pcall(high_scores.handlePacket, e, planner.settings);
    if ok and changed then
        persist();
    elseif not ok then
        local now = os.clock();
        if planner.lastHighScoreErrorAt == nil or (now - planner.lastHighScoreErrorAt) > 5 then
            planner.lastHighScoreErrorAt = now;
            print(chat.header(addon.name):append(chat.error('High score packet parse failed: ' .. tostring(changed))));
        end
    end
end);

ashita.events.register('d3d_present', 'scp_present', function ()
    if planner.dirty then recompute(); end
    renderUI();
    if planner.saveAt and os.clock() >= planner.saveAt then
        planner.saveAt = nil;
        settings.save();
    end
end);

ashita.events.register('command', 'scp_command', function (e)
    local args = e.command:args();
    if (#args == 0) then return; end
    if (not args[1]:any('/scplanner', '/scp')) then return; end

    e.blocked = true;

    if (#args == 1) then
        planner.settings.visible = not planner.settings.visible;
        persist();
        return;
    end

    local sub = args[2]:lower();
    if sub == 'show' then
        planner.settings.visible = true; persist();
    elseif sub == 'hide' then
        planner.settings.visible = false; persist();
    elseif sub == 'horizon' then
        planner.settings.ruleset = 'horizon'; markDirty(); persist();
        print(chat.header(addon.name):append(chat.message('Ruleset: Horizon')));
    elseif sub == 'retail' then
        planner.settings.ruleset = 'retail'; markDirty(); persist();
        print(chat.header(addon.name):append(chat.message('Ruleset: Retail (CoP)')));
    elseif sub == 'sync' then
        syncPartyFromGame();
    elseif sub == 'steps' and #args >= 3 then
        local n = args[3]:number();
        if n and n >= 2 then
            planner.settings.maxSteps = math.min(5, math.floor(n));
            markDirty(); persist();
            print(chat.header(addon.name):append(chat.message(('Max steps: %d'):fmt(planner.settings.maxSteps))));
        end
    elseif sub == 'scores' then
        local action = (#args >= 3) and args[3]:lower() or '';
        if action == 'reset' then
            high_scores.reset(planner.settings);
            persist();
            print(chat.header(addon.name):append(chat.message('High scores reset.')));
        else
            local scores = high_scores.ensure(planner.settings);
            print(chat.header(addon.name):append(chat.message(
                'Skillchain: ' .. high_scores.formatScore(scores.skillchain, 'none yet'))));
            print(chat.header(addon.name):append(chat.message(
                'Magic Burst: ' .. high_scores.formatScore(scores.magicBurst, 'none yet'))));
        end
    elseif sub == 'reset' then
        planner.settings.party = T{};
        normalizeParty();
        -- re-apply default party
        for i = 1, 6 do
            local d = default_settings.party[i];
            local m = planner.settings.party[i];
            m.enabled = d.enabled; m.job = d.job; m.level = d.level; m.weapon = d.weapon; m.relic = d.relic;
            m.name = ''; m.serverId = 0;
            deriveSelected(m);
        end
        markDirty(); persist();
        print(chat.header(addon.name):append(chat.message('Party reset to defaults.')));
    else
        print(chat.header(addon.name):append(chat.message('Commands: /scp [show|hide|horizon|retail|sync|steps N|scores [reset]|reset]')));
    end
end);
