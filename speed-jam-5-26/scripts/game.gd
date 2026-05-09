extends Node2D

# ---------------------------------------------------------
# CONFIG
# ---------------------------------------------------------
const START_ORGANISMS := 100
const MAX_ORGANISMS := 100
const MAX_TENTACLES_PER_ORG := 5

const TENTACLE_SPEED := 1
const MAX_TENTACLE_LENGTH := 110.0
const TIP_COLLISION_RADIUS := 10.0

var organisms = []
var frame = 0

# ---------------------------------------------------------
# BLOB
# ---------------------------------------------------------
var blob_pos = Vector2(500, 500)
var blob_dir = Vector2(1, 0)
var blob_speed = 3
var blob_radius = 50.0

var blob_tentacles = []

# ---------------------------------------------------------
# EXPLOSIONS
# ---------------------------------------------------------
var explosions = []


# ---------------------------------------------------------
# SETUP
# ---------------------------------------------------------
func _ready():
	randomize()
	_spawn_initial()
	set_process(true)


func _spawn_initial():
	var size = get_viewport_rect().size
	for i in range(START_ORGANISMS):
		organisms.append({
			"pos": Vector2(randf_range(0, size.x), randf_range(0, size.y)),
			"color": Color.from_hsv(randf(), 0.8, 1.0),
			"radius": 18.0,
			"growth": randf_range(0.7, 3.3),
			"team": i,
			"tentacles": [],
			"dead": false,
			"life": randi_range(300, 350)
		})


# ---------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------
func _process(delta):
	frame += 1
	_update_lifespans()
	_update_blob()
	_update_blob_tentacles()
	_update_tentacles()
	_update_explosions()
	_cleanup()
	queue_redraw()


# ---------------------------------------------------------
# LIFESPAN UPDATE
# ---------------------------------------------------------
func _update_lifespans():
	for org in organisms:
		if org["dead"]:
			continue

		org["life"] -= 1

		if org["life"] <= 0:
			org["dead"] = true
			explosions.append({
				"pos": org["pos"],
				"color": org["color"],
				"frame": 0
			})


# ---------------------------------------------------------
# BLOB UPDATE (CHASE ADDED)
# ---------------------------------------------------------
func _update_blob():
	# random wiggle
	if randi() % 40 == 0:
		var angle = randf() * TAU
		blob_dir = Vector2(cos(angle), sin(angle))

	# --- CHASE NEAREST ORGANISM ---
	var nearest = null
	var nearest_dist = INF

	for org in organisms:
		if org["dead"]:
			continue
		var d = blob_pos.distance_to(org["pos"])
		if d < nearest_dist:
			nearest_dist = d
			nearest = org

	if nearest != null:
		var desired = (nearest["pos"] - blob_pos).normalized()
		blob_dir = (blob_dir * 0.85 + desired * 0.15).normalized()

	# move
	blob_pos += blob_dir * blob_speed

	# bounce off edges
	var size = get_viewport_rect().size
	if blob_pos.x < 0 or blob_pos.x > size.x:
		blob_dir.x *= -1
	if blob_pos.y < 0 or blob_pos.y > size.y:
		blob_dir.y *= -1

	# kill by body contact
	for org in organisms:
		if org["dead"]:
			continue
		if blob_pos.distance_to(org["pos"]) < blob_radius + org["radius"]:
			org["dead"] = true
			explosions.append({"pos": org["pos"], "color": org["color"], "frame": 0})

	# spawn blob tentacles
	if randi() % 6 == 0:
		var angle = randf() * TAU
		var dir = Vector2(cos(angle), sin(angle))
		blob_tentacles.append({
			"start": blob_pos,
			"tip": blob_pos + dir * 5.0,
			"dir": dir,
			"length": 1.0,
			"alive": true
		})


# ---------------------------------------------------------
# BLOB TENTACLE UPDATE
# ---------------------------------------------------------
func _update_blob_tentacles():
	for t in blob_tentacles:
		if not t["alive"]:
			continue

		t["tip"] += t["dir"] * 18.2
		t["length"] += 15.2

		t["dir"] = (t["dir"] + Vector2(
			randf_range(-0.05, 0.05),
			randf_range(-0.05, 0.05)
		)).normalized()

		var size = get_viewport_rect().size
		if t["tip"].x < 0 or t["tip"].x > size.x:
			t["dir"].x *= -1
		if t["tip"].y < 0 or t["tip"].y > size.y:
			t["dir"].y *= -1

		for org in organisms:
			if org["dead"]:
				continue
			if t["tip"].distance_to(org["pos"]) < org["radius"]:
				org["dead"] = true
				explosions.append({"pos": org["pos"], "color": org["color"], "frame": 0})

		if t["length"] > 220:
			t["alive"] = false


# ---------------------------------------------------------
# ORGANISM TENTACLE UPDATE
# ---------------------------------------------------------
func _update_tentacles():
	for org in organisms:
		if org["dead"]:
			continue

		if org["tentacles"].size() < MAX_TENTACLES_PER_ORG and randi() % 30 == 0:
			var angle = randf() * TAU
			var dir = Vector2(cos(angle), sin(angle))
			org["tentacles"].append({
				"start": org["pos"],
				"tip": org["pos"] + dir * 5.0,
				"dir": dir,
				"length": 5.0,
				"alive": true
			})

		for t in org["tentacles"]:
			if not t["alive"]:
				continue

			var speed = TENTACLE_SPEED * org["growth"]
			t["tip"] += t["dir"] * speed
			t["length"] += speed

			t["dir"] = (t["dir"] + Vector2(
				randf_range(-0.05, 0.05),
				randf_range(-0.05, 0.05)
			)).normalized()

			var size = get_viewport_rect().size
			if t["tip"].x < 0 or t["tip"].x > size.x:
				t["dir"].x *= -1
			if t["tip"].y < 0 or t["tip"].y > size.y:
				t["dir"].y *= -1

			_check_collisions(org, t)

			if t["length"] > MAX_TENTACLE_LENGTH:
				_spawn_child(org, t["tip"])
				t["alive"] = false


# ---------------------------------------------------------
# COLLISIONS
# ---------------------------------------------------------
func _check_collisions(org, tentacle):
	var tip = tentacle["tip"]

	for enemy in organisms:
		if enemy == org:
			continue
		if enemy["dead"]:
			continue
		if enemy["team"] == org["team"]:
			continue

		if tip.distance_to(enemy["pos"]) < enemy["radius"]:
			enemy["dead"] = true
			explosions.append({"pos": enemy["pos"], "color": enemy["color"], "frame": 0})
			return

		for et in enemy["tentacles"]:
			if not et["alive"]:
				continue
			if tip.distance_to(et["tip"]) < TIP_COLLISION_RADIUS:
				et["alive"] = false
				explosions.append({"pos": et["tip"], "color": org["color"], "frame": 0})
				return


# ---------------------------------------------------------
# CHILD SPAWN
# ---------------------------------------------------------
func _spawn_child(parent, pos):
	if organisms.size() >= MAX_ORGANISMS:
		return

	organisms.append({
		"pos": pos,
		"color": parent["color"],
		"radius": 12.0,
		"growth": parent["growth"] * randf_range(0.9, 1.1),
		"team": parent["team"],
		"tentacles": [],
		"dead": false,
		"life": randi_range(300, 900)
	})


# ---------------------------------------------------------
# EXPLOSION UPDATE
# ---------------------------------------------------------
func _update_explosions():
	for e in explosions:
		e["frame"] += 1

	explosions = explosions.filter(func(e):
		return e["frame"] < 20
	)


# ---------------------------------------------------------
# CLEANUP
# ---------------------------------------------------------
func _cleanup():
	for org in organisms:
		org["tentacles"] = org["tentacles"].filter(func(t): return t["alive"])

	organisms = organisms.filter(func(o): return not o["dead"])

	blob_tentacles = blob_tentacles.filter(func(t): return t["alive"])


# ---------------------------------------------------------
# DRAW
# ---------------------------------------------------------
func _draw():
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.BLACK, true)

	draw_circle(blob_pos, blob_radius, Color(0.967, 0.0, 0.0, 1.0))

	for t in blob_tentacles:
		if not t["alive"]:
			continue

		var start = t["start"]
		var tip = t["tip"]

		var segments = 12
		var points = []

		for i in range(segments + 1):
			var tpos = float(i) / segments
			var pos = start.lerp(tip, tpos)

			var wiggle = sin((tpos * 8.0) + frame * 0.1) * 6.0

			var dir = (tip - start).normalized()
			var perp = Vector2(-dir.y, dir.x)

			points.append(pos + perp * wiggle)

		for i in range(points.size() - 1):
			draw_line(points[i], points[i+1], Color(1,0,0) * 1.8, 2.0)

	for e in explosions:
		var t = e["frame"] / 20.0
		var radius = lerp(5, 40, t)
		var alpha = lerp(1.0, 0.0, t)
		var col = Color(e["color"].r, e["color"].g, e["color"].b, alpha)

		draw_circle(e["pos"], radius, col)
		draw_circle(e["pos"], radius * 0.4, Color(1,1,1,alpha * 0.6))

	for org in organisms:
		draw_circle(org["pos"], org["radius"], org["color"])

	for org in organisms:
		for t in org["tentacles"]:
			if not t["alive"]:
				continue

			var start = t["start"]
			var tip = t["tip"]

			var segments = 12
			var points = []

			for i in range(segments + 1):
				var tpos = float(i) / segments
				var pos = start.lerp(tip, tpos)

				var wiggle = sin((tpos * 8.0) + frame * 0.1) * 6.0

				var dir = (tip - start).normalized()
				var perp = Vector2(-dir.y, dir.x)

				points.append(pos + perp * wiggle)

			for i in range(points.size() - 1):
				draw_line(points[i], points[i+1], org["color"] * 1.8, 2.0)
