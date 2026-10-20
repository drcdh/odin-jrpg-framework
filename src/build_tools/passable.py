TILESET_TERRAIN_PASSABLE = [
	[0,0,0,0],
	[0,0,0,0],
	[0,0,0,0],
	[1,1,1,1],
]

TILESET_TOWN_PASSABLE = [
	[1,1,1,1,1,1],
	[1,1,1,1,1,1],
	[1,1,1,1,1,1],
	[1,1,1,1,1,1],
	[1,1,1,0,0,0],
	[0,0,0,0,0,0],
]

TILESET_OVERWORLD_PASSABLE = [
	[3,3,3,2,2,2,2,0,0],
	[3,3,3,2,2,2,2,0,0],
	[3,3,3,2,2,2,2,1,1],
	[2,2,2,0,0,2,2,3,0],
	[2,2,2,0,0,0,0,0,0],
	[2,2,2,0,0,0,0,0,0],
	[2,2,2,0,0,0,0,0,0],
]

TILESET_OVERWORLD_PRIMERA_PASSABLE = [
	[1,1,1],
	[0,0,0],
	[1,0,1],
]

TILESET_CAVE_PASSABLE = [
	[1,1,1,1,1],
	[1,0,0,0,1],
	[1,1,1,1,1],
	[1,1,1,1,1],
]

TILESET_INDOORS_PASSABLE = [
	[1,1,1,1,1],
	[0,0,0,0,0],
	[1,1,1,1,1],
	[1,1,1,1,1],
	[0,0,0,0,1],
	[1,0,0,0,1],
	[1,0,0,0,0],
]

TILESET_FARM_PASSABLE = [
	[1,1,1,1,1],
	[1,1,1,1,1],
	[1,1,1,1,0],
	[1,1,1,1,0],
]

TILESET_FFII_ALTRIA_PASSABLE = [
	[0,0,1,1,1,1],
	[0,0,1,1,1,0],
	[1,1,0,1,1,1],
	[1,0,0,1,1,1],
	[0,0,0,0,1,1],
	[0,1,1,1,1,1],
	[1,1,1,1,1,1],
]

def tile_passibility(t, tileset_firstgids):
	i_ts = len(tileset_firstgids) - 1
	while i_ts >= 0 and t < tileset_firstgids[i_ts][1]:
		i_ts -= 1
		# t = t - tileset_firstgids[i_ts][1] + 1
	tsp = globals()[tileset_firstgids[i_ts][0].upper() + "_PASSABLE"]
	# t -= 1
	t -= tileset_firstgids[i_ts][1]
	j, i = t//len(tsp[0]), t%len(tsp[0])
	p = tsp[j][i]
	return p

def process(layers, tileset_firstgids):
	h, w = len(layers[0][1]), len(layers[0][1][0])
	p = [[0 for _ in range(w)] for _ in range(h)]
	for name, layer in layers:
		if pass_override := name.startswith("Passable"):
			print(f"found passable layer {name}")
			continue
		for i in range(w):
			for j in range(h):
					t = layer[j][i]
					if t <= 0: continue
					p[j][i] |= tile_passibility(t, tileset_firstgids)
					# if pass_override: p[j][i] = 0
	return p
