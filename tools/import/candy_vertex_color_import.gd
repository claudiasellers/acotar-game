## The vertex-colour post-import (world/shared/import/vertex_color_import.gd),
## which now remaps to CandyMaterial first. A separate path so every glb that
## used it reimports once with the candy surfaces (render program T2).
@tool
extends "res://world/shared/import/vertex_color_import.gd"
