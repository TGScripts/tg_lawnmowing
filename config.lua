Config = {}

Config.Debug                =   false
Config.Locale               =   'de'    -- Sprache einstellen (Set Default Language)

Config.AllowedVehicle       =   "mower"
Config.VehicleSpawnCoords   =   vector3(-108.9251, -409.1294, 35.7743)

Config.ShowBoundaries       =   true
Config.PerPercentPayment    =   5

Config.LawnZone = {
    points = {
        vector3(-138.1990, -385.8470, 33.7930),
        vector3(-156.2798, -441.4453, 33.8511),
        vector3(-148.8564, -448.7888, 33.8517),
        vector3(-143.6042, -462.8760, 33.9635),
        vector3(-121.0598, -471.9648, 33.9790),
        vector3(-62.2947, -471.9665, 36.7289),
        vector3(-43.4795, -416.8961, 39.5810),
        vector3(-64.9227, -406.0563, 37.3397),
        vector3(-100.3140, -392.8334, 36.8160)
    },
    radius = 1.0
}

Config.NPC = {
    model = "a_m_m_farmer_01",
    coords = vector3(-106.6976, -407.8405, 34.7843),
    heading = 130.6431,

    blip = {
        enabled = true,
        name = "Rasenmähen",

        sprite = 646,
        color = 2,
        scale = 1.0,
    }
}
