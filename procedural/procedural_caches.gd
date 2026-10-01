class_name ProceduralCaches
extends RefCounted
## Satu pintu untuk melepas cache statis generator prosedural saat aplikasi,
## test runner, atau validator keluar (GDD 94 no.1, 133.3: tanpa orphan/RID bocor).


static func clear_all() -> void:
	MaterialKeep.clear()
	ProceduralMeshFactory.clear_caches()
	BreadFactory.clear_caches()
	FX.clear_caches()
	ProceduralUIFactory.clear_caches()
	MeshBuilder.clear_materials()
	CharacterFactory.clear_caches()
	DecorFactory.clear_caches()
