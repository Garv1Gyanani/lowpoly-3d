class_name GameCatalog
extends RefCounted

## Complete balanced data catalogs for Desert Outpost:
## 3 Road tiers, 3 Parking Lot archetypes, 8 Businesses (Lv1-5), 6 Stages, 5 Decorations.

enum BusinessType {
	VENDOR_STALL,
	CONVENIENCE_STORE,
	FOOD_STAND,
	DESERT_DINER,
	GAS_STATION,
	DESERT_MOTEL,
	LOOKOUT_CAMP,
	OASIS_PLAZA,
}

enum RoadTier { DIRT, GRAVEL, PAVED }
enum ParkingLotKind { DIRT_PULL_OFF, GRAVEL_LOT, PAVED_LOT }
enum LotEntrySide { SOUTH, WEST, NORTH, EAST }
enum WorldToolMode { PLAY, PAINT_ROAD, PLACE_BUILDING, PLACE_PARKING, PLACE_DECORATION, BUY_LAND, PLACE_UTILITY, PLACE_POWER_POLE, PAINT_CONDUIT, PAINT_WATER_PIPE }
enum UtilityKind { WINDMILL, SOLAR_ARRAY, DIESEL_GEN, BATTERY_BANK, WATER_WELL, WATER_TOWER, FREIGHT_DEPOT, OIL_PUMPJACK, MINI_REFINERY, DESERT_GREENHOUSE, CRAFT_WORKSHOP }
enum PowerLineKind { WOOD_POLE, STEEL_TOWER, UNDERGROUND }
enum VehicleKind { COMPACT_CAR, PICKUP_TRUCK, SUV, CAMPER_RV, TOURIST_VAN, DELIVERY_TRUCK }
enum Commodity { NONE, DRINKS_SNACKS, FRESH_FOOD, CRUDE_OIL, REFINED_FUEL, DESERT_CRAFTS }
enum PriceTier { VALUE, FAIR, MARKUP }
enum CrewKind { GRID_TECH, PUMP_ENGINEER, LOGISTICS_RUNNER }
enum VehiclePhase { HIGHWAY_CRUISE, PULLING_IN, PARKED, BACKING_OUT, PULLING_OUT }
enum VisitorPhase { WALKING_TO_BUSINESS, SHOPPING, RETURNING_TO_CAR }
enum DecorationKind { SAGUARO_CLUSTER, WOODEN_SIGNPOST, PICNIC_SET, DESERT_LAMP, CAMPFIRE_RING }
enum OutpostPreset { FULL_CITY, STAGE_ONE_CAREER }
enum StructureCategory { BUSINESS, PARKING, UTILITY, INDUSTRIAL, SOCIAL, DECORATION }
enum MapLens { NONE, LAND_TRAITS, POWER, WATER, SUPPLY }
enum ParcelTrait { NONE, HIGHWAY_PRIME, SCENIC_MESA, WIND_CORRIDOR, OIL_SEEP, AQUIFER }

const WATER_PIPE_COST := 12.0

const COMMODITIES := {
	Commodity.NONE: {
		"name": "Service",
		"short": "NONE",
		"wholesale_unit_cost": 0.0,
		"export_value_per_unit": 0.0,
		"color": Color("948a7e"),
	},
	Commodity.DRINKS_SNACKS: {
		"name": "Drinks & Snacks",
		"short": "SNACKS",
		"wholesale_unit_cost": 1.2,
		"export_value_per_unit": 0.0,
		"color": Color("4b9b95"),
	},
	Commodity.FRESH_FOOD: {
		"name": "Fresh Food",
		"short": "FOOD",
		"wholesale_unit_cost": 2.0,
		"export_value_per_unit": 0.0,
		"color": Color("64b86b"),
	},
	Commodity.CRUDE_OIL: {
		"name": "Crude Oil",
		"short": "CRUDE",
		"wholesale_unit_cost": 0.0,
		"export_value_per_unit": 2.4,
		"color": Color("473d4e"),
	},
	Commodity.REFINED_FUEL: {
		"name": "Refined Fuel",
		"short": "FUEL",
		"wholesale_unit_cost": 3.4,
		"export_value_per_unit": 4.2,
		"color": Color("d49830"),
	},
	Commodity.DESERT_CRAFTS: {
		"name": "Desert Crafts",
		"short": "CRAFTS",
		"wholesale_unit_cost": 2.6,
		"export_value_per_unit": 0.0,
		"color": Color("c9533e"),
	},
}

const PRICE_TIERS := {
	PriceTier.VALUE: {"name": "VALUE", "short": "0.85×", "income_mult": 0.92, "burn_mult": 1.22, "desc": "Lower prices · Faster shelf turnover"},
	PriceTier.FAIR: {"name": "FAIR", "short": "1.00×", "income_mult": 1.00, "burn_mult": 1.00, "desc": "Balanced roadside pricing"},
	PriceTier.MARKUP: {"name": "MARKUP", "short": "1.25×", "income_mult": 1.14, "burn_mult": 0.80, "desc": "Higher margin per sale · Slower burn"},
}

const PARCEL_TRAITS := {
	ParcelTrait.NONE: {
		"id": "none",
		"name": "Open Desert",
		"short": "DESERT",
		"desc": "Flat buildable desert sand",
		"tint": Color(0.86, 0.74, 0.56, 0.14),
		"rim": Color(0.92, 0.82, 0.64, 0.45),
		"badge_col": Color("8a745b"),
	},
	ParcelTrait.HIGHWAY_PRIME: {
		"id": "highway_prime",
		"name": "Route 163 Frontage",
		"short": "HIGHWAY",
		"desc": "Prime roadside visibility for carts & fuel",
		"tint": Color(0.95, 0.76, 0.30, 0.28),
		"rim": Color(0.98, 0.84, 0.38, 0.85),
		"badge_col": Color("c88d26"),
	},
	ParcelTrait.SCENIC_MESA: {
		"id": "scenic_mesa",
		"name": "Mesa Overlook",
		"short": "SCENIC",
		"desc": "Red-rock views · Ideal for Motels, Camps & Tours",
		"tint": Color(0.86, 0.46, 0.34, 0.30),
		"rim": Color(0.96, 0.60, 0.44, 0.88),
		"badge_col": Color("c9533e"),
	},
	ParcelTrait.WIND_CORRIDOR: {
		"id": "wind_corridor",
		"name": "Wind Corridor",
		"short": "WIND+",
		"desc": "Steady canyon gusts · +40% Windmill output",
		"tint": Color(0.42, 0.82, 0.78, 0.30),
		"rim": Color(0.56, 0.96, 0.90, 0.88),
		"badge_col": Color("3b8d86"),
	},
	ParcelTrait.OIL_SEEP: {
		"id": "oil_seep",
		"name": "Oil Seep",
		"short": "OIL SEEP",
		"desc": "Subsurface crude pocket · Enables Oil Pumpjacks",
		"tint": Color(0.30, 0.26, 0.34, 0.42),
		"rim": Color(0.84, 0.62, 0.32, 0.92),
		"badge_col": Color("473d4e"),
	},
	ParcelTrait.AQUIFER: {
		"id": "aquifer",
		"name": "Desert Aquifer",
		"short": "AQUIFER",
		"desc": "Shallow groundwater wash · High-yield Water Wells",
		"tint": Color(0.28, 0.64, 0.86, 0.34),
		"rim": Color(0.48, 0.86, 1.0, 0.92),
		"badge_col": Color("2e759e"),
	},
}

const MAP_LENSES := [
	{"id": MapLens.NONE, "short": "STD", "name": "Standard View", "hint": "Normal sunlit desert view"},
	{"id": MapLens.LAND_TRAITS, "short": "LAND", "name": "Land Traits", "hint": "Highlight Oil Seeps, Aquifers, Wind & Scenic zones"},
	{"id": MapLens.POWER, "short": "PWR", "name": "Power Grid", "hint": "Inspect overhead lines, conduits & power demand"},
	{"id": MapLens.WATER, "short": "H2O", "name": "Water Pipes", "hint": "Inspect aquifers, pipes & water needs"},
	{"id": MapLens.SUPPLY, "short": "SUP", "name": "Supply & Stock", "hint": "Inspect business supply readiness"},
]

const ROAD_TIERS := {
	RoadTier.DIRT: {
		"name": "Dirt Track",
		"short": "DIRT",
		"unlock_stage": 1,
		"cost_per_tile": 2.0,
		"vehicle_speed": 4.6,
		"access_factor": 0.74,
	},
	RoadTier.GRAVEL: {
		"name": "Gravel Road",
		"short": "GRAVEL",
		"unlock_stage": 2,
		"cost_per_tile": 7.0,
		"vehicle_speed": 6.2,
		"access_factor": 0.94,
	},
	RoadTier.PAVED: {
		"name": "Paved Asphalt",
		"short": "PAVED",
		"unlock_stage": 4,
		"cost_per_tile": 15.0,
		"vehicle_speed": 7.8,
		"access_factor": 1.10,
	},
}

const PARKING_LOTS := {
	ParkingLotKind.DIRT_PULL_OFF: {
		"tier": 1,
		"name": "Dirt Pull-Off",
		"short": "DIRT LOT",
		"subtitle": "2 wide bays (6x6m) + turnaround apron · Fits trucks & RVs",
		"unlock_stage": 1,
		"cost": 40.0,
		"spaces": 2,
		"grid_w": 3,
		"grid_d": 3,
	},
	ParkingLotKind.GRAVEL_LOT: {
		"tier": 2,
		"name": "Gravel Lot",
		"short": "GRAVEL LOT",
		"subtitle": "4 wide gravel bays (10x6m) + apron & lamp",
		"unlock_stage": 2,
		"cost": 140.0,
		"spaces": 4,
		"grid_w": 5,
		"grid_d": 3,
	},
	ParkingLotKind.PAVED_LOT: {
		"tier": 3,
		"name": "Paved Plaza Lot",
		"short": "PAVED LOT",
		"subtitle": "6 wide asphalt bays (14x6m) + sidewalk, curbs & lamps",
		"unlock_stage": 4,
		"cost": 320.0,
		"spaces": 6,
		"grid_w": 7,
		"grid_d": 3,
	},
}

const STAGES := [
	{
		"stage": 1,
		"title": "Desert Cart",
		"max_building_level": 2,
		"max_highway_turn_offs": 1,
		"max_parcels": 2,
		"next_requirement": "Build a 2-lane access road from Route 163 & a parking lot",
	},
	{
		"stage": 2,
		"title": "Trail Stop",
		"max_building_level": 2,
		"max_highway_turn_offs": 1,
		"max_parcels": 3,
		"next_requirement": "Run 2 connected stores & serve 4 visitors (or 6 gravel tiles)",
	},
	{
		"stage": 3,
		"title": "Desert Strip",
		"max_building_level": 3,
		"max_highway_turn_offs": 2,
		"max_parcels": 5,
		"next_requirement": "Run 4 connected stores & 4+ parking bays",
	},
	{
		"stage": 4,
		"title": "Oasis Hub",
		"max_building_level": 4,
		"max_highway_turn_offs": 2,
		"max_parcels": 8,
		"next_requirement": "Run 5 connected stores & 8+ Paved tiles (or 6 bays)",
	},
	{
		"stage": 5,
		"title": "Desert Resort",
		"max_building_level": 4,
		"max_highway_turn_offs": 3,
		"max_parcels": 12,
		"next_requirement": "Run 7 connected stores & 6+ parking bays",
	},
	{
		"stage": 6,
		"title": "Monument Outpost",
		"max_building_level": 5,
		"max_highway_turn_offs": 4,
		"max_parcels": 20,
		"next_requirement": "Flagship Monument Valley Outpost!",
	},
]

const BUSINESSES := {
	BusinessType.VENDOR_STALL: {
		"stage": 1,
		"category": StructureCategory.BUSINESS,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Roadside Cart & Stall",
		"short": "Drinks Cart",
		"subtitle": "Stage 1 · Cold drinks, snacks & postcards",
		"purchase_cost": 0.0,
		"base_income_per_min": 18.0,
		"upgrade_cost_base": 65.0,
		"upgrade_multiplier": 1.75,
		"max_level": 5,
		"grid_w": 2,
		"grid_d": 2,
		"prefers_scenic": false,
		"prefers_highway": true,
		"power_profile": {"base_kw": 0.0, "night_mult": 1.0, "supports_rooftop_solar": false},
		"water_need": 0.0,
		"stock_commodity": Commodity.DRINKS_SNACKS,
		"stock_capacity": 30.0,
		"stock_burn_per_min": 4.0,
		"inspector_tabs": ["overview", "staff", "stock"],
	},
	BusinessType.CONVENIENCE_STORE: {
		"stage": 2,
		"category": StructureCategory.BUSINESS,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Outpost Mart",
		"short": "Outpost Mart",
		"subtitle": "Stage 2 · Convenience store & road supplies",
		"purchase_cost": 140.0,
		"base_income_per_min": 48.0,
		"upgrade_cost_base": 110.0,
		"upgrade_multiplier": 1.78,
		"max_level": 5,
		"grid_w": 3,
		"grid_d": 3,
		"prefers_scenic": false,
		"prefers_highway": false,
		"power_profile": {"base_kw": 4.0, "night_mult": 1.15, "supports_rooftop_solar": true},
		"water_need": 1.0,
		"stock_commodity": Commodity.DRINKS_SNACKS,
		"stock_capacity": 60.0,
		"stock_burn_per_min": 7.0,
		"inspector_tabs": ["overview", "staff", "power", "stock"],
	},
	BusinessType.FOOD_STAND: {
		"stage": 3,
		"category": StructureCategory.BUSINESS,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Taco & Coffee Stand",
		"short": "Cafe Stand",
		"subtitle": "Stage 3 · Fresh street food & iced brews",
		"purchase_cost": 260.0,
		"base_income_per_min": 75.0,
		"upgrade_cost_base": 180.0,
		"upgrade_multiplier": 1.80,
		"max_level": 5,
		"grid_w": 2,
		"grid_d": 2,
		"prefers_scenic": false,
		"prefers_highway": false,
		"power_profile": {"base_kw": 3.0, "night_mult": 1.10, "supports_rooftop_solar": true},
		"water_need": 2.0,
		"stock_commodity": Commodity.FRESH_FOOD,
		"stock_capacity": 45.0,
		"stock_burn_per_min": 7.5,
		"inspector_tabs": ["overview", "staff", "power", "stock"],
	},
	BusinessType.DESERT_DINER: {
		"stage": 3,
		"category": StructureCategory.BUSINESS,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Route 163 Diner",
		"short": "Desert Diner",
		"subtitle": "Stage 3 · Streamlined Googie roadside diner",
		"purchase_cost": 520.0,
		"base_income_per_min": 140.0,
		"upgrade_cost_base": 320.0,
		"upgrade_multiplier": 1.82,
		"max_level": 5,
		"grid_w": 4,
		"grid_d": 3,
		"prefers_scenic": false,
		"prefers_highway": false,
		"power_profile": {"base_kw": 8.0, "night_mult": 1.35, "supports_rooftop_solar": true},
		"water_need": 3.0,
		"stock_commodity": Commodity.FRESH_FOOD,
		"stock_capacity": 70.0,
		"stock_burn_per_min": 10.0,
		"inspector_tabs": ["overview", "staff", "power", "stock"],
	},
	BusinessType.GAS_STATION: {
		"stage": 4,
		"category": StructureCategory.BUSINESS,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Canyon Fuel & Garage",
		"short": "Gas Station",
		"subtitle": "Stage 4 · Fuel pumps & highway repair bay",
		"purchase_cost": 900.0,
		"base_income_per_min": 220.0,
		"upgrade_cost_base": 520.0,
		"upgrade_multiplier": 1.84,
		"max_level": 5,
		"grid_w": 3,
		"grid_d": 3,
		"prefers_scenic": false,
		"prefers_highway": true,
		"power_profile": {"base_kw": 7.0, "night_mult": 1.25, "supports_rooftop_solar": true},
		"water_need": 1.0,
		"stock_commodity": Commodity.REFINED_FUEL,
		"stock_capacity": 80.0,
		"stock_burn_per_min": 11.0,
		"inspector_tabs": ["overview", "staff", "power", "stock"],
	},
	BusinessType.OASIS_PLAZA: {
		"stage": 5,
		"category": StructureCategory.SOCIAL,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Oasis Souvenir Plaza",
		"short": "Oasis Plaza",
		"subtitle": "Stage 5 · Plunge pool, palms & craft market",
		"purchase_cost": 1250.0,
		"base_income_per_min": 285.0,
		"upgrade_cost_base": 680.0,
		"upgrade_multiplier": 1.84,
		"max_level": 5,
		"grid_w": 3,
		"grid_d": 2,
		"prefers_scenic": true,
		"prefers_highway": false,
		"power_profile": {"base_kw": 5.0, "night_mult": 1.20, "supports_rooftop_solar": false},
		"water_need": 5.0,
		"stock_commodity": Commodity.DESERT_CRAFTS,
		"stock_capacity": 60.0,
		"stock_burn_per_min": 8.0,
		"inspector_tabs": ["overview", "staff", "power", "stock"],
	},
	BusinessType.DESERT_MOTEL: {
		"stage": 5,
		"category": StructureCategory.BUSINESS,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Red Rock Motel",
		"short": "Desert Motel",
		"subtitle": "Stage 5 · Adobe rooms & cozy desert cabins",
		"purchase_cost": 1650.0,
		"base_income_per_min": 360.0,
		"upgrade_cost_base": 850.0,
		"upgrade_multiplier": 1.86,
		"max_level": 5,
		"grid_w": 4,
		"grid_d": 3,
		"prefers_scenic": true,
		"prefers_highway": false,
		"power_profile": {"base_kw": 10.0, "night_mult": 1.60, "supports_rooftop_solar": true},
		"water_need": 4.0,
		"stock_commodity": Commodity.NONE,
		"stock_capacity": 0.0,
		"stock_burn_per_min": 0.0,
		"inspector_tabs": ["overview", "staff", "power"],
	},
	BusinessType.LOOKOUT_CAMP: {
		"stage": 6,
		"category": StructureCategory.SOCIAL,
		"max_instances": 1,
		"required_trait": ParcelTrait.NONE,
		"name": "Mesa Lookout & Camp",
		"short": "Lookout Camp",
		"subtitle": "Stage 6 · Water tower, tour desk & camp",
		"purchase_cost": 2800.0,
		"base_income_per_min": 520.0,
		"upgrade_cost_base": 1300.0,
		"upgrade_multiplier": 1.88,
		"max_level": 5,
		"grid_w": 4,
		"grid_d": 3,
		"prefers_scenic": true,
		"prefers_highway": false,
		"power_profile": {"base_kw": 4.0, "night_mult": 1.20, "supports_rooftop_solar": true},
		"water_need": 2.0,
		"stock_commodity": Commodity.DESERT_CRAFTS,
		"stock_capacity": 50.0,
		"stock_burn_per_min": 6.5,
		"inspector_tabs": ["overview", "staff", "power", "stock"],
	},
}

const DECORATIONS := [
	{"kind": DecorationKind.SAGUARO_CLUSTER, "category": StructureCategory.DECORATION, "name": "Cactus", "cost": 35.0, "bonus": "+4% Tips", "stage": 1, "rotatable": true},
	{"kind": DecorationKind.WOODEN_SIGNPOST, "category": StructureCategory.DECORATION, "name": "Signpost", "cost": 45.0, "bonus": "+8% Traffic", "stage": 1, "rotatable": true},
	{"kind": DecorationKind.PICNIC_SET, "category": StructureCategory.SOCIAL, "name": "Picnic", "cost": 55.0, "bonus": "+4% Tips", "stage": 2, "rotatable": true},
	{"kind": DecorationKind.DESERT_LAMP, "category": StructureCategory.DECORATION, "name": "Lantern", "cost": 75.0, "bonus": "+4% Tips", "stage": 4, "rotatable": true},
	{"kind": DecorationKind.CAMPFIRE_RING, "category": StructureCategory.SOCIAL, "name": "Campfire", "cost": 95.0, "bonus": "+4% Tips", "stage": 4, "rotatable": true},
]

const STAFF_ROLES := [
	{
		"id": "clerk",
		"name": "Counter Clerk",
		"unlock_level": 1,
		"cost_mult": 2.2,
		"min_cost": 35.0,
		"income_bonus": 0.25,
		"boost_tag": "+25% INCOME",
		"perk_short": "Auto-serves customers",
		"desc": "+25% Income · Auto-serves customers",
		"portrait": "res://assets/staff/staff_clerk.png",
		"accent": Color("4b9b95"),
		"shirt": Color("4b9b95"),
		"hat": Color("f2e5cc"),
	},
	{
		"id": "greeter",
		"name": "Porch Greeter",
		"unlock_level": 2,
		"cost_mult": 4.5,
		"min_cost": 80.0,
		"income_bonus": 0.35,
		"boost_tag": "+35% INCOME",
		"perk_short": "30% faster service",
		"desc": "+35% Income · 30% faster service",
		"portrait": "res://assets/staff/staff_greeter.png",
		"accent": Color("c88d26"),
		"shirt": Color("f4bf48"),
		"hat": Color("79543b"),
	},
	{
		"id": "manager",
		"name": "Shift Manager",
		"unlock_level": 3,
		"cost_mult": 9.0,
		"min_cost": 160.0,
		"income_bonus": 0.55,
		"boost_tag": "+55% INCOME",
		"perk_short": "+35% VIP visitor tips",
		"desc": "+55% Income · +35% VIP visitor tips",
		"portrait": "res://assets/staff/staff_manager.png",
		"accent": Color("c9533e"),
		"shirt": Color("c9533e"),
		"hat": Color("ddba87"),
	},
]

const BUSINESS_STAFF_OVERRIDES := {
	BusinessType.VENDOR_STALL: {
		"clerk": {"name": "Cart Vendor", "perk_short": "Auto-serves · Unlocks Auto-Restock"},
		"greeter": {"name": "Stock Runner", "perk_short": "30% faster · -15% snack burn", "perk_id": "stock_saver"},
		"manager": {"name": "Booth Manager", "perk_short": "+35% VIP roadside tips"},
	},
	BusinessType.CONVENIENCE_STORE: {
		"clerk": {"name": "Counter Clerk", "perk_short": "Auto-serves · Unlocks Auto-Restock"},
		"greeter": {"name": "Stock Runner", "perk_short": "30% faster · -15% stock burn", "perk_id": "stock_saver"},
		"manager": {"name": "Store Manager", "perk_short": "+35% VIP shopper tips"},
	},
	BusinessType.FOOD_STAND: {
		"clerk": {"name": "Line Cook", "perk_short": "Auto-cooks · Unlocks Auto-Restock"},
		"greeter": {"name": "Patio Server", "perk_short": "30% faster · +15% Picnic synergy", "perk_id": "picnic_synergy"},
		"manager": {"name": "Head Chef", "perk_short": "+35% VIP tips · -15% food burn", "perk_id": "stock_saver"},
	},
	BusinessType.DESERT_DINER: {
		"clerk": {"name": "Line Cook", "perk_short": "Auto-cooks · Unlocks Auto-Restock"},
		"greeter": {"name": "Patio Server", "perk_short": "30% faster · +15% Picnic synergy", "perk_id": "picnic_synergy"},
		"manager": {"name": "Head Chef", "perk_short": "+35% VIP tips · -15% food burn", "perk_id": "stock_saver"},
	},
	BusinessType.GAS_STATION: {
		"clerk": {"name": "Fuel Attendant", "perk_short": "Auto-pumps · Unlocks Auto-Restock"},
		"greeter": {"name": "Bay Mechanic", "perk_short": "30% faster · +20% Truck/RV repair tips", "perk_id": "repair_tips"},
		"manager": {"name": "Garage Chief", "perk_short": "+35% VIP tips · -15% fuel burn", "perk_id": "stock_saver"},
	},
	BusinessType.DESERT_MOTEL: {
		"clerk": {"name": "Night Clerk", "perk_short": "Auto-check-in · +20% Nighttime revenue", "perk_id": "night_boost"},
		"greeter": {"name": "Housekeeper", "perk_short": "30% faster · -20% water demand", "perk_id": "water_saver"},
		"manager": {"name": "Innkeeper", "perk_short": "+35% VIP overnight tips"},
	},
	BusinessType.OASIS_PLAZA: {
		"clerk": {"name": "Craft Vendor", "perk_short": "Auto-serves · Unlocks Auto-Restock"},
		"greeter": {"name": "Oasis Host", "perk_short": "30% faster · +15% Picnic synergy", "perk_id": "picnic_synergy"},
		"manager": {"name": "Plaza Curator", "perk_short": "+35% VIP tourist tips"},
	},
	BusinessType.LOOKOUT_CAMP: {
		"clerk": {"name": "Desk Ranger", "perk_short": "Auto-serves · Unlocks Auto-Restock"},
		"greeter": {"name": "Trail Guide", "perk_short": "30% faster · Scenic lookout tips", "perk_id": "picnic_synergy"},
		"manager": {"name": "Camp Outfitter", "perk_short": "+35% VIP explorer tips"},
	},
}

const OUTPOST_CREW := {
	CrewKind.GRID_TECH: {
		"id": "grid_tech",
		"name": "Grid Technician",
		"short": "Grid Tech",
		"stage": 2,
		"costs": [180.0, 320.0, 560.0],
		"wage_per_min": 4.0,
		"boost_by_level": [0.0, 0.12, 0.20, 0.30],
		"boost_label": "+%d%% Power Gen · -30%% Diesel Upkeep",
		"subtitle": "Patrols Solar, Wind & Batteries · Cleans panels & tunes turbines",
		"shirt": Color("e8b638"),
		"hat": Color("f8d84a"),
		"accent": Color("c88d26"),
	},
	CrewKind.PUMP_ENGINEER: {
		"id": "pump_engineer",
		"name": "Pump & Pipe Engineer",
		"short": "Pipe Eng",
		"stage": 3,
		"costs": [260.0, 460.0, 780.0],
		"wage_per_min": 6.0,
		"boost_by_level": [0.0, 0.15, 0.25, 0.38],
		"boost_label": "+%d%% Oil, Fuel & Water Output",
		"subtitle": "Patrols Oil Pumpjacks, Refinery & Wells · Boosts extraction",
		"shirt": Color("3b7ca5"),
		"hat": Color("f2e5cc"),
		"accent": Color("2e759e"),
	},
	CrewKind.LOGISTICS_RUNNER: {
		"id": "logistics_runner",
		"name": "Logistics Runner",
		"short": "Runner",
		"stage": 2,
		"costs": [200.0, 360.0, 620.0],
		"wage_per_min": 5.0,
		"boost_by_level": [0.0, 0.15, 0.25, 0.35],
		"boost_label": "+%d%% Farm/Craft · -10%% Wholesale",
		"subtitle": "Runs crates between Depot, Greenhouse, Workshop & Stores",
		"shirt": Color("b58b58"),
		"hat": Color("79543b"),
		"accent": Color("4b9b95"),
	},
}


static func staff_role_for_business(btype: int, base_role: Dictionary) -> Dictionary:
	var out := base_role.duplicate()
	var rid := str(base_role["id"])
	var ov_map: Dictionary = BUSINESS_STAFF_OVERRIDES.get(btype, {})
	if ov_map.has(rid):
		var ov: Dictionary = ov_map[rid]
		for k in ov.keys():
			out[k] = ov[k]
	return out


static func crew_action_cost(kind: int, cur_level: int) -> float:
	var costs: Array = OUTPOST_CREW[kind]["costs"]
	if cur_level < 0 or cur_level >= costs.size():
		return 0.0
	return float(costs[cur_level])


static func crew_boost_for_level(kind: int, level: int) -> float:
	var arr: Array = OUTPOST_CREW[kind]["boost_by_level"]
	return float(arr[clampi(level, 0, arr.size() - 1)])


static func staff_hire_cost(btype: int, role_spec: Dictionary) -> float:
	var base: float = float(BUSINESSES[btype]["base_income_per_min"])
	var raw := maxf(float(role_spec["min_cost"]), base * float(role_spec["cost_mult"]))
	return round(raw / 5.0) * 5.0


static func income_for_level(btype: int, level: int) -> float:
	if level <= 0:
		return 0.0
	var base: float = BUSINESSES[btype]["base_income_per_min"]
	return base * (1.0 + float(level - 1) * 0.72)


static func upgrade_cost_for_level(btype: int, current_level: int) -> float:
	var cost: float = BUSINESSES[btype]["upgrade_cost_base"]
	var mult: float = BUSINESSES[btype]["upgrade_multiplier"]
	for i in range(1, current_level):
		cost *= mult
	return round(cost)


static func next_parking_upgrade(kind: int) -> int:
	match kind:
		ParkingLotKind.DIRT_PULL_OFF:
			return ParkingLotKind.GRAVEL_LOT
		ParkingLotKind.GRAVEL_LOT:
			return ParkingLotKind.PAVED_LOT
		_:
			return -1


static func decoration_unlock_stage(kind: int) -> int:
	match kind:
		DecorationKind.SAGUARO_CLUSTER, DecorationKind.WOODEN_SIGNPOST:
			return 1
		DecorationKind.PICNIC_SET:
			return 2
		_:
			return 4


static func format_cash(amount: float) -> String:
	var v := int(round(amount))
	if abs(v) >= 1000000:
		return "$%.1fM" % (float(v) / 1000000.0)
	if abs(v) >= 10000:
		return "$%.1fK" % (float(v) / 1000.0)
	return "$%d" % v


const UTILITIES := {
	UtilityKind.WINDMILL: {
		"stage": 2,
		"category": StructureCategory.UTILITY,
		"name": "Desert Windmill",
		"short": "Windmill",
		"subtitle": "24/7 wind power · +40% on Wind Corridor parcels",
		"cost": 160.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 7.5,
		"is_solar": false,
		"wind_trait_mult": 1.40,
		"battery_kwh": 0.0,
		"max_io_kw": 0.0,
		"upkeep_per_min": 0.0,
		"noise_radius": 0,
		"anchor_y": 2.9,
	},
	UtilityKind.DIESEL_GEN: {
		"stage": 2,
		"category": StructureCategory.UTILITY,
		"name": "Diesel Generator",
		"short": "Diesel Gen",
		"subtitle": "Steady 24/7 power · $2/min fuel upkeep · Noisy",
		"cost": 120.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 11.0,
		"is_solar": false,
		"wind_trait_mult": 1.0,
		"battery_kwh": 0.0,
		"max_io_kw": 0.0,
		"upkeep_per_min": 2.0,
		"noise_radius": 3,
		"anchor_y": 1.65,
	},
	UtilityKind.SOLAR_ARRAY: {
		"stage": 3,
		"category": StructureCategory.UTILITY,
		"name": "Solar Array Farm",
		"short": "Solar Farm",
		"subtitle": "High daytime output (24 kW peak) · Pair with Batteries",
		"cost": 340.0,
		"grid_w": 3,
		"grid_d": 3,
		"base_kw": 24.0,
		"is_solar": true,
		"wind_trait_mult": 1.0,
		"battery_kwh": 0.0,
		"max_io_kw": 0.0,
		"upkeep_per_min": 0.0,
		"noise_radius": 0,
		"anchor_y": 1.55,
	},
	UtilityKind.BATTERY_BANK: {
		"stage": 3,
		"category": StructureCategory.UTILITY,
		"group": "power",
		"name": "Battery Bank",
		"short": "Battery Bank",
		"subtitle": "Stores 90 kWh daytime surplus for nighttime loads",
		"cost": 220.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 0.0,
		"is_solar": false,
		"wind_trait_mult": 1.0,
		"battery_kwh": 90.0,
		"max_io_kw": 20.0,
		"upkeep_per_min": 0.0,
		"noise_radius": 0,
		"anchor_y": 1.85,
	},
	UtilityKind.WATER_WELL: {
		"stage": 2,
		"category": StructureCategory.UTILITY,
		"group": "water",
		"name": "Desert Water Well",
		"short": "Water Well",
		"subtitle": "10 Water (18 on Aquifer) · Needs 3 kW power",
		"cost": 150.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 3.0,
		"water_output": 10.0,
		"aquifer_mult": 1.80,
		"water_radius": 2,
		"water_need": 0.0,
		"noise_radius": 0,
		"anchor_y": 2.40,
	},
	UtilityKind.WATER_TOWER: {
		"stage": 3,
		"category": StructureCategory.UTILITY,
		"group": "water",
		"name": "Pressurized Water Tower",
		"short": "Water Tower",
		"subtitle": "+4 Water pressure & 4-tile auto-link water hub",
		"cost": 210.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 0.0,
		"water_output": 4.0,
		"aquifer_mult": 1.0,
		"water_radius": 4,
		"water_need": 0.0,
		"noise_radius": 0,
		"anchor_y": 3.80,
	},
	UtilityKind.FREIGHT_DEPOT: {
		"stage": 2,
		"category": StructureCategory.INDUSTRIAL,
		"group": "supply",
		"name": "Freight Supply Depot",
		"short": "Freight Depot",
		"subtitle": "Unlocks Auto-Restock & -20% wholesale truck crates",
		"cost": 220.0,
		"grid_w": 3,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 2.0,
		"water_need": 0.0,
		"produces": Commodity.NONE,
		"prod_per_min": 0.0,
		"wholesale_discount": 0.20,
		"noise_radius": 0,
		"anchor_y": 2.25,
	},
	UtilityKind.OIL_PUMPJACK: {
		"stage": 3,
		"category": StructureCategory.INDUSTRIAL,
		"group": "supply",
		"required_trait": ParcelTrait.OIL_SEEP,
		"name": "Desert Oil Pumpjack",
		"short": "Oil Pumpjack",
		"subtitle": "Oil Seep only · 12 Crude/min · Needs 6 kW power",
		"cost": 280.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 6.0,
		"water_need": 0.0,
		"produces": Commodity.CRUDE_OIL,
		"prod_per_min": 12.0,
		"noise_radius": 3,
		"anchor_y": 2.35,
	},
	UtilityKind.MINI_REFINERY: {
		"stage": 4,
		"category": StructureCategory.INDUSTRIAL,
		"group": "supply",
		"name": "Mini Fuel Refinery",
		"short": "Fuel Refinery",
		"subtitle": "Refines Crude -> 14 Fuel/min · Fuels Gas & Diesel",
		"cost": 460.0,
		"grid_w": 3,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 8.0,
		"water_need": 2.0,
		"consumes": Commodity.CRUDE_OIL,
		"consume_per_min": 10.0,
		"produces": Commodity.REFINED_FUEL,
		"prod_per_min": 14.0,
		"noise_radius": 3,
		"anchor_y": 2.95,
	},
	UtilityKind.DESERT_GREENHOUSE: {
		"stage": 3,
		"category": StructureCategory.INDUSTRIAL,
		"group": "supply",
		"name": "Desert Greenhouse",
		"short": "Greenhouse",
		"subtitle": "Grows 12 Fresh Food/min for Cafe & Diner · Needs Water",
		"cost": 320.0,
		"grid_w": 3,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 4.0,
		"water_need": 3.0,
		"produces": Commodity.FRESH_FOOD,
		"prod_per_min": 12.0,
		"noise_radius": 0,
		"anchor_y": 2.05,
	},
	UtilityKind.CRAFT_WORKSHOP: {
		"stage": 4,
		"category": StructureCategory.INDUSTRIAL,
		"group": "supply",
		"name": "Desert Craft Workshop",
		"short": "Craft Studio",
		"subtitle": "Makes 10 Crafts/min for Oasis Plaza & Lookout Camp",
		"cost": 360.0,
		"grid_w": 2,
		"grid_d": 2,
		"base_kw": 0.0,
		"power_need_kw": 3.0,
		"water_need": 0.0,
		"produces": Commodity.DESERT_CRAFTS,
		"prod_per_min": 10.0,
		"noise_radius": 0,
		"anchor_y": 2.15,
	},
}

const POWER_LINES := {
	PowerLineKind.WOOD_POLE: {
		"stage": 2,
		"name": "Overhead Power Pole",
		"short": "Wood Pole",
		"subtitle": "Auto-strings wires up to 5 tiles · Cheap",
		"cost": 12.0,
		"span_tiles": 5,
		"anchor_y": 3.42,
		"scenic_penalty": 0.04,
	},
	PowerLineKind.STEEL_TOWER: {
		"stage": 4,
		"name": "Transmission Tower",
		"short": "Steel Tower",
		"subtitle": "Long-haul pylon (9-tile span) for remote farms",
		"cost": 30.0,
		"span_tiles": 9,
		"anchor_y": 5.45,
		"scenic_penalty": 0.06,
	},
	PowerLineKind.UNDERGROUND: {
		"stage": 2,
		"name": "Underground Conduit",
		"short": "Buried Wire",
		"subtitle": "Runs under roads & plazas · Zero scenic penalty",
		"cost": 18.0,
		"span_tiles": 1,
		"anchor_y": 0.05,
		"scenic_penalty": 0.0,
	},
}


static func rooftop_solar_cost(btype: int) -> float:
	var kw := business_power_demand_kw(btype, 1, false)
	return round(maxf(95.0, 75.0 + kw * 8.5) / 5.0) * 5.0


static func rooftop_solar_kw(btype: int) -> float:
	var spec: Dictionary = BUSINESSES.get(btype, {})
	if not bool(spec.get("power_profile", {}).get("supports_rooftop_solar", false)):
		return 0.0
	var base_kw := float(spec.get("power_profile", {}).get("base_kw", 0.0))
	return snappedf(maxf(4.5, base_kw * 0.85), 0.5)


static func make_runtime_bag(btype: int = -1) -> Dictionary:
	var cap := 0.0
	if btype >= 0 and BUSINESSES.has(btype):
		cap = float(BUSINESSES[btype].get("stock_capacity", 0.0))
	return {
		"power_ratio": 1.0,
		"power_supplied_kw": 0.0,
		"power_demand_kw": 0.0,
		"power_grid_id": -1,
		"water_ratio": 1.0,
		"water_supplied": 0.0,
		"water_demand": 0.0,
		"stock_units": cap,
		"stock_max": cap,
		"stock_ratio": 1.0,
		"auto_restock": false,
		"restock_in_transit": false,
		"roof_addons": [],
		"inventory": {},
		"price_tier": PriceTier.FAIR,
	}


static func commodity_spec(cid: int) -> Dictionary:
	return COMMODITIES.get(cid, COMMODITIES[Commodity.NONE])


static func price_tier_spec(tier: int) -> Dictionary:
	return PRICE_TIERS.get(tier, PRICE_TIERS[PriceTier.FAIR])


static func utility_group(ukind: int) -> String:
	return str(UTILITIES.get(ukind, {}).get("group", "power"))


static func business_power_demand_kw(btype: int, level: int, is_night: bool = false) -> float:
	var spec: Dictionary = BUSINESSES.get(btype, {})
	var prof: Dictionary = spec.get("power_profile", {})
	var base_kw := float(prof.get("base_kw", 0.0))
	if base_kw <= 0.0:
		return 0.0
	var lv_mult := 1.0 + float(maxi(0, level - 1)) * 0.25
	var night_mult := float(prof.get("night_mult", 1.0)) if is_night else 1.0
	return snappedf(base_kw * lv_mult * night_mult, 0.1)


static func business_inspector_tabs(btype: int) -> Array:
	var spec: Dictionary = BUSINESSES.get(btype, {})
	return spec.get("inspector_tabs", ["overview", "staff"])


static func parcel_trait_spec(trait_id: int) -> Dictionary:
	return PARCEL_TRAITS.get(trait_id, PARCEL_TRAITS[ParcelTrait.NONE])


static func max_decorations_for_parcels(owned_parcel_count: int) -> int:
	return maxi(16, owned_parcel_count * 6)
