class_name Ids
extends RefCounted
## Urutan ID yang deterministik (GDD 102, 116). `Array.sort()` membandingkan
## StringName menurut alamat internalnya, bukan menurut huruf, sehingga urutan
## itu bisa berbeda antar-sesi (mis. setelah memuat save di sesi lain). Setiap
## iterasi simulasi atas ID teks memakai urutan dari sini.


## Angka menurut nilai dan selalu sebelum teks; teks menurut huruf.
static func less(a: Variant, b: Variant) -> bool:
	var na: bool = a is int or a is float
	var nb: bool = b is int or b is float
	if na and nb:
		return float(a) < float(b)
	if na != nb:
		return na
	return str(a) < str(b)


## Urutkan `ids` di tempat dan kembalikan array yang sama.
static func sort(ids: Array) -> Array:
	ids.sort_custom(less)
	return ids
