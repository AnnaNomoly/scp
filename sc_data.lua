--[[
* sc_data.lua  --  Skillchain reference data for the Chains Planner addon.
* Author: AnnaNomoly
* SPDX-License-Identifier: GPL-3.0-or-later
*
* The formation table below (chainInfo) is ported from the "chains" addon by
* Ivaar / Sippius / NerfOnline.  It matches the canonical BG-wiki
* resonance rules, including reciprocal and non-reciprocal pairs
* (e.g. Transfixion -> Scission makes Distortion, but Scission -> Transfixion
* makes nothing).
*
* Usage:
*   chainInfo[resonatingProperty][closingProperty] = { level = N, skillchain = 'Result' }
*
* "resonatingProperty" is the property the target is currently resonating with
* (from the previous weaponskill or the previous skillchain).
* "closingProperty"    is a property of the weaponskill being used to close.
*
* Plain tables are used here (no dependency on Ashita's T{}) so this module
* can be reasoned about / tested in isolation.  Plain tables index identically.
*
* Because this file contains data derived from chains.lua, distribute it under
* GPL-3.0-or-later with the SCP addon. See LICENSE and NOTICE.md.
--]]

local sc = {}

--=============================================================================
-- Skillchain formation table (resonating -> closing => result)
--=============================================================================
sc.chainInfo = {
    Radiance = { level = 4, burst = {'Fire','Wind','Lightning','Light'} },
    Umbra    = { level = 4, burst = {'Earth','Ice','Water','Dark'} },
    Light    = { level = 3, burst = {'Fire','Wind','Lightning','Light'},
        aeonic = { level = 4, skillchain = 'Radiance' },
        Light  = { level = 4, skillchain = 'Light' },
    },
    Darkness = { level = 3, burst = {'Earth','Ice','Water','Dark'},
        aeonic   = { level = 4, skillchain = 'Umbra' },
        Darkness = { level = 4, skillchain = 'Darkness' },
    },
    Gravitation = { level = 2, burst = {'Earth','Dark'},
        Distortion    = { level = 3, skillchain = 'Darkness' },
        Fragmentation = { level = 2, skillchain = 'Fragmentation' },
    },
    Fragmentation = { level = 2, burst = {'Wind','Lightning'},
        Fusion     = { level = 3, skillchain = 'Light' },
        Distortion = { level = 2, skillchain = 'Distortion' },
    },
    Distortion = { level = 2, burst = {'Ice','Water'},
        Gravitation = { level = 3, skillchain = 'Darkness' },
        Fusion      = { level = 2, skillchain = 'Fusion' },
    },
    Fusion = { level = 2, burst = {'Fire','Light'},
        Fragmentation = { level = 3, skillchain = 'Light' },
        Gravitation   = { level = 2, skillchain = 'Gravitation' },
    },
    Compression = { level = 1, burst = {'Dark'},
        Transfixion = { level = 1, skillchain = 'Transfixion' },
        Detonation  = { level = 1, skillchain = 'Detonation' },
    },
    Liquefaction = { level = 1, burst = {'Fire'},
        Impaction = { level = 2, skillchain = 'Fusion' },
        Scission  = { level = 1, skillchain = 'Scission' },
    },
    Induration = { level = 1, burst = {'Ice'},
        Reverberation = { level = 2, skillchain = 'Fragmentation' },
        Compression   = { level = 1, skillchain = 'Compression' },
        Impaction     = { level = 1, skillchain = 'Impaction' },
    },
    Reverberation = { level = 1, burst = {'Water'},
        Induration = { level = 1, skillchain = 'Induration' },
        Impaction  = { level = 1, skillchain = 'Impaction' },
    },
    Transfixion = { level = 1, burst = {'Light'},
        Scission      = { level = 2, skillchain = 'Distortion' },
        Reverberation = { level = 1, skillchain = 'Reverberation' },
        Compression   = { level = 1, skillchain = 'Compression' },
    },
    Scission = { level = 1, burst = {'Earth'},
        Liquefaction  = { level = 1, skillchain = 'Liquefaction' },
        Reverberation = { level = 1, skillchain = 'Reverberation' },
        Detonation    = { level = 1, skillchain = 'Detonation' },
    },
    Detonation = { level = 1, burst = {'Wind'},
        Compression = { level = 2, skillchain = 'Gravitation' },
        Scission    = { level = 1, skillchain = 'Scission' },
    },
    Impaction = { level = 1, burst = {'Lightning'},
        Liquefaction = { level = 1, skillchain = 'Liquefaction' },
        Detonation   = { level = 1, skillchain = 'Detonation' },
    },
}

--=============================================================================
-- Canonical tier of each named skillchain / property (for ranking & display)
--=============================================================================
sc.level = {
    Light = 3, Darkness = 3, Radiance = 4, Umbra = 4,
    Fusion = 2, Fragmentation = 2, Distortion = 2, Gravitation = 2,
    Transfixion = 1, Compression = 1, Liquefaction = 1, Scission = 1,
    Reverberation = 1, Induration = 1, Impaction = 1, Detonation = 1,
}

-- Pseudo-keys inside chainInfo[res] that are NOT closing properties.
sc.nonPropertyKeys = { level = true, burst = true, aeonic = true }

--=============================================================================
-- IMGUI RGB color table {r, g, b, a} (ported from the chains addon, colors by Sammeh)
--=============================================================================
local colors = {}
colors.Light         = { 1.0, 1.0, 1.0, 1.0 }
colors.Dark          = { 0.0, 0.0, 0.8, 1.0 }
colors.Ice           = { 0.0, 1.0, 1.0, 1.0 }
colors.Water         = { 0.0, 1.0, 1.0, 1.0 }
colors.Earth         = { 0.6, 0.5, 0.0, 1.0 }
colors.Wind          = { 0.4, 1.0, 0.4, 1.0 }
colors.Fire          = { 1.0, 0.0, 0.0, 1.0 }
colors.Lightning     = { 1.0, 0.0, 1.0, 1.0 }
colors.Gravitation   = { 0.4, 0.2, 0.0, 1.0 }
colors.Fragmentation = { 1.0, 0.6, 1.0, 1.0 }
colors.Fusion        = { 1.0, 0.4, 0.4, 1.0 }
colors.Distortion    = { 0.2, 0.6, 1.0, 1.0 }
colors.Darkness      = colors.Dark
colors.Umbra         = colors.Dark
colors.Compression   = colors.Dark
colors.Radiance      = colors.Light
colors.Transfixion   = colors.Light
colors.Induration    = colors.Ice
colors.Reverberation = colors.Water
colors.Scission      = colors.Earth
colors.Detonation    = colors.Wind
colors.Liquefaction  = colors.Fire
colors.Impaction     = colors.Lightning
sc.colors = colors

local white = { 1.0, 1.0, 1.0, 1.0 }
function sc.color(name)
    return colors[name] or white
end

--=============================================================================
-- Helpers
--=============================================================================

-- Given a resonating property and a closing property, return the resulting
-- skillchain { name=, level= } or nil if no skillchain forms.
function sc.resolve(resonating, closing)
    local node = sc.chainInfo[resonating]
    if not node then return nil end
    local hit = node[closing]
    if not hit or type(hit) ~= 'table' or not hit.skillchain then return nil end
    return { name = hit.skillchain, level = hit.level }
end

-- Burst elements for a given skillchain/property name (array of element names).
function sc.burstOf(name)
    local node = sc.chainInfo[name]
    if node and node.burst then return node.burst end
    return {}
end

return sc
