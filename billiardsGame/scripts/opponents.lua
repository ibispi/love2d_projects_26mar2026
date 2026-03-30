local opponents = {}

opponents.scarlett = {
    name = "Scarlett",
    balls_color = {0.9, 0.2, 0.2},
    alt_balls_color = {0.9, 0.5, 0.1},
    ai = {
        accuracy = 0.7,
        power_control = 0.6,
        aggression = 0.8,
        think_time = 1.5,
    }
}

opponents.marina = {
    name = "Marina",
    balls_color = {0.2, 0.8, 0.7},
    alt_balls_color = {0.3, 0.9, 0.3},
    ai = {
        accuracy = 0.85,
        power_control = 0.8,
        aggression = 0.3,
        think_time = 2.0,
    }
}

opponents.diana = {
    name = "Diana",
    balls_color = {0.7, 0.2, 0.8},
    alt_balls_color = {0.8, 0.2, 0.5},
    ai = {
        accuracy = 0.5,
        power_control = 0.4,
        aggression = 1.0,
        think_time = 1.0,
    }
}

return opponents
