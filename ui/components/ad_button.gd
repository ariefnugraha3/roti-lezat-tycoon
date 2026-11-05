class_name AdButton
extends RefCounted
## Tombol hadiah iklan berhadiah (GDD idle 22.1, 22.3): ikon putar dan "· Ad"
## supaya pemain tahu iklan akan tayang sebelum mengetuknya, atau ikon hati dan
## "· Free" bagi pemilik Supporter Pack. Tampil hanya bila Monetization bisa
## menawarkan hadiah itu sekarang (iklan siap dan jatah harian masih ada).


static func make(placement: StringName, text: String, kind: String = "soft", icon_size: int = 20, font_size: int = 16) -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button("play", Tx.t("ui_ad_watch", {"text": text}), kind, icon_size, font_size)
	b.name = "Ad_" + String(placement)
	b.set_meta("placement", placement)
	b.set_meta("base_text", text)
	refresh(b)
	return b


## Teks, ikon, dan tampil/sembunyi sesuai keadaan sekarang. Aman dipanggil
## setiap tick: hanya mengubah yang berubah.
static func refresh(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		return
	var placement: StringName = b.get_meta("placement")
	var free: bool = Monetization.is_free(placement)
	var text: String = Tx.t("ui_ad_free" if free else "ui_ad_watch", {"text": str(b.get_meta("base_text"))})
	var cap: Label = b.get_meta("caption") as Label
	if cap != null and cap.text != text:
		cap.text = text
		b.tooltip_text = text
	var ic: IconCanvas = b.get_meta("icon") as IconCanvas
	var icon_name: String = "heart" if free else "play"
	if ic != null and ic.icon_name != icon_name:
		ic.icon_name = icon_name
	var show: bool = Monetization.can_offer(placement)
	if b.visible != show:
		b.visible = show
