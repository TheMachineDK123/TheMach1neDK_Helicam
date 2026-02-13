Config = {}

Config.Locale = 'da'

Config.AllowedJobs = {
    police = true,
}

Config.AllowedHelis = {
    polmav = true,
    maverick = true,
}

Config.RequireSeat = false

Config.ToggleKey = 74
Config.LockKey = 38
Config.SpotlightKey = 47
Config.RecToggleKey = 45
Config.NightVisionKey = 249
Config.ThermalKey = 182
Config.CopyPlateKey = 311
Config.ExitKey = 177

Config.Zoom = {
    MinFov = 15.0,
    MaxFov = 65.0,
    Step = 2.5,
    Smooth = 8.0,
}

Config.Look = {
    SpeedKeyboard = 3.0,
    SpeedMouse = 7.5,
    MaxPitch = 60.0,
    MinPitch = -95.0,
}

Config.Targeting = {
    MaxDistance = 900.0,
    LockBreakDistance = 1200.0,
    RaycastFlags = 10,
}

Config.Spotlight = {
    CustomEnabled = true,
    Distance = 150.0,
    Brightness = 4.5,
    Hardness = 3.5,
    Radius = 10.0,
    Falloff = 2.0,
    Color = { r = 235, g = 255, b = 255 },
    Offset = { x = 0.0, y = 2.0, z = -1.2 },
}

Config.ANPR = {
    Enabled = true,
    OnlyWhenLocked = true,
    IntervalMs = 2500,
    CooldownMs = 8000,
}

Config.Database = {
    LogANPR = false,
}

Config.Ownership = {
    Enabled = true,
    OwnedVehiclesTable = 'owned_vehicles',
    OwnedVehiclesPlateColumn = 'plate',
    OwnedVehiclesOwnerColumn = 'owner',
    UsersTable = 'users',
    UsersIdentifierColumn = 'identifier',
    UsersFirstNameColumn = 'firstname',
    UsersLastNameColumn = 'lastname',
}
