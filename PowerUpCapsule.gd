# scripts/PowerUpCapsule.gd
extends Area2D
@export var power_type := "Spread"      # enumerate in Inspector

const FUSION_TABLE := {
	"Spread:Freeze":  "PermaFrostFan",
	"Laser:Explosive":"TridentNova",
	"Freeze:Laser":   "CrystallineBeam",
	# Add the full matrix here ⇧
}

func _on_body_entered(player: PlayerBase):
	var current := player._weapon.name
	if current == power_type:
		player._weapon.upgrade_tier()
	else:
		var key := "%s:%s" % [current, power_type]
		var fusion:String = FUSION_TABLE.get(key, null)
		if fusion:
			player.swap_weapon(fusion)
		else:
			player.swap_weapon(power_type)
	queue_free()
