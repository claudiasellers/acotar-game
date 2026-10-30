## The registry of every lane's HeightProvider. Lanes add their entry to
## height_providers.tres in their own handoff.
class_name HeightProviderSet
extends Resource

@export var providers: Array[HeightProvider] = []
