extends RefCounted


static func height_at(_x: float, _z: float) -> float:
	return 100.0


static func texture_at(_x: float, _z: float) -> Vector3i:
	return Vector3i(WorldHeight.Tex.PATH, WorldHeight.Tex.SNOW, 7)
