extends Node2D

# ---------------------------------------------------------
# CONFIG
# ---------------------------------------------------------
const START_ORGANISMS := 100
const MAX_ORGANISMS := 100
const MAX_TENTACLES_PER_ORG := 10

const TENTACLE_SPEED := 1
var MAX_TENTACLE_LENGTH := 10.0
const TIP_COLLISION_RADIUS := 10.0

var organisms = []
var frame = 0

var tentacle_timer = 0.0

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
			"life": randi_range(600000, 6000050)
		})


# ---------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------
func _process(delta):
	frame += 1
	_update_lifespans()
	_update_tentacle_growth_timer(delta)
	_update_tentacles()
	_update_explosions()
	_cleanup()
	queue_redraw()


# ---------------------------------------------------------
# TENTACLE GROWTH TIMER
# ---------------------------------------------------------
func _update_tentacle_growth_timer(delta):
	tentacle_timer += delta
	if tentacle_timer >= 1.0:
		tentacle_timer = 0.0
		MAX_TENTACLE_LENGTH += 15.0
		print("Tentacle max length increased to: ", MAX_TENTACLE_LENGTH)


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
# ORGANISM TENTACLE UPDATE (FADE + CHILD FIX)
# ---------------------------------------------------------
func _update_tentacles():
	for org in organisms:
		if org["dead"]:
			continue

		# spawn tentacle
		if org["tentacles"].size() < MAX_TENTACLES_PER_ORG and randi() % 30 == 0:
			var angle = randf() * TAU
			var dir = Vector2(cos(angle), sin(angle))
			org["tentacles"].append({
				"start": org["pos"],
				"tip": org["pos"] + dir * 5.0,
				"dir": dir,
				"length": 5.0,
				"alive": true,
				"fade": 1.0
			})

		for t in org["tentacles"]:

			# ACTIVE tentacle
			if t["alive"]:
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

				# CHILD SPAWN FIX — spawn BEFORE fade
				if t["length"] > MAX_TENTACLE_LENGTH:
					_spawn_child(org, t["tip"])
					t["alive"] = false
					t["fade"] = 1.0

			# DEAD tentacle (fade mode)
			else:
				t["fade"] -= 0.005   # smooth fade


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
				et["fade"] = 1.0
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
		"radius": 18.0,
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
# CLEANUP (FADE SUPPORT)
# ---------------------------------------------------------
func _cleanup():
	for org in organisms:
		org["tentacles"] = org["tentacles"].filter(func(t):
			return t["fade"] > 0.0
		)

	organisms = organisms.filter(func(o): return not o["dead"])

	blob_tentacles = blob_tentacles.filter(func(t): return t["alive"])


# ---------------------------------------------------------
# DRAW
# ---------------------------------------------------------
func _draw():
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.BLACK, true)

	# explosions
	for e in explosions:
		var t = e["frame"] / 20.0
		var radius = lerp(5, 40, t)
		var alpha = lerp(1.0, 0.0, t)
		var col = Color(e["color"].r, e["color"].g, e["color"].b, alpha)

		draw_circle(e["pos"], radius, col)
		draw_circle(e["pos"], radius * 0.4, Color(1,1,1,alpha * 0.6))

	# organisms
	for org in organisms:
		draw_circle(org["pos"], org["radius"], org["color"])

	# tentacles (FADE)
	for org in organisms:
		for t in org["tentacles"]:
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

			var alpha = clamp(t["fade"], 0.0, 1.0)
			var col = Color(org["color"].r, org["color"].g, org["color"].b, alpha)

			for i in range(points.size() - 1):
				draw_line(points[i], points[i+1], col, 6.0)
