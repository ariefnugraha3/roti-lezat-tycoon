class_name StaffDefinition
extends RefCounted
## Kandidat staf dari roster tetap (GDD 3.1-3.5, 87.1, 101.5).
##
## Keputusan maintainer 2026-10-02: staf tidak punya tier maupun kemampuan
## khusus. Semua kasir dan koki bekerja sama cepat dan sama caranya; yang
## membedakan kandidat hanya nama, rupa, dan cerita. Gaji harian ditetapkan
## tier lokasi (`LocationDefinition.staff_daily_wage_kr`), sama untuk kedua
## peran, dan kecepatan jalan semua staf `staff.json` `staff_movement_speed_mps`.

var id: StringName
var display_name: String = ""
## &"cashier" atau &"baker"
var role_id: StringName
## Parameter CharacterFactory (warna sebagai "#rrggbb").
var visual: Dictionary = {}
var visual_profile_id: StringName


static func from_dict(d: Dictionary) -> StaffDefinition:
	var s := StaffDefinition.new()
	s.id = StringName(str(d.get("id", "")))
	s.display_name = str(d.get("display_name", ""))
	s.role_id = StringName(str(d.get("role_id", "")))
	s.visual = d.get("visual", {})
	s.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
	return s


func is_cashier() -> bool:
	return role_id == &"cashier"


func is_baker() -> bool:
	return role_id == &"baker"


## Nama jabatan: "Cashier Assistant" atau "Kitchen Assistant" (GDD 127).
func title_key() -> String:
	return "ui_staff_role_%s" % role_id
