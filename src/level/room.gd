## Room — Scene node representing a single room in a level.
##
## Contains collision geometry as children. LevelManager discovers
## Room nodes in its children and registers them by room_id.
class_name Room
extends Node2D

## Unique identifier for this room (e.g., &"living_room", &"kitchen").
@export var room_id: StringName = &""

## World-space bounding rectangle of this room.
@export var bounds: Rect2 = Rect2()

## IDs of rooms adjacent to this one (for BFS attenuation in Sprint 2).
@export var adjacent_rooms: Array[StringName] = []
