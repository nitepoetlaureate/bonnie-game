## RoomData — Serializable room definition resource.
##
## Used for data-driven room configuration. Rooms can reference
## this resource or define their own exports directly.
class_name RoomData
extends Resource

@export var room_id: StringName = &""
@export var bounds: Rect2 = Rect2()
@export var adjacent_rooms: Array[StringName] = []
