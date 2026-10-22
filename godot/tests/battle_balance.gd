extends SceneTree
var battle: Node2D
var campaign: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.set_process(false)
	battle = load("res://scripts/battle.gd").new()
	root.add_child(battle)
	battle.build(1,[60,50,50,40],"line",41)
	battle.set_physics_process(false)
	var start := Time.get_ticks_usec()
	var frames := 0
	while battle.elapsed < 240 and not battle.ended:
		# A modest player policy: approach the nearest enemy, hold strike, rally when hurt.
		var target: Dictionary = {}
		var nearest := INF
		for unit in battle.units:
			if unit.team != 1 or unit.hp <= 0: continue
			var distance: float = unit.pos.distance_squared_to(battle.player.pos)
			if distance < nearest:
				nearest = distance
				target = unit
		battle.input_axis = Vector2.ZERO
		if not target.is_empty() and nearest > 2600: battle.input_axis = (target.pos-battle.player.pos).normalized()
		battle.held_strike = true
		if battle.player.hp < battle.player.max*0.7: battle.action("rally")
		battle.advance(1.0/30)
		frames += 1
		if frames % 900 == 0:
			print("BALANCE ",int(battle.elapsed),"s ",battle.counts()," leader ",int(battle.player.hp))
			await process_frame
	var result := {"seconds":snappedf(battle.elapsed,0.1),"won":battle.ended and battle.player.hp>0,"leader_hp":battle.player.hp,"remaining":battle.counts(),"simulation_ms_per_tick":(Time.get_ticks_usec()-start)/1000.0/frames}
	print("BATTLE RESULT ",JSON.stringify(result))
	var success: bool = result.won and result.seconds >= 70 and result.seconds <= 240
	battle.queue_free()
	await process_frame
	campaign.state.squads = [125,125,125,125]
	battle = load("res://scripts/battle.gd").new()
	root.add_child(battle)
	battle.build(15,[125,125,125,125],"line",42)
	battle.set_physics_process(false)
	battle._spawn_wave()
	battle._spawn_wave()
	battle.charge = 0
	start = Time.get_ticks_usec()
	for i in 300: battle.advance(1.0/30)
	var stress := {"units":battle.units.size(),"simulation_ms_per_tick":(Time.get_ticks_usec()-start)/1000.0/300,"live":battle.counts()}
	print("STRESS RESULT ",JSON.stringify(stress))
	var report := FileAccess.open("res://artifacts/battle-balance.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"baseline":result,"stress":stress},"\t"))
	report.close()
	battle.queue_free()
	await process_frame
	root.get_node("Sound").stop_all()
	for i in 3: await process_frame
	quit(0 if success else 1)
