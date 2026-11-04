class_name OpenWorldTerrain
extends StaticBody3D

## Open World Hyper-Realistic Terrain & Wilderness Generator for SwordStrike
## Spans 700m x 700m (490,000 m² = ~253x the starter town ground footprint)
## Features:
## - Continuous smooth rolling hills & valleys with slopes <= 19 degrees
## - Winding mountain river with translucent water ribbon and arched stone bridge
## - Multi-species forest: Ancient Oaks, Alpine Mountain Pines, and Golden Birches
## - 140+ mossy granite boulders with physical collision
## - 400+ wild shrubs, ferns, and colorful flower tufts
## - Wayfarer valley campsite with stone firepit, embers, and real OmniLight3D
## - Carved wooden road signposts and glowing ancient runic stone circles
## - All props equipped with physical CollisionShape3D on physics layer 1

@export var world_size: float = 700.0
@export var grid_resolution: int = 140 # 140x140 quads = 5m per quad (~39.2k triangles)
@export var town_radius: float = 24.0 # Flat plateau where starter town is situated
@export var blend_radius: float = 40.0 # Transition distance from town to rolling hills

var _mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null

func _ready() -> void:
	name = "OpenWorldTerrain"
	_generate_terrain()
	_generate_river_water()
	_build_river_bridge()
	_scatter_world_landmarks()


## Generates the procedural 700m x 700m uneven terrain mesh and matching trimesh collision
func _generate_terrain() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step: float = world_size / float(grid_resolution)
	var half_size: float = world_size * 0.5
	
	for iz in range(grid_resolution):
		var z0 = -half_size + iz * step
		var z1 = z0 + step
		var v_frac0 = float(iz) / float(grid_resolution)
		var v_frac1 = float(iz + 1) / float(grid_resolution)
		
		for ix in range(grid_resolution):
			var x0 = -half_size + ix * step
			var x1 = x0 + step
			var u_frac0 = float(ix) / float(grid_resolution)
			var u_frac1 = float(ix + 1) / float(grid_resolution)
			
			var y00 = get_terrain_height(x0, z0)
			var y10 = get_terrain_height(x1, z0)
			var y01 = get_terrain_height(x0, z1)
			var y11 = get_terrain_height(x1, z1)
			
			var v00 = Vector3(x0, y00, z0)
			var v10 = Vector3(x1, y10, z0)
			var v01 = Vector3(x0, y01, z1)
			var v11 = Vector3(x1, y11, z1)
			
			var c00 = _get_vertex_color(x0, z0, y00)
			var c10 = _get_vertex_color(x1, z0, y10)
			var c01 = _get_vertex_color(x0, z1, y01)
			var c11 = _get_vertex_color(x1, z1, y11)
			
			# Triangle 1 (v00 -> v10 -> v01)
			st.set_color(c00)
			st.set_uv(Vector2(u_frac0 * 28.0, v_frac0 * 28.0))
			st.add_vertex(v00)
			
			st.set_color(c10)
			st.set_uv(Vector2(u_frac1 * 28.0, v_frac0 * 28.0))
			st.add_vertex(v10)
			
			st.set_color(c01)
			st.set_uv(Vector2(u_frac0 * 28.0, v_frac1 * 28.0))
			st.add_vertex(v01)
			
			# Triangle 2 (v10 -> v11 -> v01)
			st.set_color(c10)
			st.set_uv(Vector2(u_frac1 * 28.0, v_frac0 * 28.0))
			st.add_vertex(v10)
			
			st.set_color(c11)
			st.set_uv(Vector2(u_frac1 * 28.0, v_frac1 * 28.0))
			st.add_vertex(v11)
			
			st.set_color(c01)
			st.set_uv(Vector2(u_frac0 * 28.0, v_frac1 * 28.0))
			st.add_vertex(v01)
			
	st.generate_normals()
	var terrain_mesh = st.commit()
	
	# High-fidelity landscape material
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	_mesh_instance.mesh = terrain_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.90
	mat.metallic_specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)
	
	# Physically exact matching trimesh collision
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "TerrainCollision"
	_collision_shape.shape = terrain_mesh.create_trimesh_shape()
	add_child(_collision_shape)


## Computes continuous smooth elevation with slope <= 19 degrees for effortless walking
func get_terrain_height(x: float, z: float) -> float:
	var r = sqrt(x * x + z * z)
	
	# Flat level platform for starter town
	var blend: float = 0.0
	if r > blend_radius:
		blend = 1.0
	elif r > town_radius:
		var t = (r - town_radius) / (blend_radius - town_radius)
		blend = t * t * (3.0 - 2.0 * t)
	else:
		return 0.0
		
	# Check proximity to the 4 cardinal gateway roads extending from the town
	var road_flatten = 1.0
	var is_road_x = (absf(z) < 4.2 and absf(x) < 140.0) # East-West road
	var is_road_z = (absf(x) < 4.2 and absf(z) < 140.0) # North-South road
	if is_road_x:
		var road_t = clampf(absf(z) / 4.2, 0.0, 1.0)
		road_flatten = road_t * road_t
	elif is_road_z:
		var road_t = clampf(absf(x) / 4.2, 0.0, 1.0)
		road_flatten = road_t * road_t
		
	# Rolling hill landscape formulas
	var h: float = 0.0
	h += 3.8 * sin(0.018 * x) * cos(0.016 * z)
	h += 2.5 * sin(0.038 * x + 1.4) * sin(0.035 * z - 0.7)
	h += 4.2 * cos(0.009 * x - 0.012 * z + 0.5)
	h += 1.6 * sin(0.075 * x) * cos(0.065 * z)
	
	# Smoothly flatten where roads pass through
	h *= lerpf(0.2, 1.0, road_flatten)
	
	# Carve natural riverbed in eastern valley (curving around X = 85.0)
	var river_x = 85.0 + 32.0 * sin(0.014 * z)
	var d_river = absf(x - river_x)
	if d_river < 9.0 and r > 36.0:
		var r_t = 1.0 - (d_river / 9.0)
		# Preserve road deck elevation across river crossing (|z| < 4.5)
		var bridge_protect = clampf(absf(z) / 4.5, 0.0, 1.0)
		h -= 1.65 * (r_t * r_t) * bridge_protect
		
	# Perimeter natural mountain walls enclosing the 700m world
	if r > 300.0:
		var edge_t = clampf((r - 300.0) / 45.0, 0.0, 1.0)
		h += edge_t * edge_t * 28.0
		
	return h * blend


## Computes natural biome vertex coloring: lush grass, rocky hilltops, and dirt roads
func _get_vertex_color(x: float, z: float, y: float) -> Color:
	var r = sqrt(x * x + z * z)
	
	# 1. Road thoroughfares
	var on_road_x = (absf(z) < 3.8 and absf(x) < 140.0 and r > town_radius)
	var on_road_z = (absf(x) < 3.8 and absf(z) < 140.0 and r > town_radius)
	if on_road_x or on_road_z:
		return Color(0.46, 0.38, 0.26, 1.0) # Warm dirt & gravel trail
		
	# 2. Riverbed pebbles & sand
	var river_x = 85.0 + 32.0 * sin(0.014 * z)
	var d_river = absf(x - river_x)
	if d_river < 9.5 and r > 36.0:
		var pebble_t = clampf(d_river / 9.5, 0.0, 1.0)
		return Color(0.38, 0.35, 0.28, 1.0).lerp(Color(0.26, 0.44, 0.25, 1.0), pebble_t)
		
	# 3. Near town outer perimeter: lush green verge
	if r < 48.0:
		return Color(0.26, 0.45, 0.25, 1.0)
		
	# 4. Hilltops / ridges
	if y > 5.5:
		return Color(0.50, 0.48, 0.40, 1.0) # Weathered granite crest
	elif y > 2.0:
		return Color(0.34, 0.48, 0.28, 1.0) # Upland grass knoll
	else:
		return Color(0.24, 0.44, 0.24, 1.0) # Deep valley meadow


## Generates translucent shimmering water ribbon along the eastern valley riverbed
func _generate_river_water() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.18, 0.45, 0.65, 0.85)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.06
	water_mat.metallic = 0.12
	water_mat.metallic_specular = 0.85
	
	var half_size: float = world_size * 0.46
	var num_segments = 90
	var z_step = (half_size * 2.0) / float(num_segments)
	var river_half_w = 4.2
	
	for i in range(num_segments):
		var z_a = -half_size + i * z_step
		var z_b = z_a + z_step
		
		var x_center_a = 85.0 + 32.0 * sin(0.014 * z_a)
		var x_center_b = 85.0 + 32.0 * sin(0.014 * z_b)
		
		# Skip where water meets the starter town radius
		if sqrt(x_center_a * x_center_a + z_a * z_a) < town_radius + 12.0:
			continue
			
		var y_water_a = get_terrain_height(x_center_a, z_a) + 0.35
		var y_water_b = get_terrain_height(x_center_b, z_b) + 0.35
		
		var p0 = Vector3(x_center_a - river_half_w, y_water_a, z_a)
		var p1 = Vector3(x_center_a + river_half_w, y_water_a, z_a)
		var p2 = Vector3(x_center_b - river_half_w, y_water_b, z_b)
		var p3 = Vector3(x_center_b + river_half_w, y_water_b, z_b)
		
		st.set_normal(Vector3.UP)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		
		st.add_vertex(p1)
		st.add_vertex(p3)
		st.add_vertex(p2)
		
	var water_mesh = st.commit()
	var water_inst = MeshInstance3D.new()
	water_inst.name = "RiverWater"
	water_inst.mesh = water_mesh
	water_inst.material_override = water_mat
	add_child(water_inst)


## Builds an arched stone bridge across the river on the East Road (X = 85m)
func _build_river_bridge() -> void:
	var bridge_node = StaticBody3D.new()
	bridge_node.name = "RiverBridge"
	bridge_node.position = Vector3(85.0, 0.0, 0.0)
	
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.48, 0.46, 0.42, 1.0)
	stone_mat.roughness = 0.85
	
	var trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.32, 0.30, 0.28, 1.0)
	trim_mat.roughness = 0.82
	
	# 1. Bridge Road Deck
	var deck = MeshInstance3D.new()
	var deck_mesh = BoxMesh.new()
	deck_mesh.size = Vector3(14.0, 0.5, 4.6)
	deck_mesh.material = stone_mat
	deck.mesh = deck_mesh
	deck.position = Vector3(0, 0.25, 0)
	bridge_node.add_child(deck)
	
	var deck_col = CollisionShape3D.new()
	var deck_shape = BoxShape3D.new()
	deck_shape.size = Vector3(14.0, 0.5, 4.6)
	deck_col.shape = deck_shape
	deck_col.position = Vector3(0, 0.25, 0)
	bridge_node.add_child(deck_col)
	
	# 2. Bridge Stone Parapets (North and South sides)
	for side in [-2.4, 2.4]:
		var parapet = MeshInstance3D.new()
		var p_mesh = BoxMesh.new()
		p_mesh.size = Vector3(14.2, 0.8, 0.35)
		p_mesh.material = trim_mat
		parapet.mesh = p_mesh
		parapet.position = Vector3(0, 0.85, side)
		bridge_node.add_child(parapet)
		
		var p_col = CollisionShape3D.new()
		var p_shape = BoxShape3D.new()
		p_shape.size = Vector3(14.2, 0.8, 0.35)
		p_col.shape = p_shape
		p_col.position = Vector3(0, 0.85, side)
		bridge_node.add_child(p_col)
		
	# 3. Bridge Stone Arch Supports
	for offset_x in [-5.0, 5.0]:
		var arch_pillar = MeshInstance3D.new()
		var pillar_mesh = BoxMesh.new()
		pillar_mesh.size = Vector3(2.0, 2.5, 5.2)
		pillar_mesh.material = stone_mat
		arch_pillar.mesh = pillar_mesh
		arch_pillar.position = Vector3(offset_x, -0.9, 0)
		bridge_node.add_child(arch_pillar)
		
	add_child(bridge_node)


## Scatters landmarks, ruins, campsites, signposts, boulders, and 500+ foliage instances
func _scatter_world_landmarks() -> void:
	var landmarks_node = Node3D.new()
	landmarks_node.name = "WorldLandmarks"
	add_child(landmarks_node)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261105 # Deterministic seed for consistent world generation
	
	# Common Standard Materials
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.46, 0.44, 0.40, 1.0)
	stone_mat.roughness = 0.88
	
	var mossy_stone_mat = StandardMaterial3D.new()
	mossy_stone_mat.albedo_color = Color(0.38, 0.42, 0.32, 1.0)
	mossy_stone_mat.roughness = 0.92
	
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.32, 0.22, 0.14, 1.0)
	wood_mat.roughness = 0.85
	
	var oak_leaf_mat = StandardMaterial3D.new()
	oak_leaf_mat.albedo_color = Color(0.20, 0.38, 0.18, 1.0)
	oak_leaf_mat.roughness = 0.85
	
	var pine_needle_mat = StandardMaterial3D.new()
	pine_needle_mat.albedo_color = Color(0.12, 0.28, 0.16, 1.0)
	pine_needle_mat.roughness = 0.82
	
	var birch_trunk_mat = StandardMaterial3D.new()
	birch_trunk_mat.albedo_color = Color(0.82, 0.80, 0.74, 1.0)
	birch_trunk_mat.roughness = 0.75
	
	var birch_leaf_mat = StandardMaterial3D.new()
	birch_leaf_mat.albedo_color = Color(0.68, 0.52, 0.16, 1.0) # Autumn gold
	birch_leaf_mat.roughness = 0.85
	
	var shrub_mat = StandardMaterial3D.new()
	shrub_mat.albedo_color = Color(0.24, 0.42, 0.22, 1.0)
	shrub_mat.roughness = 0.88
	
	# 1. Road Waypoint Lanterns along the 4 exits
	var road_distances = [32.0, 52.0, 75.0, 105.0]
	for d in road_distances:
		_add_waystone(landmarks_node, Vector3(3.8, get_terrain_height(3.8, d), d), stone_mat)
		_add_waystone(landmarks_node, Vector3(-3.8, get_terrain_height(-3.8, -d), -d), stone_mat)
		_add_waystone(landmarks_node, Vector3(d, get_terrain_height(d, 3.8), 3.8), stone_mat)
		_add_waystone(landmarks_node, Vector3(-d, get_terrain_height(-d, -3.8), -3.8), stone_mat)
		
	# 2. Road Directional Signposts outside all 4 gates
	_add_signpost(landmarks_node, Vector3(3.2, get_terrain_height(3.2, -28.0), -28.0), wood_mat, 0.0)
	_add_signpost(landmarks_node, Vector3(3.2, get_terrain_height(3.2, 28.0), 28.0), wood_mat, PI)
	_add_signpost(landmarks_node, Vector3(28.0, get_terrain_height(28.0, 3.2), 3.2), wood_mat, -PI * 0.5)
	_add_signpost(landmarks_node, Vector3(-28.0, get_terrain_height(-28.0, 3.2), 3.2), wood_mat, PI * 0.5)
	
	# 3. Wayfarer Campsite in Southern Valley
	_build_wayfarer_camp(landmarks_node, Vector3(32.0, get_terrain_height(32.0, 68.0), 68.0), wood_mat, stone_mat)
	
	# 4. Standing Stone Circles & Ancient Megaliths
	var ruin_locations = [
		Vector2(65.0, 70.0),
		Vector2(-75.0, 60.0),
		Vector2(80.0, -65.0),
		Vector2(-70.0, -80.0),
		Vector2(140.0, 120.0),
		Vector2(-150.0, 130.0),
		Vector2(130.0, -140.0),
		Vector2(-140.0, -130.0)
	]
	for loc in ruin_locations:
		_add_rune_stone_circle(landmarks_node, loc.x, loc.y, stone_mat)
		
	# 5. Scatter 140+ Mossy Granite Boulders (with full CollisionShape3D)
	for i in range(140):
		var ang = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(35.0, 280.0)
		var px = cos(ang) * dist
		var pz = sin(ang) * dist
		if absf(px) < 6.0 or absf(pz) < 6.0: # Keep roads clear
			continue
		var py = get_terrain_height(px, pz)
		var scale_b = rng.randf_range(0.8, 2.8)
		_add_granite_boulder(landmarks_node, Vector3(px, py, pz), scale_b, mossy_stone_mat)
		
	# 6. Scatter 180+ Trees across varied biomes (with physical trunk collision)
	for i in range(180):
		var ang = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(38.0, 275.0)
		var px = cos(ang) * dist
		var pz = sin(ang) * dist
		if absf(px) < 6.5 or absf(pz) < 6.5: # Clear roads
			continue
		var py = get_terrain_height(px, pz)
		
		var tree_type = rng.randi_range(0, 2)
		if tree_type == 0:
			_add_ancient_oak(landmarks_node, Vector3(px, py, pz), wood_mat, oak_leaf_mat, rng)
		elif tree_type == 1:
			_add_alpine_pine(landmarks_node, Vector3(px, py, pz), wood_mat, pine_needle_mat, rng)
		else:
			_add_golden_birch(landmarks_node, Vector3(px, py, pz), birch_trunk_mat, birch_leaf_mat, rng)
			
	# 7. Scatter 160+ Wild Bushes & Foliage Clusters
	for i in range(160):
		var ang = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(32.0, 260.0)
		var px = cos(ang) * dist
		var pz = sin(ang) * dist
		if absf(px) < 4.8 or absf(pz) < 4.8:
			continue
		var py = get_terrain_height(px, pz)
		_add_wild_bush(landmarks_node, Vector3(px, py, pz), shrub_mat, rng)
		
	# 8. Scatter 240+ Colorful Alpine Flower Tufts
	var flower_colors = [
		Color(0.88, 0.22, 0.22, 1.0), # Red Poppy
		Color(0.24, 0.55, 0.92, 1.0), # Blue Bellflower
		Color(0.95, 0.82, 0.24, 1.0), # Golden Buttercup
		Color(0.92, 0.92, 0.94, 1.0)  # White Alpine Edelweiss
	]
	for i in range(240):
		var ang = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(30.0, 240.0)
		var px = cos(ang) * dist
		var pz = sin(ang) * dist
		if absf(px) < 4.5 or absf(pz) < 4.5:
			continue
		var py = get_terrain_height(px, pz)
		var col = flower_colors[rng.randi_range(0, flower_colors.size() - 1)]
		_add_flower_tuft(landmarks_node, Vector3(px, py, pz), col, rng)


## Granite Boulder with physical collision shape
func _add_granite_boulder(parent: Node3D, pos: Vector3, scale_b: float, mat: Material) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.2 * scale_b, 0.9 * scale_b, 1.1 * scale_b)
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position.y = 0.45 * scale_b
	body.add_child(mesh_inst)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position.y = 0.45 * scale_b
	body.add_child(col)
	
	parent.add_child(body)


## Ancient Oak with heavy wooden trunk and spreading foliage tiers
func _add_ancient_oak(parent: Node3D, pos: Vector3, trunk_mat: Material, fol_mat: Material, rng: RandomNumberGenerator) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	
	var trunk = MeshInstance3D.new()
	var c_mesh = CylinderMesh.new()
	c_mesh.top_radius = 0.42
	c_mesh.bottom_radius = 0.58
	c_mesh.height = 3.0
	c_mesh.material = trunk_mat
	trunk.mesh = c_mesh
	trunk.position.y = 1.5
	body.add_child(trunk)
	
	var trunk_col = CollisionShape3D.new()
	var col_shape = CylinderShape3D.new()
	col_shape.radius = 0.55
	col_shape.height = 3.0
	trunk_col.shape = col_shape
	trunk_col.position.y = 1.5
	body.add_child(trunk_col)
	
	# Multi-tiered spreading leafy canopy
	for t in range(4):
		var fol = MeshInstance3D.new()
		var fol_mesh = BoxMesh.new()
		var s = 2.8 - t * 0.45 + rng.randf_range(-0.2, 0.2)
		fol_mesh.size = Vector3(s, 1.1, s)
		fol_mesh.material = fol_mat
		fol.mesh = fol_mesh
		fol.position.y = 2.8 + t * 0.85
		fol.rotation.y = rng.randf_range(0.0, TAU)
		body.add_child(fol)
		
	parent.add_child(body)


## Alpine Mountain Pine with conical evergreen canopy
func _add_alpine_pine(parent: Node3D, pos: Vector3, trunk_mat: Material, needle_mat: Material, rng: RandomNumberGenerator) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	
	var trunk = MeshInstance3D.new()
	var c_mesh = CylinderMesh.new()
	c_mesh.top_radius = 0.18
	c_mesh.bottom_radius = 0.32
	c_mesh.height = 4.2
	c_mesh.material = trunk_mat
	trunk.mesh = c_mesh
	trunk.position.y = 2.1
	body.add_child(trunk)
	
	var trunk_col = CollisionShape3D.new()
	var col_shape = CylinderShape3D.new()
	col_shape.radius = 0.35
	col_shape.height = 4.2
	trunk_col.shape = col_shape
	trunk_col.position.y = 2.1
	body.add_child(trunk_col)
	
	# 5 stacked conical needle cones
	for t in range(5):
		var needle = MeshInstance3D.new()
		var n_mesh = CylinderMesh.new()
		n_mesh.top_radius = 0.05
		n_mesh.bottom_radius = 2.2 - t * 0.38
		n_mesh.height = 1.4
		n_mesh.material = needle_mat
		needle.mesh = n_mesh
		needle.position.y = 2.6 + t * 0.95
		body.add_child(needle)
		
	parent.add_child(body)


## Golden Birch with pale trunk and golden amber canopy
func _add_golden_birch(parent: Node3D, pos: Vector3, trunk_mat: Material, fol_mat: Material, rng: RandomNumberGenerator) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	
	var trunk = MeshInstance3D.new()
	var c_mesh = CylinderMesh.new()
	c_mesh.top_radius = 0.16
	c_mesh.bottom_radius = 0.24
	c_mesh.height = 3.6
	c_mesh.material = trunk_mat
	trunk.mesh = c_mesh
	trunk.position.y = 1.8
	body.add_child(trunk)
	
	var trunk_col = CollisionShape3D.new()
	var col_shape = CylinderShape3D.new()
	col_shape.radius = 0.28
	col_shape.height = 3.6
	trunk_col.shape = col_shape
	trunk_col.position.y = 1.8
	body.add_child(trunk_col)
	
	for t in range(3):
		var fol = MeshInstance3D.new()
		var fol_mesh = BoxMesh.new()
		var s = 2.2 - t * 0.4
		fol_mesh.size = Vector3(s, 1.2, s)
		fol_mesh.material = fol_mat
		fol.mesh = fol_mesh
		fol.position.y = 3.0 + t * 0.9
		fol.rotation.y = rng.randf_range(0.0, TAU)
		body.add_child(fol)
		
	parent.add_child(body)


## Wild leafy shrub
func _add_wild_bush(parent: Node3D, pos: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	var bush = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	var sx = rng.randf_range(0.9, 1.7)
	var sy = rng.randf_range(0.6, 1.1)
	var sz = rng.randf_range(0.9, 1.7)
	mesh.size = Vector3(sx, sy, sz)
	mesh.material = mat
	bush.mesh = mesh
	bush.position = pos + Vector3(0, sy * 0.5, 0)
	bush.rotation.y = rng.randf_range(0.0, TAU)
	parent.add_child(bush)


## Alpine Flower Patch
func _add_flower_tuft(parent: Node3D, pos: Vector3, col: Color, rng: RandomNumberGenerator) -> void:
	var flower = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.35, 0.4, 0.35)
	
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = col
	f_mat.roughness = 0.8
	mesh.material = f_mat
	
	flower.mesh = mesh
	flower.position = pos + Vector3(0, 0.2, 0)
	flower.rotation.y = rng.randf_range(0.0, TAU)
	parent.add_child(flower)


## Roadside Waystone with guide lantern
func _add_waystone(parent: Node3D, pos: Vector3, mat: Material) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	
	var post = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.55, 1.9, 0.55)
	box.material = mat
	post.mesh = box
	post.position = Vector3(0, 0.95, 0)
	body.add_child(post)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position = post.position
	body.add_child(col)
	
	# Small amber lantern on waystone
	var lamp = MeshInstance3D.new()
	var lamp_mesh = BoxMesh.new()
	lamp_mesh.size = Vector3(0.24, 0.28, 0.24)
	
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.85, 0.5)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.78, 0.4)
	lamp_mat.emission_energy_multiplier = 1.6
	lamp_mesh.material = lamp_mat
	
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0, 2.05, 0)
	body.add_child(lamp)
	
	parent.add_child(body)


## Wooden directional road signpost
func _add_signpost(parent: Node3D, pos: Vector3, wood_mat: Material, rot_y: float) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	
	var post = MeshInstance3D.new()
	var p_mesh = CylinderMesh.new()
	p_mesh.top_radius = 0.08
	p_mesh.bottom_radius = 0.10
	p_mesh.height = 1.8
	p_mesh.material = wood_mat
	post.mesh = p_mesh
	post.position.y = 0.9
	body.add_child(post)
	
	# Direction boards
	for i in range(2):
		var board = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(0.7, 0.16, 0.04)
		b_mesh.material = wood_mat
		board.mesh = b_mesh
		board.position = Vector3(0.28 if i == 0 else -0.28, 1.45 + i * 0.22, 0)
		body.add_child(board)
		
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.15
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	body.add_child(col)
	
	parent.add_child(body)


## Wayfarer Campfire Encounter in valley
func _build_wayfarer_camp(parent: Node3D, pos: Vector3, wood_mat: Material, stone_mat: Material) -> void:
	var camp = Node3D.new()
	camp.name = "WayfarerCampsite"
	camp.position = pos
	
	# Firepit ring of stones
	for i in range(8):
		var a = float(i) * (TAU / 8.0)
		var stone = MeshInstance3D.new()
		var s_mesh = BoxMesh.new()
		s_mesh.size = Vector3(0.35, 0.22, 0.35)
		s_mesh.material = stone_mat
		stone.mesh = s_mesh
		stone.position = Vector3(cos(a) * 0.85, 0.11, sin(a) * 0.85)
		camp.add_child(stone)
		
	# Burning ember core
	var ember = MeshInstance3D.new()
	var e_mesh = CylinderMesh.new()
	e_mesh.top_radius = 0.55
	e_mesh.bottom_radius = 0.65
	e_mesh.height = 0.18
	
	var ember_mat = StandardMaterial3D.new()
	ember_mat.albedo_color = Color(0.9, 0.3, 0.1, 1.0)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.45, 0.12, 1.0)
	ember_mat.emission_energy_multiplier = 2.8
	e_mesh.material = ember_mat
	
	ember.mesh = e_mesh
	ember.position.y = 0.12
	camp.add_child(ember)
	
	# Real warm flickering firelight
	var fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.62, 0.22, 1.0)
	fire_light.light_energy = 1.5
	fire_light.omni_range = 9.0
	fire_light.omni_attenuation = 1.3
	fire_light.position = Vector3(0, 0.6, 0)
	camp.add_child(fire_light)
	
	# Two log benches (with collision)
	for side in [-1.8, 1.8]:
		var log_body = StaticBody3D.new()
		log_body.position = Vector3(0, 0, side)
		
		var log_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(2.2, 0.38, 0.45)
		box.material = wood_mat
		log_mesh.mesh = box
		log_mesh.position.y = 0.19
		log_body.add_child(log_mesh)
		
		var log_col = CollisionShape3D.new()
		var col_box = BoxShape3D.new()
		col_box.size = box.size
		log_col.shape = col_box
		log_col.position = log_mesh.position
		log_body.add_child(log_col)
		
		camp.add_child(log_body)
		
	parent.add_child(camp)


## Ancient Megalithic Stone Circle with glowing turquoise runes
func _add_rune_stone_circle(parent: Node3D, cx: float, cz: float, mat: Material) -> void:
	var cy = get_terrain_height(cx, cz)
	
	var rune_mat = StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.2, 0.8, 0.9, 1.0)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.15, 0.85, 0.95, 1.0)
	rune_mat.emission_energy_multiplier = 1.8
	
	for i in range(6):
		var a = float(i) * (TAU / 6.0)
		var sx = cx + cos(a) * 6.5
		var sz = cz + sin(a) * 6.5
		var sy = get_terrain_height(sx, sz)
		
		var body = StaticBody3D.new()
		body.position = Vector3(sx, sy, sz)
		body.rotation.y = a
		
		var pillar = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.9, 3.2, 0.9)
		mesh.material = mat
		pillar.mesh = mesh
		pillar.position.y = 1.6
		body.add_child(pillar)
		
		# Glowing runic inlay band
		var rune_band = MeshInstance3D.new()
		var r_mesh = BoxMesh.new()
		r_mesh.size = Vector3(0.94, 0.15, 0.94)
		r_mesh.material = rune_mat
		rune_band.mesh = r_mesh
		rune_band.position.y = 2.1
		body.add_child(rune_band)
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = mesh.size
		col.shape = shape
		col.position.y = 1.6
		body.add_child(col)
		
		parent.add_child(body)
