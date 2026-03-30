-- Test scene: demonstrates all VN features
return {
    -- Set background
    { type = "background", color = {0.12, 0.18, 0.1}, label = "Cafe Interior" },

    -- Show characters
    { type = "show", character = "scarlett", position = "right", expression = "neutral" },

    -- Opening dialogue
    { type = "dialogue", character = "scarlett", text = "Well well, a new face in the cafe. You must be the new owner." },

    { type = "show", character = "player", position = "left", expression = "neutral" },

    { type = "dialogue", character = "player", text = "That's right. My mother left this place to me." },

    { type = "expression", character = "scarlett", expression = "smirk" },
    { type = "dialogue", character = "scarlett", text = "Think you can handle it? This place has... a reputation." },

    -- Player choice
    {
        type = "choice",
        choices = {
            { text = "I'm ready for anything.", next = "confident_response" },
            { text = "Honestly, I'm not sure.", next = "humble_response" },
        }
    },

    -- Branch: confident
    { type = "label", name = "confident_response" },
    { type = "expression", character = "scarlett", expression = "impressed" },
    { type = "dialogue", character = "scarlett", text = "Ha! I like your attitude. How about a game of pool to prove it?" },
    { type = "goto", target = "challenge" },

    -- Branch: humble
    { type = "label", name = "humble_response" },
    { type = "expression", character = "scarlett", expression = "gentle" },
    { type = "dialogue", character = "scarlett", text = "Don't worry, everyone starts somewhere. Let me show you the ropes over a game." },
    { type = "goto", target = "challenge" },

    -- Converge
    { type = "label", name = "challenge" },
    { type = "expression", character = "player", expression = "determined" },
    { type = "dialogue", character = "player", text = "You're on. Let's play." },

    { type = "expression", character = "scarlett", expression = "happy" },
    { type = "dialogue", character = "scarlett", text = "That's the spirit! Rack 'em up!" },

    -- Hide characters and start match
    { type = "hide", character = "scarlett" },
    { type = "hide", character = "player" },

    { type = "start_match", opponent = "scarlett" },
}
