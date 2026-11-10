extends Effect
class_name AdmiralDockMaster
## +3 vagas na doca: cabe mais navio na frota.

const EXTRA := 3

func _init() -> void:
	id = &"dock_master"
	display_name = "Mestre do Estaleiro"
	description = "+%d vagas na doca: cabe mais navio na frota." % EXTRA

func modify_dock(n: int) -> int:
	return n + EXTRA
