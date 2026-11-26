## One rung of a bond's ladder (docs/contracts/relationships.md, plan §1.1).
## It opens when its gate is up, its needs are done, and regard has reached
## its floor (or its canon floor beat has come, so the book is never blocked).
class_name BondStage
extends Resource

@export var id: StringName
## The flag that means this stage is reached.
@export var fact: String = ""
## True when another system raises `fact` (a canon flag, or fact.mare_ridden):
## the core only reads it.
@export var raised_elsewhere: bool = false
## Canon flag that must be up first ("" for none): the ceiling.
@export var gate: String = ""
## Deeds that must all be done (the mare's milestones).
@export var needs: Array[StringName] = []
## Regard needed.
@export var floor: int = 0
## Canon flag that opens the stage without the regard ("": the floor is strict).
@export var canon_floor: String = ""
## Regard at which this stage turns warm (0: never): fact.<prefix>_warm_<id>.
@export var warm_at: int = 0
## How they hold themselves here before it turns warm (Relationships.COOL,
## BAITING, NEUTRAL or WARM).
@export var attitude: StringName = &"neutral"
@export var canon: String = "X"
