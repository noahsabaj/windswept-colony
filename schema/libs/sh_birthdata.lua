--[[
    Birth Data Library

    Constants and utilities for birth date and location handling.
    Used in character creation and Personal ID display.
]]--

ws.birthdata = ws.birthdata or {}

-- The current in-game year
ws.birthdata.CURRENT_YEAR = 2200

-- Month names
ws.birthdata.months = {
    "January", "February", "March", "April",
    "May", "June", "July", "August",
    "September", "October", "November", "December"
}

-- Days in each month (non-leap year)
ws.birthdata.daysInMonth = {
    31, 28, 31, 30, 31, 30,
    31, 31, 30, 31, 30, 31
}

-- Birth location options
ws.birthdata.locations = {
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
function ws.birthdata.IsLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

-- Get the maximum days for a given month and birth year
function ws.birthdata.GetMaxDay(month, age)
    month = tonumber(month) or 1
    age = tonumber(age) or 25

    local birthYear = ws.birthdata.CURRENT_YEAR - age
    local maxDays = ws.birthdata.daysInMonth[month] or 31

    -- February leap year check
    if month == 2 and ws.birthdata.IsLeapYear(birthYear) then
        maxDays = 29
    end

    return maxDays
end

-- Calculate birth year from age
function ws.birthdata.GetBirthYear(age)
    return ws.birthdata.CURRENT_YEAR - (tonumber(age) or 25)
end

-- Format a birth date for display
function ws.birthdata.FormatDate(month, day, age)
    month = tonumber(month) or 1
    day = tonumber(day) or 1
    age = tonumber(age) or 25

    local monthName = ws.birthdata.months[month] or "January"
    local year = ws.birthdata.GetBirthYear(age)

    return string.format("%s %d, %d", monthName, day, year)
end

-- Validate a day value for a given month and age
function ws.birthdata.ValidateDay(month, day, age)
    local maxDay = ws.birthdata.GetMaxDay(month, age)
    return math.Clamp(tonumber(day) or 1, 1, maxDay)
end

-- Get month name from number
function ws.birthdata.GetMonthName(month)
    return ws.birthdata.months[tonumber(month) or 1] or "January"
end

-- Check if a location is valid
function ws.birthdata.IsValidLocation(location)
    for _, loc in ipairs(ws.birthdata.locations) do
        if loc == location then
            return true
        end
    end
    return false
end

-- Get current in-game date (real month/day, year 2200)
function ws.birthdata.GetCurrentDate()
    local realDate = os.date("*t")
    local monthName = ws.birthdata.months[realDate.month]
    return string.format("%s %d, %d", monthName, realDate.day, ws.birthdata.CURRENT_YEAR)
end
