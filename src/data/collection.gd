class_name Collection
extends RefCounted
## 文物档案收集册：标题页的长期收藏。
##
## 条目只放“真实文物”（Game.ARCHIVE 里的条目），图片复用端详页的 2.5D 特写；
## 解锁状态来自 Game.is_archived()（行动中接触过 / 老档已推进过器灵对谈）。

const IDS: Array[String] = ["mask", "ram_zun"]

const LOCKED_HINTS := {
	"mask": "在「城西博物馆」的行动中带走它，这一页就会亮起来。",
	"ram_zun": "在「大英博物馆·中国馆」的行动中带走它，这一页就会亮起来。",
}

const FIELD_LABELS := {
	"era": "年代",
	"origin": "原在地",
	"collection": "现藏",
	"provenance": "流转",
	"legend": "备注",
}


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in IDS:
		var archive: Dictionary = Game.ARCHIVE.get(item_id, {})
		result.append({
			"id": item_id,
			"name": Game.item_name(item_id),
			"image": Lore.closeup_path(item_id),
			"hint": String(LOCKED_HINTS.get(item_id, "")),
			"archive": archive,
		})
	return result
