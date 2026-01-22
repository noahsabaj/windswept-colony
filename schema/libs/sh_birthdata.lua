--[[
    Birth Data Library

    Constants and utilities for birth date and location handling.
    Used in character creation and Personal ID display.
]]--

ix.birthdata = ix.birthdata or {}

-- The current in-game year
ix.birthdata.CURRENT_YEAR = 2200

-- Month names
ix.birthdata.months = {
    "January", "February", "March", "April",
    "May", "June", "July", "August",
    "September", "October", "November", "December"
}

-- Days in each month (non-leap year)
ix.birthdata.daysInMonth = {
    31, 28, 31, 30, 31, 30,
    31, 31, 30, 31, 30, 31
}

-- Birth location options
ix.birthdata.locations = {
    "North America, Earth",
    "South America, Earth",
    "Europe, Earth",
    "Asia, Earth",
    "Africa, Earth",
    "Australia, Earth",
    "Antarctica, Earth",
    "Mars",
    "Venus",
    "Luna (Earth's Moon)",
    "Phobos",
    "Deimos",
    "Kuiper Belt",
    "Unspecified",
    "Redrock City"
}

-- Check if a year is a leap year
function ix.birthdata.IsLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

-- Get the maximum days for a given month and birth year
function ix.birthdata.GetMaxDay(month, age)
    month = tonumber(month) or 1
    age = tonumber(age) or 25

    local birthYear = ix.birthdata.CURRENT_YEAR - age
    local maxDays = ix.birthdata.daysInMonth[month] or 31

    -- February leap year check
    if month == 2 and ix.birthdata.IsLeapYear(birthYear) then
        maxDays = 29
    end

    return maxDays
end

-- Calculate birth year from age
function ix.birthdata.GetBirthYear(age)
    return ix.birthdata.CURRENT_YEAR - (tonumber(age) or 25)
end

-- Format a birth date for display
function ix.birthdata.FormatDate(month, day, age)
    month = tonumber(month) or 1
    day = tonumber(day) or 1
    age = tonumber(age) or 25

    local monthName = ix.birthdata.months[month] or "January"
    local year = ix.birthdata.GetBirthYear(age)

    return string.format("%s %d, %d", monthName, day, year)
end

-- Validate a day value for a given month and age
function ix.birthdata.ValidateDay(month, day, age)
    local maxDay = ix.birthdata.GetMaxDay(month, age)
    return math.Clamp(tonumber(day) or 1, 1, maxDay)
end

-- Get month name from number
function ix.birthdata.GetMonthName(month)
    return ix.birthdata.months[tonumber(month) or 1] or "January"
end

-- Check if a location is valid
function ix.birthdata.IsValidLocation(location)
    for _, loc in ipairs(ix.birthdata.locations) do
        if loc == location then
            return true
        end
    end
    return false
end
