class_name Investigation
extends RefCounted
## 电脑调查链数据：浏览器 / 档案库 / 邮件 / 聊天 / 推理板。
##
## 设计约定（按 docs/narrative/EXPLORATION_PATCH_V2.md）：
##   - 玩家先在电脑/手机看到文字档案与名称，**没有完整目标照片**。
##   - 推理板中心是文字档案 + 三个问题，玩家用已获得的材料手动连线/选择关系。
##   - 只追踪一条线也能行动；另外两条未完成不阻塞出门。
##   - 史实信息走 card/档案，虚构演绎仅存在于角色台词。

const TARGETS := {
	"ram_zun": {
		"name": "商代双羊尊",
		"code": "1936,1118.1",
		"questions": [
			{"id": "features", "text": "它有哪些能认出的特点？", "requires": ["zun_archive", "zun_tech"]},
			{"id": "area", "text": "哪份材料指向本次展区？", "requires": ["zun_delivery"]},
			{"id": "spot", "text": "我在哪里看到过对应门牌或柜号？", "requires": ["zun_service"]},
		],
		"materials": {
			"zun_name": {
				"type": "note",
				"title": "恶魔留下的清单",
				"body": "三个名字：商代双羊尊、埃及心形圣甲虫、阿克罗蒂里彩绘注壶。没有照片，没有地图。",
				"unlock": "saw_p00",
				"answers": [],
			},
			"zun_archive": {
				"type": "archive",
				"title": "馆藏档案 1936,1118.1",
				"body": "登记对象：商代双羊尊。两只羊合为器身，背部有开口。档案记载它来自尤摩弗帕勒斯旧藏，1936 年入藏。关于此前的出境经过，这页没有继续写下去。",
				"unlock": "inv_zun_archive",
				"answers": ["features"],
			},
			"zun_tech": {
				"type": "web",
				"title": "技术研究摘记",
				"body": "这件双羊尊做过技术研究：羊角先铸好，再与器身接合。材料也讨论了南方青铜传统，具体来自湖南何处仍不能确定。",
				"unlock": "inv_zun_tech",
				"answers": ["features"],
			},
			"zun_delivery": {
				"type": "mail",
				"title": "阿岚：C-17 搬运备注",
				"body": "C-17：双羊尊，1936,1118.1。入柜时从腹底托起，避开双角。临时展位在青铜厅内侧。送柜和撤柜都走东侧装卸道。",
				"unlock": "inv_zun_delivery",
				"answers": ["area"],
			},
			"zun_service": {
				"type": "note",
				"title": "馆内检修便条",
				"body": "C-17 的搬运小车停在东门内侧。台阶口不得搬运重器，请从平坡绕行。搬运结束后关闭防火门。",
				"unlock": "inv_zun_service",
				"answers": ["spot"],
			},
		},
		"relations": {
			"features": [
				{"text": "双羊合为器身，背部开口，羊角先铸后接", "correct": true, "feedback": "对，这些是能把它认出来的关键特征。"},
				{"text": "单羊独尊，面部有饕餮纹", "correct": false, "feedback": "这不是双羊尊的形制。"},
			],
			"area": [
				{"text": "青铜厅内侧临时展位", "correct": true, "feedback": "是，布展单上写了这个展区。"},
				{"text": "入口大厅安检门旁", "correct": false, "feedback": "那里不是重器展位。"},
			],
			"spot": [
				{"text": "东门内侧，C-17 小车", "correct": true, "feedback": "门牌和柜号对应上了。"},
				{"text": "西侧装卸区，G-04", "correct": false, "feedback": "G-04 是另一件目标的线索，不是双羊尊。"},
			],
		},
	},

	"egypt_heart_scarab": {
		"name": "埃及心形圣甲虫",
		"code": "10.130.1650",
		"questions": [
			{"id": "features", "text": "它有哪些能认出的特点？"},
			{"id": "area", "text": "哪份材料指向本次展区？"},
			{"id": "spot", "text": "我在哪里看到过对应门牌或柜号？"},
		],
		"materials": {
			"scarab_name": {
				"type": "note",
				"title": "恶魔留下的清单",
				"body": "三个名字之一：埃及心形圣甲虫。没有照片，没有地图。",
				"unlock": "saw_p00",
				"answers": [],
			},
		},
		"relations": {
			"features": [
				{"text": "心形圣甲虫，背部有穿孔", "correct": true, "feedback": "（占位：E 批接入时补全）"},
				{"text": "带翼日盘，青金石镶嵌", "correct": false, "feedback": "（占位：E 批接入时补全）"},
			],
			"area": [
				{"text": "埃及厅中央展柜", "correct": true, "feedback": "（占位）"},
				{"text": "丝路厅侧柜", "correct": false, "feedback": "（占位）"},
			],
			"spot": [
				{"text": "北服务门 E-09", "correct": true, "feedback": "（占位）"},
				{"text": "东装卸道 C-17", "correct": false, "feedback": "（占位）"},
			],
		},
	},

	"akrotiri_askos": {
		"name": "阿克罗蒂里彩绘注壶",
		"code": "VM-GR-25-012",
		"questions": [
			{"id": "features", "text": "它有哪些能认出的特点？"},
			{"id": "area", "text": "哪份材料指向本次展区？"},
			{"id": "spot", "text": "我在哪里看到过对应门牌或柜号？"},
		],
		"materials": {
			"askos_name": {
				"type": "note",
				"title": "恶魔留下的清单",
				"body": "三个名字之一：阿克罗蒂里彩绘注壶。没有照片，没有地图。",
				"unlock": "saw_p00",
				"answers": [],
			},
		},
		"relations": {
			"features": [
				{"text": "船形注壶，绘有海豚与波浪纹", "correct": true, "feedback": "（占位：E 批接入时补全）"},
				{"text": "双耳高颈，黑绘人物", "correct": false, "feedback": "（占位：E 批接入时补全）"},
			],
			"area": [
				{"text": "希腊爱琴海专题厅", "correct": true, "feedback": "（占位）"},
				{"text": "瓷器厅", "correct": false, "feedback": "（占位）"},
			],
			"spot": [
				{"text": "西服务间 G-04", "correct": true, "feedback": "（占位）"},
				{"text": "东门内侧 C-17", "correct": false, "feedback": "（占位）"},
			],
		},
	},
}


static func target_ids() -> Array[String]:
	var out: Array[String] = []
	for id in TARGETS.keys():
		out.append(id)
	return out


static func target_name(target_id: String) -> String:
	var entry: Dictionary = TARGETS.get(target_id, {})
	return entry.get("name", target_id)


static func target_code(target_id: String) -> String:
	var entry: Dictionary = TARGETS.get(target_id, {})
	return entry.get("code", "")


static func questions(target_id: String) -> Array:
	var entry: Dictionary = TARGETS.get(target_id, {})
	return entry.get("questions", [])


static func materials(target_id: String) -> Dictionary:
	var entry: Dictionary = TARGETS.get(target_id, {})
	return entry.get("materials", {})


static func material(target_id: String, material_id: String) -> Dictionary:
	var mats: Dictionary = materials(target_id)
	return mats.get(material_id, {})


static func relations(target_id: String, question_id: String) -> Array:
	var entry: Dictionary = TARGETS.get(target_id, {})
	var rels: Dictionary = entry.get("relations", {})
	return rels.get(question_id, [])


static func unlocked_materials(target_id: String) -> Dictionary:
	var out := {}
	for mid in materials(target_id).keys():
		var mat: Dictionary = material(target_id, mid)
		var flag: String = mat.get("unlock", "")
		if flag == "" or Game.story_flag(flag):
			out[mid] = mat
	return out


static func is_question_answered(target_id: String, question_id: String) -> bool:
	return Game.story_flag("inv_%s_%s_ok" % [target_id, question_id])


static func question_requires(target_id: String, question_id: String) -> Array:
	for q in questions(target_id):
		if q.get("id", "") == question_id:
			return q.get("requires", [])
	return []


static func can_answer_question(target_id: String, question_id: String) -> bool:
	for req in question_requires(target_id, question_id):
		var mat := material(target_id, req)
		var flag := mat.get("unlock", "") as String
		if flag == "" or not Game.story_flag(flag):
			return false
	return true


static func answer_question(target_id: String, question_id: String, material_id: String, relation_index: int) -> Dictionary:
	if not can_answer_question(target_id, question_id):
		return {"ok": false, "feedback": "还缺少关键材料，无法下结论。"}
	var mat := material(target_id, material_id)
	if mat.is_empty() or not (question_id in mat.get("answers", [])):
		return {"ok": false, "feedback": "这份材料不能回答这个问题。"}
	var flag := mat.get("unlock", "") as String
	if flag != "" and not Game.story_flag(flag):
		return {"ok": false, "feedback": "你还没有获得这份材料。"}
	var rels: Array = relations(target_id, question_id)
	if relation_index < 0 or relation_index >= rels.size():
		return {"ok": false, "feedback": "无效选项。"}
	var rel: Dictionary = rels[relation_index]
	var ok := rel.get("correct", false) as bool
	if ok:
		Game.set_story_flag("inv_%s_%s_ok" % [target_id, question_id])
	return {"ok": ok, "feedback": rel.get("feedback", "")}


static func any_question_answered(target_id: String) -> bool:
	for q in questions(target_id):
		if is_question_answered(target_id, q["id"]):
			return true
	return false


## 浏览器关键词匹配：返回可解锁的材料 ID 列表（只解锁未解开的）。
static func search_web(keyword: String) -> Array[String]:
	var kw := keyword.strip_edges()
	var out: Array[String] = []
	if kw == "":
		return out
	for tid in target_ids():
		for mid in materials(tid).keys():
			var mat: Dictionary = material(tid, mid)
			if mat.get("type", "") != "web":
				continue
			var title: String = mat.get("title", "")
			var body: String = mat.get("body", "")
			if title.contains(kw) or body.contains(kw) or tid.contains(kw.to_lower()):
				out.append("%s:%s" % [tid, mid])
	return out


## 档案编号检索：返回匹配的 archive 材料 ID。
static func search_archive(code: String) -> Array[String]:
	var c := code.strip_edges()
	var out: Array[String] = []
	if c == "":
		return out
	for tid in target_ids():
		if target_code(tid) == c:
			for mid in materials(tid).keys():
				var mat: Dictionary = material(tid, mid)
				if mat.get("type", "") == "archive":
					out.append("%s:%s" % [tid, mid])
		for mid in materials(tid).keys():
			var mat: Dictionary = material(tid, mid)
			if mat.get("type", "") == "archive" and mat.get("title", "").contains(c):
				out.append("%s:%s" % [tid, mid])
	return out


static func material_type_label(mtype: String) -> String:
	match mtype:
		"web": return "网页"
		"archive": return "档案"
		"mail": return "邮件"
		"chat": return "聊天"
		_: return "笔记"
