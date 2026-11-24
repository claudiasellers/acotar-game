extends GutTest
## The weakref pattern used by deferred lambdas (timers, tweens): a freed node
## yields null from get_ref() and the callback is a quiet no-op, no engine error.


func test_weakref_lambda_survives_freed_node() -> void:
	var n := Node3D.new()
	add_child(n)
	var ref: WeakRef = weakref(n)
	var hits: Array[int] = [0]
	var cb := func() -> void:
		var live := ref.get_ref() as Node3D
		if live:
			hits[0] += 1
	cb.call()
	assert_eq(hits[0], 1, "live node is seen")
	n.free()
	cb.call()
	assert_eq(hits[0], 1, "freed node is skipped without error")
