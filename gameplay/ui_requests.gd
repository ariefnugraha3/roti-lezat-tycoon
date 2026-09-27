class_name UIRequests
extends RefCounted
## Konteks sementara untuk modal yang diminta lapisan tugas pemain. Bukan state
## gameplay dan tidak disimpan: saat load, semua modal tertutup.

var recipe_book_storage: int = -1
var slot_picker_display: int = -1
var display_detail: int = -1
var customer_order: StringName = &""


func clear() -> void:
	recipe_book_storage = -1
	slot_picker_display = -1
	display_detail = -1
	customer_order = &""
