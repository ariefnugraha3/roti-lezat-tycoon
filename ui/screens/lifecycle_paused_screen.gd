class_name LifecyclePausedScreen
extends UIScreen
## "Game Paused" setelah aplikasi/tab kehilangan fokus (GDD 90, 113). Tidak ada
## kemajuan offline; pemain harus menekan Resume secara eksplisit.


## Muncul di atas modal yang sedang terbuka tanpa menutupnya; Resume kembali ke modal itu.
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_pause_title"), Vector2(460, 300), false)
	var c := CenterContainer.new()
	c.add_child(ProceduralUIFactory.icon("pause", 64, Palette.UI_WOOD))
	body.add_child(c)
	var b: Button = btn(body, Tx.t("ui_resume"), "primary", _resume)
	b.custom_minimum_size = Vector2(300, 60)


func _resume() -> void:
	PauseManager.resume_from_lifecycle()
	close()


func on_back() -> bool:
	_resume()
	return true
