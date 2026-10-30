@tool
extends StaticBody2D
## A ground strip or a ledge. Its `size` is set in the Inspector (or as an
## instance override), so ONE scene covers the whole level instead of
## hand-authoring a collision shape and two rects for every platform.
##
## The node's origin is the CENTRE of the platform.
##
## `@tool` on purpose: the shape and the two rects are built in code, so without
## it none of this exists in the editor — the ground and every ledge would be
## invisible in main.tscn and you would be looking straight at the background
## image while editing the level.

const TOP_THICKNESS := 9.0
# NOTE: this file is a @tool script so the editor draws the ground and ledges
# while you edit the level. If Godot had the file open when tool mode was added,
# it must reload the script (restart the editor) before that takes effect.

## Copied from PALETTE_DEFAULT in game.gd rather than read from the Game
## autoload, because autoloads do not exist inside the editor. At runtime
## game_level.gd calls _apply_palette() right after and overwrites both colours,
## which is what makes the colourblind palette work.
const DEFAULT_BODY := Color(0.447, 0.365, 0.176)
const DEFAULT_TOP := Color(0.376, 0.584, 0.239)

@export var size: Vector2 = Vector2(200, 32):
	set(value):
		size = value
		_rebuild()

## One-way ledges can be jumped *up through* and landed on from above, so their
## underside never blocks a jump. Ground strips stay solid, so the player cannot
## slip through the side of a pit.
@export var one_way: bool = false:
	set(value):
		one_way = value
		_rebuild()

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _body: ColorRect = $Body
@onready var _top: ColorRect = $Top


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	# The setters also fire during scene instantiation, before _ready, when the
	# @onready references do not exist yet.
	if not is_node_ready():
		return

	var rect := RectangleShape2D.new()
	rect.size = size
	_collision.shape = rect
	_collision.one_way_collision = one_way
	_collision.one_way_collision_margin = 6.0

	var half := size * 0.5
	_body.color = DEFAULT_BODY
	_body.offset_left = -half.x
	_body.offset_right = half.x
	_body.offset_top = -half.y
	_body.offset_bottom = half.y

	# Thin grass/edge strip across the top face.
	_top.color = DEFAULT_TOP
	_top.offset_left = -half.x
	_top.offset_right = half.x
	_top.offset_top = -half.y
	_top.offset_bottom = -half.y + TOP_THICKNESS