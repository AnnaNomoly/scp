--[[
* ws_data.lua  --  Through-Chains-of-Promathia weaponskills for the Chains Planner.
* Author: AnnaNomoly
* SPDX-License-Identifier: GPL-3.0-or-later
*
* Source of properties: the "chains" addon skills.lua (Ivaar/Sippius/NerfOnline),
* classic weaponskill IDs 1-216 only.  These are the level-75-era weaponskills,
* grouped by weapon type.  The property sets in 'prop' are the Horizon / Chains-
* addon values (the addon's default ruleset).
*
* The original skills.lua data is copyright (c) 2017 Ivaar and carries a
* BSD-style license notice. That notice is preserved in NOTICE.md. SCP is
* distributed under GPL-3.0-or-later as a whole because it also includes data
* derived from chains.lua.
*
* RULESETS
*   prop    : Horizon / Chains-addon properties  (ruleset == 'horizon', the default)
*   retail  : OPTIONAL override array, used only when ruleset == 'retail'.
*             If a weaponskill has no 'retail' field, the 'retail' ruleset falls
*             back to 'prop'.  Only deltas evidenced by the source data are filled
*             in (currently: Catastrophe, which the chains addon overrode from the
*             retail Darkness/Gravitation to Fusion/Compression -- see skills.lua).
*             >>> Add further retail-CoP property corrections here as you confirm them. <<<
*
* FIELDS
*   id     : in-game action id (kept for reference / future packet work)
*   name   : English weaponskill name
*   prop   : array of skillchain properties (primary, secondary, ternary)
*   retail : optional array override (see above)
*   skill  : APPROXIMATE combat-skill requirement to learn the WS.  Best-effort,
*            compiled offline; treat as editable.  Used by the auto-suggest layer
*            only -- the per-WS toggles and "show all" override make exact values
*            non-critical.
*   relic  : true for the original Relic-weapon weaponskill (requires that relic;
*            excluded from auto-suggest, enabled via the per-member Relic toggle).
--]]

local ws = {}

ws.weaponOrder = {
    'Hand-to-Hand', 'Dagger', 'Sword', 'Great Sword', 'Axe', 'Great Axe',
    'Scythe', 'Polearm', 'Katana', 'Great Katana', 'Club', 'Staff',
    'Archery', 'Marksmanship',
}

-- Which weapon types occupy the ranged slot (informational; affects nothing in v1).
ws.rangedWeapons = { ['Archery'] = true, ['Marksmanship'] = true }

ws.weapons = {
    ['Hand-to-Hand'] = {
        { id = 1,  name = 'Combo',          prop = {'Impaction'},                     skill = 5   },
        { id = 2,  name = 'Shoulder Tackle', prop = {'Reverberation','Impaction'},    skill = 40  },
        { id = 3,  name = 'One Inch Punch',  prop = {'Compression'},                  skill = 70  },
        { id = 4,  name = 'Backhand Blow',   prop = {'Detonation'},                   skill = 100 },
        { id = 5,  name = 'Raging Fists',    prop = {'Impaction'},                    skill = 125 },
        { id = 6,  name = 'Spinning Attack', prop = {'Liquefaction','Impaction'},     skill = 150 },
        { id = 7,  name = 'Howling Fist',    prop = {'Transfixion','Impaction'},      skill = 175 },
        { id = 8,  name = 'Dragon Kick',     prop = {'Fragmentation'},                skill = 200 },
        { id = 9,  name = 'Asuran Fists',    prop = {'Gravitation','Liquefaction'},   skill = 225 },
        { id = 10, name = 'Final Heaven',    prop = {'Light','Fusion'},               relic = true },
    },
    ['Dagger'] = {
        { id = 16, name = 'Wasp Sting',      prop = {'Scission'},                     skill = 5   },
        { id = 17, name = 'Viper Bite',      prop = {'Scission'},                     skill = 40  },
        { id = 18, name = 'Shadowstitch',    prop = {'Reverberation'},                skill = 70  },
        { id = 19, name = 'Gust Slash',      prop = {'Detonation'},                   skill = 100 },
        { id = 20, name = 'Cyclone',         prop = {'Detonation','Impaction'},       skill = 125 },
        { id = 23, name = 'Dancing Edge',    prop = {'Scission','Detonation'},        skill = 150 },
        { id = 24, name = 'Shark Bite',      prop = {'Fragmentation'},                skill = 175 },
        { id = 25, name = 'Evisceration',    prop = {'Gravitation','Transfixion'},    skill = 200 },
        { id = 26, name = 'Mercy Stroke',    prop = {'Darkness','Gravitation'},       relic = true },
    },
    ['Sword'] = {
        { id = 32, name = 'Fast Blade',       prop = {'Scission'},                    skill = 5   },
        { id = 33, name = 'Burning Blade',    prop = {'Liquefaction'},                skill = 40  },
        { id = 34, name = 'Red Lotus Blade',  prop = {'Liquefaction','Detonation'},   skill = 70  },
        { id = 35, name = 'Flat Blade',       prop = {'Impaction'},                   skill = 100 },
        { id = 36, name = 'Shining Blade',    prop = {'Scission'},                    skill = 125 },
        { id = 37, name = 'Seraph Blade',     prop = {'Scission','Transfixion'},      skill = 150 },
        { id = 38, name = 'Circle Blade',     prop = {'Reverberation','Impaction'},   skill = 175 },
        { id = 40, name = 'Vorpal Blade',     prop = {'Scission','Impaction'},        skill = 200 },
        { id = 41, name = 'Swift Blade',      prop = {'Gravitation'},                 skill = 225 },
        { id = 42, name = 'Savage Blade',     prop = {'Fragmentation','Scission'},    skill = 240 },
        { id = 43, name = 'Knights of Round', prop = {'Light','Fusion'},              relic = true },
    },
    ['Great Sword'] = {
        { id = 48, name = 'Hard Slash',     prop = {'Scission'},                      skill = 5   },
        { id = 49, name = 'Power Slash',    prop = {'Transfixion'},                   skill = 40  },
        { id = 50, name = 'Frostbite',      prop = {'Induration'},                    skill = 70  },
        { id = 51, name = 'Freezebite',     prop = {'Induration','Detonation'},       skill = 100 },
        { id = 52, name = 'Shockwave',      prop = {'Reverberation'},                 skill = 125 },
        { id = 53, name = 'Crescent Moon',  prop = {'Scission'},                      skill = 150 },
        { id = 54, name = 'Sickle Moon',    prop = {'Scission','Impaction'},          skill = 175 },
        { id = 55, name = 'Spinning Slash', prop = {'Fragmentation'},                 skill = 200 },
        { id = 56, name = 'Ground Strike',  prop = {'Fragmentation','Distortion'},    skill = 225 },
        { id = 57, name = 'Scourge',        prop = {'Light','Fusion'},                relic = true },
    },
    ['Axe'] = {
        { id = 64, name = 'Raging Axe',    prop = {'Detonation','Impaction'},              skill = 5   },
        { id = 65, name = 'Smash Axe',     prop = {'Induration','Reverberation'},          skill = 40  },
        { id = 66, name = 'Gale Axe',      prop = {'Detonation'},                          skill = 70  },
        { id = 67, name = 'Avalanche Axe', prop = {'Induration'},                          skill = 100 },
        { id = 68, name = 'Spinning Axe',  prop = {'Liquefaction','Scission','Impaction'}, skill = 125 },
        { id = 69, name = 'Rampage',       prop = {'Scission'},                            skill = 150 },
        { id = 70, name = 'Calamity',      prop = {'Scission','Impaction'},                skill = 175 },
        { id = 71, name = 'Mistral Axe',   prop = {'Fusion'},                              skill = 200 },
        { id = 72, name = 'Decimation',    prop = {'Fusion','Detonation'},                 skill = 225 },
        { id = 73, name = 'Onslaught',     prop = {'Darkness','Gravitation'},              relic = true },
    },
    ['Great Axe'] = {
        { id = 80, name = 'Shield Break',     prop = {'Impaction'},                  skill = 5   },
        { id = 81, name = 'Iron Tempest',     prop = {'Scission'},                   skill = 40  },
        { id = 82, name = 'Sturmwind',        prop = {'Reverberation','Scission'},   skill = 70  },
        { id = 83, name = 'Armor Break',      prop = {'Impaction'},                  skill = 100 },
        { id = 84, name = 'Keen Edge',        prop = {'Compression'},                skill = 125 },
        { id = 85, name = 'Weapon Break',     prop = {'Impaction'},                  skill = 150 },
        { id = 86, name = 'Raging Rush',      prop = {'Induration','Reverberation'}, skill = 175 },
        { id = 87, name = 'Full Break',       prop = {'Distortion'},                 skill = 200 },
        { id = 88, name = 'Steel Cyclone',    prop = {'Distortion','Detonation'},    skill = 225 },
        { id = 89, name = 'Metatron Torment', prop = {'Light','Fusion'},             relic = true },
    },
    ['Scythe'] = {
        { id = 96,  name = 'Slice',            prop = {'Scission'},                  skill = 5   },
        { id = 97,  name = 'Dark Harvest',     prop = {'Reverberation'},             skill = 40  },
        { id = 98,  name = 'Shadow of Death',  prop = {'Induration','Reverberation'},skill = 70  },
        { id = 99,  name = 'Nightmare Scythe', prop = {'Compression','Scission'},    skill = 100 },
        { id = 100, name = 'Spinning Scythe',  prop = {'Reverberation','Scission'},  skill = 125 },
        { id = 101, name = 'Vorpal Scythe',    prop = {'Transfixion','Scission'},    skill = 150 },
        { id = 102, name = 'Guillotine',       prop = {'Induration'},                skill = 175 },
        { id = 103, name = 'Cross Reaper',     prop = {'Distortion'},                skill = 200 },
        { id = 104, name = 'Spiral Hell',      prop = {'Distortion','Scission'},     skill = 225 },
        -- Horizon overrides Catastrophe to Fusion/Compression; retail-CoP is Darkness/Gravitation.
        { id = 105, name = 'Catastrophe',      prop = {'Fusion','Compression'}, retail = {'Darkness','Gravitation'}, relic = true },
    },
    ['Polearm'] = {
        { id = 112, name = 'Double Thrust',   prop = {'Transfixion'},               skill = 5   },
        { id = 113, name = 'Thunder Thrust',  prop = {'Transfixion','Impaction'},   skill = 40  },
        { id = 114, name = 'Raiden Thrust',   prop = {'Transfixion','Impaction'},   skill = 70  },
        { id = 115, name = 'Leg Sweep',       prop = {'Impaction'},                 skill = 100 },
        { id = 116, name = 'Penta Thrust',    prop = {'Compression'},               skill = 125 },
        { id = 117, name = 'Vorpal Thrust',   prop = {'Reverberation','Transfixion'}, skill = 150 },
        { id = 118, name = 'Skewer',          prop = {'Transfixion','Impaction'},   skill = 175 },
        { id = 119, name = 'Wheeling Thrust', prop = {'Fusion'},                    skill = 200 },
        { id = 120, name = 'Impulse Drive',   prop = {'Gravitation','Induration'},  skill = 225 },
        { id = 121, name = 'Geirskogul',      prop = {'Light','Distortion'},        relic = true },
    },
    ['Katana'] = {
        { id = 128, name = 'Blade: Rin',   prop = {'Transfixion'},                  skill = 5   },
        { id = 129, name = 'Blade: Retsu', prop = {'Scission'},                     skill = 40  },
        { id = 130, name = 'Blade: Teki',  prop = {'Reverberation'},                skill = 70  },
        { id = 131, name = 'Blade: To',    prop = {'Induration','Detonation'},      skill = 100 },
        { id = 132, name = 'Blade: Chi',   prop = {'Transfixion','Impaction'},      skill = 125 },
        { id = 133, name = 'Blade: Ei',    prop = {'Compression'},                  skill = 150 },
        { id = 134, name = 'Blade: Jin',   prop = {'Detonation','Impaction'},       skill = 175 },
        { id = 135, name = 'Blade: Ten',   prop = {'Gravitation'},                  skill = 200 },
        { id = 136, name = 'Blade: Ku',    prop = {'Gravitation','Transfixion'},    skill = 225 },
        { id = 137, name = 'Blade: Metsu', prop = {'Darkness','Fragmentation'},     relic = true },
    },
    ['Great Katana'] = {
        { id = 144, name = 'Tachi: Enpi',     prop = {'Transfixion','Scission'},    skill = 5   },
        { id = 145, name = 'Tachi: Hobaku',   prop = {'Induration'},                skill = 40  },
        { id = 146, name = 'Tachi: Goten',    prop = {'Transfixion','Impaction'},   skill = 70  },
        { id = 147, name = 'Tachi: Kagero',   prop = {'Liquefaction'},              skill = 100 },
        { id = 148, name = 'Tachi: Jinpu',    prop = {'Scission','Detonation'},     skill = 125 },
        { id = 149, name = 'Tachi: Koki',     prop = {'Reverberation','Impaction'}, skill = 150 },
        { id = 150, name = 'Tachi: Yukikaze', prop = {'Induration','Detonation'},   skill = 175 },
        { id = 151, name = 'Tachi: Gekko',    prop = {'Distortion','Reverberation'},skill = 200 },
        { id = 152, name = 'Tachi: Kasha',    prop = {'Fusion','Compression'},      skill = 225 },
        { id = 153, name = 'Tachi: Kaiten',   prop = {'Light','Fragmentation'},     relic = true },
    },
    ['Club'] = {
        { id = 160, name = 'Shining Strike', prop = {'Transfixion'},                skill = 5   },
        { id = 161, name = 'Seraph Strike',  prop = {'Scission'},                   skill = 40  },
        { id = 162, name = 'Brainshaker',    prop = {'Reverberation'},              skill = 70  },
        { id = 165, name = 'Skullbreaker',   prop = {'Induration','Reverberation'}, skill = 100 },
        { id = 166, name = 'True Strike',    prop = {'Detonation','Impaction'},     skill = 125 },
        { id = 167, name = 'Judgment',       prop = {'Impaction'},                  skill = 150 },
        { id = 168, name = 'Hexa Strike',    prop = {'Fusion'},                     skill = 175 },
        { id = 169, name = 'Black Halo',     prop = {'Fragmentation','Compression'},skill = 200 },
        { id = 170, name = 'Randgrith',      prop = {'Light','Fragmentation'},      relic = true },
    },
    ['Staff'] = {
        { id = 176, name = 'Heavy Swing',      prop = {'Impaction'},                skill = 5   },
        { id = 177, name = 'Rock Crusher',     prop = {'Impaction'},                skill = 40  },
        { id = 178, name = 'Earth Crusher',    prop = {'Detonation','Impaction'},   skill = 70  },
        { id = 179, name = 'Starburst',        prop = {'Compression','Transfixion'},skill = 100 },
        { id = 180, name = 'Sunburst',         prop = {'Transfixion','Reverberation'}, skill = 125 },
        { id = 181, name = 'Shell Crusher',    prop = {'Detonation'},               skill = 150 },
        { id = 182, name = 'Full Swing',       prop = {'Liquefaction','Impaction'}, skill = 175 },
        { id = 184, name = 'Retribution',      prop = {'Gravitation','Reverberation'}, skill = 200 },
        { id = 185, name = 'Gate of Tartarus', prop = {'Darkness','Distortion'},    relic = true },
    },
    ['Archery'] = {
        { id = 192, name = 'Flaming Arrow',  prop = {'Liquefaction','Transfixion'},              skill = 5   },
        { id = 193, name = 'Piercing Arrow', prop = {'Reverberation','Transfixion'},             skill = 40  },
        { id = 194, name = 'Dulling Arrow',  prop = {'Liquefaction','Transfixion'},              skill = 70  },
        { id = 196, name = 'Sidewinder',     prop = {'Reverberation','Transfixion','Detonation'},skill = 100 },
        { id = 197, name = 'Blast Arrow',    prop = {'Induration','Transfixion'},                skill = 125 },
        { id = 198, name = 'Arching Arrow',  prop = {'Fusion'},                                  skill = 150 },
        { id = 199, name = 'Empyreal Arrow', prop = {'Fusion','Transfixion'},                    skill = 175 },
        { id = 200, name = 'Namas Arrow',    prop = {'Light','Distortion'},                      relic = true },
    },
    ['Marksmanship'] = {
        { id = 208, name = 'Hot Shot',    prop = {'Liquefaction','Transfixion'},              skill = 5   },
        { id = 209, name = 'Split Shot',  prop = {'Reverberation','Transfixion'},             skill = 40  },
        { id = 210, name = 'Sniper Shot', prop = {'Liquefaction','Transfixion'},              skill = 70  },
        { id = 212, name = 'Slug Shot',   prop = {'Reverberation','Transfixion','Detonation'},skill = 100 },
        { id = 213, name = 'Blast Shot',  prop = {'Induration','Transfixion'},                skill = 125 },
        { id = 214, name = 'Heavy Shot',  prop = {'Fusion'},                                  skill = 150 },
        { id = 215, name = 'Detonator',   prop = {'Fusion','Transfixion'},                    skill = 175 },
        { id = 216, name = 'Coronach',    prop = {'Darkness','Fragmentation'},                relic = true },
    },
}

-- Return the property array for a weaponskill entry under the given ruleset.
function ws.propsFor(entry, ruleset)
    if ruleset == 'retail' and entry.retail then
        return entry.retail
    end
    return entry.prop
end

return ws
