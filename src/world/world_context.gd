class_name WorldContext
extends RefCounted
## Services Main hands to a world scene before it enters the tree (see Main.load_world).

var input_router: InputRouter
## Parsed CLI user args (e.g. "autoplay").
var args: Dictionary = {}
