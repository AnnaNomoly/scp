--[[
* jobs.lua  --  Job roster + skill model for the Chains Planner.
* Author: AnnaNomoly
* SPDX-License-Identifier: GPL-3.0-or-later
*
* SCOPE: only the jobs that existed through Chains of Promathia (15):
*   WAR MNK WHM BLM RDM THF PLD DRK BST BRD RNG SMN SAM NIN DRG
* (No BLU/COR/PUP from ToAU, no SCH/DNC from WotG, no GEO/RUN from SoA.)
*
* >>> ACCURACY NOTE <<<
* The skill-grade matrix and the level-75 skill caps below were compiled offline
* (no wiki access at build time) and are BEST-EFFORT.  They drive the auto-suggest
* layer only.  Because every member also has per-WS checkboxes and a "show all WS
* for this weapon" override, imperfect values here are never fatal -- they just
* change which WS start out checked.  Treat this whole file as editable data.
--]]

local ws = require('ws_data')

local jobs = {}

jobs.order = {
    'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK',
    'BST', 'BRD', 'RNG', 'SMN', 'SAM', 'NIN', 'DRG',
}

jobs.names = {
    WAR = 'Warrior',     MNK = 'Monk',         WHM = 'White Mage',
    BLM = 'Black Mage',  RDM = 'Red Mage',     THF = 'Thief',
    PLD = 'Paladin',     DRK = 'Dark Knight',  BST = 'Beastmaster',
    BRD = 'Bard',        RNG = 'Ranger',       SMN = 'Summoner',
    SAM = 'Samurai',     NIN = 'Ninja',        DRG = 'Dragoon',
}

--=============================================================================
-- Skill caps
--=============================================================================
-- Approximate combat-skill cap at level 75 by rank (single-letter ranks).
-- Editable; verify against your server if you rely on tight skill gating.
jobs.cap75 = {
    A = 269, B = 256, C = 242, D = 230, E = 215, F = 200, G = 184,
}

-- Skill cap for a rank at a given character level.
-- At level >= 75 this returns the 75-era cap above.  Below 75 it uses a crude
-- monotonic proxy (the true 75-era curve is piecewise-linear by level); good
-- enough for auto-suggest, and exact values matter little once you toggle.
function jobs.skillCap(rank, level)
    local cap = jobs.cap75[rank]
    if not cap then return 0 end
    if level >= 75 then return cap end
    if level < 1 then level = 1 end
    return math.floor(cap * level / 75 + 0.5)
end

--=============================================================================
-- Weapon skill-grade matrix:  jobs.grades[JOB][weaponType] = 'A'..'G'
-- A weapon type ABSENT for a job means the job cannot use it.
--=============================================================================
jobs.grades = {
    WAR = { ['Axe']='A', ['Great Axe']='A', ['Sword']='B', ['Great Sword']='B',
            ['Club']='B', ['Scythe']='C', ['Polearm']='C', ['Dagger']='C',
            ['Staff']='C', ['Archery']='C', ['Marksmanship']='C' },
    MNK = { ['Hand-to-Hand']='A', ['Staff']='B', ['Club']='C', ['Dagger']='E' },
    WHM = { ['Staff']='B', ['Club']='C', ['Hand-to-Hand']='E', ['Dagger']='E' },
    BLM = { ['Staff']='C', ['Dagger']='D', ['Club']='E', ['Hand-to-Hand']='F' },
    RDM = { ['Sword']='B', ['Dagger']='C', ['Club']='C', ['Staff']='C',
            ['Great Sword']='E', ['Archery']='E', ['Marksmanship']='E' },
    THF = { ['Dagger']='A', ['Sword']='C', ['Katana']='C', ['Club']='C',
            ['Archery']='C', ['Marksmanship']='C', ['Hand-to-Hand']='D',
            ['Scythe']='E', ['Staff']='E' },
    PLD = { ['Sword']='A', ['Great Sword']='B', ['Club']='B', ['Staff']='C',
            ['Dagger']='D', ['Polearm']='E', ['Axe']='E', ['Great Axe']='E' },
    DRK = { ['Scythe']='A', ['Great Sword']='A', ['Sword']='B', ['Great Axe']='B',
            ['Axe']='C', ['Club']='C', ['Dagger']='C', ['Staff']='C',
            ['Polearm']='E', ['Marksmanship']='E' },
    BST = { ['Axe']='A', ['Scythe']='C', ['Club']='C', ['Dagger']='C',
            ['Staff']='C', ['Sword']='D', ['Great Axe']='E', ['Hand-to-Hand']='E' },
    BRD = { ['Dagger']='C', ['Sword']='C', ['Club']='C', ['Staff']='C',
            ['Hand-to-Hand']='E', ['Archery']='E', ['Marksmanship']='E' },
    RNG = { ['Archery']='A', ['Marksmanship']='A', ['Axe']='B', ['Dagger']='C',
            ['Sword']='C', ['Club']='D', ['Staff']='D', ['Great Axe']='E' },
    SMN = { ['Staff']='C', ['Club']='D', ['Dagger']='D', ['Hand-to-Hand']='E' },
    SAM = { ['Great Katana']='A', ['Polearm']='C', ['Sword']='D', ['Great Sword']='D',
            ['Dagger']='D', ['Club']='D', ['Staff']='D', ['Katana']='D',
            ['Axe']='E', ['Great Axe']='E', ['Scythe']='E', ['Archery']='E',
            ['Marksmanship']='E', ['Hand-to-Hand']='E' },
    NIN = { ['Katana']='A', ['Sword']='C', ['Dagger']='C', ['Club']='D',
            ['Staff']='D', ['Great Katana']='E', ['Polearm']='E',
            ['Archery']='E', ['Marksmanship']='E', ['Hand-to-Hand']='E' },
    DRG = { ['Polearm']='A', ['Sword']='C', ['Staff']='D', ['Club']='D',
            ['Dagger']='D', ['Great Sword']='E', ['Axe']='E' },
}

--=============================================================================
-- Helpers
--=============================================================================

-- Weapon types a job can use, in canonical weapon order.
function jobs.usableWeapons(job)
    local g = jobs.grades[job]
    local out = {}
    if not g then return out end
    for _, wt in ipairs(ws.weaponOrder) do
        if g[wt] then out[#out + 1] = wt end
    end
    return out
end

-- Skill grade a job has in a weapon ('A'..'G'), or nil.
function jobs.gradeFor(job, weapon)
    local g = jobs.grades[job]
    return g and g[weapon] or nil
end

-- Whether (job, level) can auto-learn a (non-relic) weaponskill on a weapon,
-- based on whether its skill cap reaches the WS's skill requirement.
function jobs.canLearn(job, level, weapon, wsEntry)
    if wsEntry.relic then return false end
    local grade = jobs.gradeFor(job, weapon)
    if not grade then return false end
    return jobs.skillCap(grade, level) >= (wsEntry.skill or 0)
end

return jobs
