-- Internationalization module
-- English is the base language; all text is written in English.
-- Other languages provide translation tables that map English -> translated.
-- If a translation is missing, the original English text is returned.

local M = {}

local languages = {}      -- loaded from content/translations/languages.lua
local currentCode = "en"  -- active language code
local translations = {}   -- the active translation table (English key -> translated value)
local flagImages = {}     -- [code] = love2d Image

function M.load()
    package.loaded["content.translations.languages"] = nil
    languages = require("content.translations.languages")

    -- Preload flag images
    flagImages = {}
    for _, lang in ipairs(languages) do
        if love.filesystem.getInfo(lang.flag) then
            local ok, img = pcall(love.graphics.newImage, lang.flag)
            if ok then
                flagImages[lang.code] = img
            end
        end
    end
end

-- Set the active language by code. Loads its translation file if it exists.
function M.setLanguage(code)
    currentCode = code
    translations = {}

    if code == "en" then
        -- English is the base language, no translation needed
        return
    end

    -- Try to load the translation module
    local modulePath = "content.translations." .. code
    package.loaded[modulePath] = nil

    -- Check if the file exists before requiring
    local filePath = "content/translations/" .. code .. ".lua"
    if love.filesystem.getInfo(filePath) then
        local ok, result = pcall(require, modulePath)
        if ok and type(result) == "table" then
            translations = result
        end
    end
end

-- Translate a string. Returns the translation if available, otherwise the original.
function M.t(text)
    if currentCode == "en" or not text then
        return text
    end
    return translations[text] or text
end

-- Get the current language code
function M.getLanguageCode()
    return currentCode
end

-- Get the list of all available languages
function M.getLanguages()
    return languages
end

-- Get the flag image for a language code
function M.getFlag(code)
    return flagImages[code]
end

-- Get the current language's flag image
function M.getCurrentFlag()
    return flagImages[currentCode]
end

-- Get the language entry for a code
function M.getLanguageByCode(code)
    for _, lang in ipairs(languages) do
        if lang.code == code then
            return lang
        end
    end
    return nil
end

return M
