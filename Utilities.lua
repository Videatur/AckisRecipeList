-- Shared helpers for native frames, text, item links and unit GUIDs.
local FOLDER_NAME, private = ...
local type = _G.type
local tonumber = _G.tonumber
local tostring = _G.tostring

private.SafeOps = {}
function private.SafeOps.IsSecretValue(value)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(value) or false
end

function private.CreateFrameWithBackdrop(frameType, name, parent, template)
    return _G.CreateFrame(frameType, name, parent, template or "BackdropTemplate")
end

-- Use Edit Mode's native dialog background without changing the shared popup border.
function private.ShowPopupBackground(popup)
    if popup.ackisPopupBackground then return end
    local background = popup.BG
    if not background or not background.Bottom then return end
    local bottom = background.Bottom
    popup.ackisPopupBackground = {
        atlas = bottom:GetAtlas(),
        texture = bottom:GetTexture(),
        horizontalTile = bottom:GetHorizTile(),
        verticalTile = bottom:GetVertTile(),
    }
    bottom:SetTexture([[Interface\DialogFrame\UI-DialogBox-Background]])
    bottom:SetHorizTile(true)
    bottom:SetVertTile(true)
end

-- Blizzard reuses these frames for other dialogs; restore their original appearance.
function private.HidePopupBackground(popup)
    local original = popup.ackisPopupBackground
    if not original then return end
    local background = popup.BG
    local bottom = background.Bottom
    if original.atlas then
        bottom:SetAtlas(original.atlas)
    else
        bottom:SetTexture(original.texture)
    end
    bottom:SetHorizTile(original.horizontalTile)
    bottom:SetVertTile(original.verticalTile)
    popup.ackisPopupBackground = nil
end

function private.SetTextColor(color_code, text)
    local cc = "ffffff"
    if type(color_code) == "string" then
        local hex = color_code:match("^[0-9a-fA-F]{6}") or color_code:gsub("[^0-9a-fA-F]", ""):sub(1, 6)
        if hex and #hex == 6 then
            cc = hex
        end
    end
    return ("|cff%s%s|r"):format(cc, tostring(text or ""))
end

function private.MobGUIDToIDNum(guid)
    -- A tooltip may supply a secret unit GUID. An
    -- addon-tainted execution path cannot index or parse that string.
    if private.SafeOps.IsSecretValue(guid) then return end
    if not guid or type(guid) ~= "string" then return end

    if guid:find("-") then
        local _, _, _, _, _, id_num = ("-"):split(guid)
        return tonumber(id_num)
    end

    local hex = guid:gsub("^0x", "")
    if #hex >= 10 then
        return tonumber(hex:sub(6, 10), 16)
    end
    return tonumber(guid)
end

