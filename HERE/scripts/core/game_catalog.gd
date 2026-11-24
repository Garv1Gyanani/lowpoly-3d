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
enum WorldToolMode { PLAY, PAINT_ROAD, PLACE_BUILDING, PLACE_PARKING, PLACE_DECORATION, BUY_LAND }
enum VehicleKind { COMPACT_CAR, PICKUP_TRUCK, SUV, CAMPER_RV, TOURIST_VAN }
enum VehiclePhase { HIGHWAY_CRUISE, PULLING_IN, PARKED, BACKING_OUT, PULLING_OUT }
enum VisitorPhase { WALKING_TO_BUSINESS, SHOPPING, RETURNING_TO_CAR }
enum DecorationKind { SAGUARO_CLUSTER, WOODEN_SIGNPOST, PICNIC_SET, DESERT_LAMP, CAMPFIRE_RING }
enum OutpostPreset { FULL_CITY, STAGE_ONE_CAREER }

const ROAD_TIERS := {
	RoadTier.DIRT: {
		"name": "Dirt Track",
		"short": "DIRT",
		"unlock_stage": 1,
		"cost_per_tile": 5.0,
		"vehicle_speed": 4.2,
		"access_factor": 0.72,
	},
	RoadTier.GRAVEL: {
		"name": "Gravel Road",
		"short": "GRAVEL",
		"unlock_stage": 2,
		"cost_per_tile": 14.0,
		"vehicle_speed": 5.6,
		"access_factor": 0.92,
	},
	RoadTier.PAVED: {
		"name": "Paved Asphalt",
		"short": "PAVED",
		"unlock_stage": 4,
		"cost_per_tile": 30.0,
		"vehicle_speed": 7.2,
		"access_factor": 1.08,
	},
}

const PARKING_LOTS := {
	ParkingLotKind.DIRT_PULL_OFF: {
		"tier": 1,
		"name": "Dirt Pull-Off",
		"short": "DIRT LOT",
		"subtitle": "2 roomy bays (4x4m) · Fits trucks & RVs cleanly",
		"unlock_stage": 1,
		"cost": 40.0,
		"spaces": 2,
		"grid_w": 2,
		"grid_d": 2,
	},
	ParkingLotKind.GRAVEL_LOT: {
		"tier": 2,
		"name": "Gravel Lot",
		"short": "GRAVEL LOT",
		"subtitle": "4 gravel bays + lamp · Upgrade from Dirt Pull-Off",
		"unlock_stage": 2,
		"cost": 140.0,
		"spaces": 4,
		"grid_w": 3,
		"grid_d": 2,
	},
	ParkingLotKind.PAVED_LOT: {
		"tier": 3,
		"name": "Paved Plaza Lot",
		"short": "PAVED LOT",
		"subtitle": "6 striped asphalt bays + lamps · Maximum visitor flow",
		"unlock_stage": 4,
		"cost": 320.0,
		"spaces": 6,
		"grid_w": 4,
		"grid_d": 2,
	},
}

const STAGES := [
	{
		"stage": 1,
		"title": "Desert Cart",
		"max_building_level": 2,
		"max_highway_turn_offs": 1,
		"max_parcels": 2,
		"next_requirement": "Build an access road from Route 163 & a parking lot",
	},
	{
		"stage": 2,
		"title": "Trail Stop",
		"max_building_level": 2,
		"max_highway_turn_offs": 1,
		"max_parcels": 3,
		"next_requirement": "Run 2 connected stores & serve 4 visitors (or 3 gravel tiles)",
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
		"next_requirement": "Run 5 connected stores & 4+ Paved tiles (or 6 bays)",
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
	},
	BusinessType.CONVENIENCE_STORE: {
		"stage": 2,
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
	},
	BusinessType.FOOD_STAND: {
		"stage": 3,
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
	},
	BusinessType.DESERT_DINER: {
		"stage": 3,
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
	},
	BusinessType.GAS_STATION: {
		"stage": 4,
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
	},
	BusinessType.OASIS_PLAZA: {
		"stage": 5,
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
	},
	BusinessType.DESERT_MOTEL: {
		"stage": 5,
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
	},
	BusinessType.LOOKOUT_CAMP: {
		"stage": 6,
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
	},
}

const DECORATIONS := [
	{"kind": DecorationKind.SAGUARO_CLUSTER, "name": "Cactus", "cost": 35.0, "bonus": "+4% Tips", "stage": 1},
	{"kind": DecorationKind.WOODEN_SIGNPOST, "name": "Signpost", "cost": 45.0, "bonus": "+8% Traffic", "stage": 1},
	{"kind": DecorationKind.PICNIC_SET, "name": "Picnic", "cost": 55.0, "bonus": "+4% Tips", "stage": 2},
	{"kind": DecorationKind.DESERT_LAMP, "name": "Lantern", "cost": 75.0, "bonus": "+4% Tips", "stage": 4},
	{"kind": DecorationKind.CAMPFIRE_RING, "name": "Campfire", "cost": 95.0, "bonus": "+4% Tips", "stage": 4},
]


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
