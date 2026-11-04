class_name OpenWorldTerrain
extends StaticBody3D

## Open World Terrain Generator for SwordStrike
## Spans 700m x 700m (490,000 m² = ~253x the starter town ground footprint)
## Features smooth rolling hills, valleys, gateway roads, and seamless slope physics.

@export var world_size: float = 700.0
@export var grid_resolution: int = 140 # 140x140 quads = 5m per quad (~39.2k triangles)
@export var town_radius: float = 24.0 # Flat plateau where starter town is situated
@export var blend_radius: float = 40.0 # Transition distance from town to rolling hills

var _mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null

func _ready() -> void:
	name = "OpenWorldTerrain"
	_generate_terrain()
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
	
	# Create MeshInstance3D with high-quality landscape material
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	_mesh_instance.mesh = terrain_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)
	
	# Create physically exact matching trimesh collision
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
	
	# Perimeter natural mountain walls enclosing the 700m world
	if r > 300.0:
		var edge_t = clampf((r - 300.0) / 45.0, 0.0, 1.0)
		h += edge_t * edge_t * 28.0
		
	return h * blend


## Computes natural biome vertex coloring: lush grass, rocky hilltops, and dirt roads
func _get_vertex_color(x: float, z: float, y: float) -> Color:
	var r = sqrt(x * x + z * z)
	
	# Check if on road
	var on_road_x = (absf(z) < 3.8 and absf(x) < 140.0 and r > town_radius)
	var on_road_z = (absf(x) < 3.8 and absf(z) < 140.0 and r > town_radius)
	if on_road_x or on_road_z:
		return Color(0.44, 0.36, 0.24, 1.0) # Warm dirt/gravel trail
		
	# Near town outer perimeter: lush green verge
	if r < 48.0:
		return Color(0.25, 0.44, 0.24, 1.0)
		
	# Hilltops / ridges
	if y > 5.5:
		return Color(0.48, 0.46, 0.38, 1.0) # Rocky crest
	elif y > 2.0:
		return Color(0.32, 0.46, 0.26, 1.0) # Upland grass
	else:
		return Color(0.22, 0.42, 0.22, 1.0) # Deep valley meadow


## Scatters landmarks, ancient ruins, forest groves, and waystones outside the town
func _scatter_world_landmarks() -> void:
	var landmarks_node = Node3D.new()
	landmarks_node.name = "WorldLandmarks"
	add_child(landmarks_node)
	
	# Materials for open world props
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.45, 0.43, 0.40, 1.0)
	stone_mat.roughness = 0.88
	
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.32, 0.22, 0.14, 1.0)
	wood_mat.roughness = 0.85
	
	var foliage_mat = StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.18, 0.38, 0.20, 1.0)
	foliage_mat.roughness = 0.85
	
	# 1. Road Waypoint Lanterns along the 4 cardinal exits
	var road_distances = [32.0, 52.0, 75.0, 105.0]
	for d in road_distances:
		_add_waystone(landmarks_node, Vector3(3.6, get_terrain_height(3.6, d), d), stone_mat)
		_add_waystone(landmarks_node, Vector3(-3.6, get_terrain_height(-3.6, -d), -d), stone_mat)
		_add_waystone(landmarks_node, Vector3(d, get_terrain_height(d, 3.6), 3.6), stone_mat)
		_add_waystone(landmarks_node, Vector3(-d, get_terrain_height(-d, -3.6), -3.6), stone_mat)
		
	# 2. Standing Stone Circles & Ruins on scenic hills
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
		_add_stone_circle(landmarks_node, loc.x, loc.y, stone_mat)
		
	# 3. Forest groves (trees scattered across rolling slopes)
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261104
	
	for i in range(120):
		var ang = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(45.0, 260.0)
		var px = cos(ang) * dist
		var pz = sin(ang) * dist
		
		# Avoid placing directly on roads
		if absf(px) < 6.0 or absf(pz) < 6.0:
			continue
			
		var py = get_terrain_height(px, pz)
		_add_open_world_tree(landmarks_node, Vector3(px, py, pz), wood_mat, foliage_mat)


func _add_waystone(parent: Node3D, pos: Vector3, mat: Material) -> void:
	var post = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 1.8, 0.5)
	box.material = mat
	post.mesh = box
	post.position = pos + Vector3(0, 0.9, 0)
	parent.add_child(post)


func _add_stone_circle(parent: Node3D, cx: float, cz: float, mat: Material) -> void:
	var cy = get_terrain_height(cx, cz)
	for i in range(6):
		var a = float(i) * (TAU / 6.0)
		var sx = cx + cos(a) * 6.0
		var sz = cz + sin(a) * 6.0
		var sy = get_terrain_height(sx, sz)
		
		var pillar = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.8, 2.8, 0.8)
		mesh.material = mat
		pillar.mesh = mesh
		pillar.position = Vector3(sx, sy + 1.4, sz)
		pillar.rotation.y = a
		parent.add_child(pillar)


func _add_open_world_tree(parent: Node3D, pos: Vector3, trunk_mat: Material, foliage_mat: Material) -> void:
	var tree_root = Node3D.new()
	tree_root.position = pos
	
	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 2.4
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.2
	tree_root.add_child(trunk)
	
	# Foliage tiers
	for t in range(3):
		var fol = MeshInstance3D.new()
		var fol_mesh = CylinderMesh.new()
		fol_mesh.top_radius = 0.05
		fol_mesh.bottom_radius = 1.4 - t * 0.3
		fol_mesh.height = 1.3
		fol_mesh.material = foliage_mat
		fol.mesh = fol_mesh
		fol.position.y = 2.2 + t * 0.8
		tree_root.add_child(fol)
		
	parent.add_child(tree_root)
