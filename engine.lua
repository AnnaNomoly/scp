--[[
* engine.lua  --  Skillchain enumeration + ranking for the Chains Planner.
* Author: AnnaNomoly
* SPDX-License-Identifier: GPL-3.0-or-later
*
* Pure graph logic over a "move pool".  Knows nothing about jobs, weapons, or
* rulesets -- the caller resolves those and hands the engine a flat list of
* available moves.
*
* A "move" is one weaponskill a party member can perform:
*   { member = <int>, label = <string>, name = <string>, props = { <property names> } }
*
* findChains() walks every ordered sequence of moves where each adjacent pair
* forms a valid skillchain (per sc_data.chainInfo), recording a result at every
* closure.  Multi-property weaponskills are resolved in server priority order:
* target A/B/C property first, then closing A/B/C property, stopping at the first
* valid match.  A branch stops when it reaches a Lv.3 result (Light/Darkness) or
* hits maxSteps -- so Lv.3 is naturally terminal, which matches the level-75 era
* (no Aeonic Radiance/Umbra, no double-Light/Darkness).
--]]

local sc = require('sc_data')

local engine = {}

-- Tier label helper for display.
function engine.tierLabel(tier)
    if tier == 3 then return 'Lv.3' end
    if tier == 2 then return 'Lv.2' end
    if tier == 1 then return 'Lv.1' end
    if tier == 4 then return 'Lv.4' end
    return '?'
end

-- Canonical tier of a named skillchain (falls back to provided level).
local function tierOf(name, fallback)
    return sc.level[name] or fallback or 0
end

local function copyProps(props)
    local out = {}
    for i = 1, #props do
        out[i] = props[i]
    end
    return out
end

local function resolveFirst(resonances, closingProps)
    for ri = 1, #resonances do
        local resonating = resonances[ri]
        for pi = 1, #closingProps do
            local closing = closingProps[pi]
            local res = sc.resolve(resonating, closing)
            if res then
                return res, resonating, closing
            end
        end
    end
    return nil
end

--=============================================================================
-- findChains
--   moves : array of moves (see header)
--   opts  : {
--             maxSteps        = 3,      -- 2..6, total weaponskills in a chain
--             minTier         = 1,      -- only keep results whose final tier >= this
--             finalSC         = nil,    -- if set (name), only keep results ending in it
--             distinctMembers = false,  -- if true, each member used at most once per chain
--             maxResults      = 4000,   -- safety cap on collected results
--           }
--   returns: sorted array of result tables:
--     {
--       steps     = <int>,
--       finalSC   = <name>,
--       finalTier = <int>,
--       burst     = { <element names> },
--       sequence  = { [k] = { member, label, wsName, usedProp, resultSC, resultTier } },
--     }
--=============================================================================
function engine.findChains(moves, opts)
    opts = opts or {}
    local maxSteps = math.max(2, math.min(6, opts.maxSteps or 3))
    local minTier = opts.minTier or 1
    local finalSC = opts.finalSC
    local distinct = opts.distinctMembers and true or false
    local maxResults = opts.maxResults or 4000

    local results = {}
    local seen = {}
    local capped = false

    local function signature(seq)
        local parts = {}
        for i = 1, #seq do
            local s = seq[i]
            parts[i] = s.member .. ':' .. s.wsName .. ':' .. s.usedProp
        end
        return table.concat(parts, '>')
    end

    local function record(seq, resName, resTier)
        if capped then return end
        if finalSC and resName ~= finalSC then return end
        if resTier < minTier then return end
        local sig = signature(seq) .. '#' .. resName
        if seen[sig] then return end
        seen[sig] = true

        -- deep copy the sequence so later mutation can't affect stored results
        local copy = {}
        for i = 1, #seq do
            local s = seq[i]
            copy[i] = {
                member = s.member, label = s.label, wsName = s.wsName,
                usedProp = s.usedProp, resonatingProp = s.resonatingProp,
                resultSC = s.resultSC, resultTier = s.resultTier,
            }
        end

        results[#results + 1] = {
            steps = #seq,
            finalSC = resName,
            finalTier = resTier,
            burst = sc.burstOf(resName),
            sequence = copy,
        }
        if #results >= maxResults then capped = true end
    end

    -- usedMembers is only maintained when distinct == true
    local function extend(resonances, seq, usedMembers)
        if capped then return end
        if #seq >= maxSteps then return end
        for mi = 1, #moves do
            local mv = moves[mi]
            if not (distinct and usedMembers[mv.member]) then
                local res, resonatingProp, closingProp = resolveFirst(resonances, mv.props)
                if res then
                    local resTier = tierOf(res.name, res.level)
                    local step = {
                        member = mv.member, label = mv.label, wsName = mv.name,
                        usedProp = closingProp, resonatingProp = resonatingProp,
                        resultSC = res.name, resultTier = resTier,
                    }
                    seq[#seq + 1] = step
                    record(seq, res.name, resTier)

                    -- continue only while below Lv.3 and under the step cap
                    if resTier < 3 and #seq < maxSteps then
                        if distinct then
                            usedMembers[mv.member] = true
                            extend({ res.name }, seq, usedMembers)
                            usedMembers[mv.member] = nil
                        else
                            extend({ res.name }, seq, usedMembers)
                        end
                    end

                    seq[#seq] = nil
                    if capped then return end
                end
            end
        end
    end

    -- Seed from every move once. The target resonates with the move's full
    -- A/B/C property list until a skillchain collapses it to one result.
    for mi = 1, #moves do
        local mv = moves[mi]
        local seq = { {
            member = mv.member, label = mv.label, wsName = mv.name,
            usedProp = table.concat(mv.props, '/'), resultSC = nil, resultTier = nil,
        } }
        local usedMembers = distinct and { [mv.member] = true } or nil
        extend(copyProps(mv.props), seq, usedMembers)
        if capped then break end
    end

    -- Sort: tier desc, then fewer steps, then SC name, then sequence signature.
    table.sort(results, function(a, b)
        if a.finalTier ~= b.finalTier then return a.finalTier > b.finalTier end
        if a.steps ~= b.steps then return a.steps < b.steps end
        if a.finalSC ~= b.finalSC then return a.finalSC < b.finalSC end
        return signature(a.sequence) < signature(b.sequence)
    end)

    return results, capped
end

return engine
