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
		"ready": true,
		"questions": [
			{"id": "features", "text": "它有哪些能认出的特点？", "requires": ["zun_archive", "zun_tech"]},
			{"id": "area", "text": "哪份材料指向本次展区？", "requires": ["zun_delivery"]},
			{"id": "spot", "text": "我在哪里看到过对应门牌或柜号？", "requires": ["zun_service"]},
		],
		"positions": {
			"zun_name": Vector2(0.50, 0.12),
			"zun_archive": Vector2(0.12, 0.38),
			"zun_tech": Vector2(0.88, 0.38),
			"zun_delivery": Vector2(0.28, 0.82),
			"zun_service": Vector2(0.72, 0.82),
		},
		"materials": {
			"zun_name": {
				"type": "note",
				"title": "恶魔留下的清单",
				"body": "三个名字：商代双羊尊、埃及心形圣甲虫、阿克罗蒂里彩绘注壶。没有照片，没有地图。",
				"unlock": "saw_p00",
				"answers": [],
				"facts": [],
				"source": "游戏内剧情",
			},
			"zun_archive": {
				"type": "archive",
				"title": "馆藏档案 1936,1118.1",
				"body": "登记对象：商代双羊尊。两只羊支撑中间的壶形容器；羊角先铸并锁接。馆藏记录写它来自尤摩弗帕勒斯旧藏、1936 年入藏；此前的出境经过，这页没有继续写下去。",
				"unlock": "inv_zun_archive",
				"answers": ["features"],
				"facts": ["C-001-F01", "C-001-F02", "C-001-F03"],
				"source": "SOURCES S-001 / BM 1936,1118.1",
			},
			"zun_tech": {
				"type": "web",
				"title": "技术研究摘记",
				"body": "这件双羊尊做过技术研究：羊角先铸好，再与器身锁接。材料也讨论了南方青铜传统，具体来自湖南何处仍不能确定。",
				"unlock": "inv_zun_tech",
				"answers": ["features", "area"],
				"facts": ["C-001-F04", "C-001-F05"],
				"source": "Wang & Priewe 2013; SOURCES S-001",
			},
			"zun_delivery": {
				"type": "mail",
				"title": "阿岚：C-17 搬运备注",
				"body": "阿岚转来本次展馆的布展备注：C-17，双羊尊。入柜时从腹底托起，避开双角。临时展位在青铜厅内侧；送柜和撤柜都走东侧装卸道。",
				"unlock": "inv_zun_delivery",
				"answers": ["area"],
				"facts": ["X-C02"],
				"source": "游戏内虚构布展单",
			},
			"zun_service": {
				"type": "note",
				"title": "馆内检修便条",
				"body": "C-17 的搬运小车停在东门内侧。台阶口不得搬运重器，请从平坡绕行。搬运结束后关闭防火门。",
				"unlock": "inv_zun_service",
				"answers": ["spot"],
				"facts": ["X-C03"],
				"source": "游戏内虚构现场便条",
			},
		},
		"relations": {
			"features": [
				{"text": "档案形制与工艺研究共同表明：双羊支撑中间壶形容器，羊角先铸并锁接", "correct": true, "requires": ["zun_archive", "zun_tech"], "feedback": "两份材料互相补足：档案确认是哪一件，工艺研究确认羊角做法。"},
				{"text": "只有档案形制：双羊支撑中间壶形容器", "correct": false, "feedback": "这还没有说明羊角工艺；另一份技术材料才能补上。"},
				{"text": "只有工艺研究：羊角先铸并锁接", "correct": false, "feedback": "这还不能确认是哪一件；还需要馆藏档案的形制记录。"},
			],
			"area": [
				{"text": "布展单：临时展位在青铜厅内侧", "correct": true, "requires": ["zun_delivery"], "feedback": "是，布展单写的是本次展馆位置，下一处去青铜厅内侧。"},
				{"text": "技术研究说它可能出自湖南，所以今晚展位在湖南", "correct": false, "requires": ["zun_tech"], "feedback": "技术研究讨论的是历史产地，不是今晚展位；布展单才写本次展馆位置。"},
				{"text": "入口大厅安检门旁", "correct": false, "feedback": "那里不是重器展位。"},
			],
			"spot": [
				{"text": "东门内侧，C-17 小车", "correct": true, "requires": ["zun_service"], "feedback": "门牌和柜号对应上了。"},
				{"text": "西侧装卸区，G-04", "correct": false, "feedback": "G-04 是另一件目标的线索，不是双羊尊。"},
			],
		},
	},

	"egypt_heart_scarab": {
		"name": "埃及心形圣甲虫",
		"code": "10.130.1650",
		"ready": true,
		"positions": {
			"scarab_name": Vector2(0.50, 0.12),
			"scarab_archive": Vector2(0.12, 0.38),
			"scarab_type": Vector2(0.88, 0.38),
			"scarab_delivery": Vector2(0.28, 0.82),
			"scarab_service": Vector2(0.72, 0.82),
		},
		"questions": [
			{"id": "features", "text": "它有哪些能认出的特点？", "requires": ["scarab_archive", "scarab_type"]},
			{"id": "area", "text": "哪份材料指向本次展区？", "requires": ["scarab_delivery"]},
			{"id": "spot", "text": "我在哪里看到过对应门牌或柜号？", "requires": ["scarab_service"]},
		],
		"materials": {
			"scarab_name": {
				"type": "note",
				"title": "恶魔留下的清单",
				"body": "三个名字之一：埃及心形圣甲虫。没有照片，没有地图。",
				"unlock": "saw_p00",
				"answers": [],
				"facts": [],
				"source": "游戏内剧情",
			},
			"scarab_archive": {
				"type": "archive",
				"title": "Met 馆藏档案 10.130.1650",
				"body": "埃及晚期（约前 664—前 332 年），深绿色石材，长约 6.1 厘米；1910 年由 Helen Miller Gould 捐赠。馆藏页只给这些登记字段，没有写本件铭文或此前流转。",
				"unlock": "inv_scarab_archive",
				"answers": ["features"],
				"facts": ["C-002-F01", "C-002-F02"],
				"source": "Met 548226（codex 2026-11-21；SOURCES S-005）",
			},
			"scarab_type": {
				"type": "web",
				"title": "同类器研究摘记",
				"body": "Met 另一件藏品 30.8.1076 介绍：同类心脏圣甲虫用于葬仪，许多同类器刻有请求心脏不作不利证词的文字。这是类型说明，不能套到 10.130.1650 的铭文上。",
				"unlock": "inv_scarab_type",
				"answers": ["features"],
				"facts": ["C-002-F03"],
				"source": "Met 30.8.1076；SOURCES C-002-F03",
			},
			"scarab_delivery": {
				"type": "mail",
				"title": "阿岚：E-09 布展备注",
				"body": "阿岚转来本次展馆的布展备注：埃及厅 E-09 展柜。只写今晚展位，不是出土地或现藏地。",
				"unlock": "inv_scarab_delivery",
				"answers": ["area"],
				"facts": ["X-SC02"],
				"source": "游戏内虚构布展单",
			},
			"scarab_service": {
				"type": "note",
				"title": "北侧服务门便条",
				"body": "E-09 展柜的搬运从北侧服务门进，门牌 E-09。",
				"unlock": "inv_scarab_service",
				"answers": ["spot"],
				"facts": ["X-SC03"],
				"source": "游戏内虚构现场便条",
			},
		},
		"relations": {
			"features": [
				{"text": "馆藏记录：晚王国、深绿色石、长约 6.1 厘米；同类器有葬仪用途，但不能套到本件铭文", "correct": true, "requires": ["scarab_archive", "scarab_type"], "feedback": "馆藏档案确认本件登记字段，类型研究只说明同类器；不能把同类器铭文写成本件。"},
				{"text": "本件刻有第 30B 章，金箔包裹并写有墓主姓名", "correct": false, "feedback": "这些属于同类器的类型介绍或未核内容，不能写成本件。"},
				{"text": "只有馆藏记录：晚王国、深绿色石、长约 6.1 厘米", "correct": false, "feedback": "这还没说明同类器的用途；还需要另一份类型研究。"},
			],
			"area": [
				{"text": "布展单：今晚在埃及厅 E-09 展柜", "correct": true, "requires": ["scarab_delivery"], "feedback": "布展单写的是本次展馆位置，下一处去埃及厅 E-09。"},
				{"text": "档案说它来自埃及，所以今晚在埃及国家博物馆", "correct": false, "requires": ["scarab_archive"], "feedback": "档案讲的是件目来源与年代，不是今晚展馆位置。"},
				{"text": "丝路厅侧柜", "correct": false, "feedback": "丝路厅不是这件目标的本展位。"},
			],
			"spot": [
				{"text": "北侧服务门 E-09", "correct": true, "requires": ["scarab_service"], "feedback": "门牌 E-09 与展柜号对应上了。"},
				{"text": "东门内侧，C-17 小车", "correct": false, "feedback": "C-17 是双羊尊线，不是这件。"},
			],
		},
	},

	"akrotiri_askos": {
		"name": "阿克罗蒂里彩绘注壶",
		"code": "VM-GR-25-012",
		"ready": true,
		"positions": {
			"askos_name": Vector2(0.50, 0.12),
			"askos_archive": Vector2(0.12, 0.38),
			"askos_type": Vector2(0.88, 0.38),
			"askos_delivery": Vector2(0.28, 0.82),
			"askos_service": Vector2(0.72, 0.82),
		},
		"questions": [
			{"id": "features", "text": "它有哪些能认出的特点？", "requires": ["askos_archive", "askos_type"]},
			{"id": "area", "text": "哪份材料指向本次展区？", "requires": ["askos_delivery"]},
			{"id": "spot", "text": "我在哪里看到过对应门牌或柜号？", "requires": ["askos_service"]},
		],
		"materials": {
			"askos_name": {
				"type": "note",
				"title": "恶魔留下的清单",
				"body": "三个名字之一：阿克罗蒂里彩绘注壶。没有照片，没有地图。",
				"unlock": "saw_p00",
				"answers": [],
				"facts": [],
				"source": "游戏内剧情",
			},
			"askos_archive": {
				"type": "archive",
				"title": "UNESCO 条目 VM-GR-25-012",
				"body": "约前 1650—1615 年，出土于阿克罗蒂里（圣托里尼/锡拉）；圆腹、平底、侧嘴、横柄，肩部螺旋纹与条纹。陶土可能来自梅洛斯。公开条目未交代失窃经过与现藏。",
				"unlock": "inv_askos_archive",
				"answers": ["features"],
				"facts": ["C-003-F01", "C-003-F02", "C-003-F04", "AK-04"],
				"source": "UNESCO VM-GR-25-012；SOURCES S-006 + 矩阵 AK-04",
			},
			"askos_type": {
				"type": "web",
				"title": "西屋与陶土：别混用",
				"body": "这件注壶出土于阿克罗蒂里遗址的“西屋”。西屋是考古建筑名，不是今晚展馆西翼；条目推测它可能属于富商或水手，不能当成本件主人。陶土来自梅洛斯，不等于本件在梅洛斯出土。",
				"unlock": "inv_askos_type",
				"answers": ["features", "area"],
				"facts": ["C-003-F04", "AK-05", "AK-06"],
				"source": "UNESCO VM-GR-25-012；矩阵 AK-04/05/06",
			},
			"askos_delivery": {
				"type": "mail",
				"title": "阿岚：G-04 布展备注",
				"body": "阿岚转来本次展馆的布展备注：希腊厅 G-04 展柜。只写今晚展位，不是出土地。",
				"unlock": "inv_askos_delivery",
				"answers": ["area"],
				"facts": ["X-AK02"],
				"source": "游戏内虚构布展单",
			},
			"askos_service": {
				"type": "note",
				"title": "西侧服务门便条",
				"body": "G-04 展柜的搬运从西侧服务门进，门牌 G-04。",
				"unlock": "inv_askos_service",
				"answers": ["spot"],
				"facts": ["X-AK03"],
				"source": "游戏内虚构现场便条",
			},
		},
		"relations": {
			"features": [
				{"text": "约前 1650—1615 年，圆腹平底、侧嘴横柄；西屋是遗址建筑，陶土可能来自梅洛斯", "correct": true, "requires": ["askos_archive", "askos_type"], "feedback": "档案确认器形与年代，类型研究区分西屋/梅洛斯；两处误读都被排除。"},
				{"text": "西屋是今晚展馆西翼，富商是这件注壶的主人", "correct": false, "requires": ["askos_type"], "feedback": "西屋是考古遗址建筑；富商只是 UNESCO 页面的推测，不是本件主人。"},
				{"text": "只有档案器形：圆腹平底、侧嘴横柄", "correct": false, "feedback": "这还没区分西屋、陶土与圣托里尼出土的容易误读关系。"},
			],
			"area": [
				{"text": "布展单：今晚在希腊厅 G-04 展柜", "correct": true, "requires": ["askos_delivery"], "feedback": "布展单写的是本次展馆位置，下一处去希腊厅 G-04。"},
				{"text": "UNESCO 说出土于圣托里尼，所以今晚在圣托里尼", "correct": false, "requires": ["askos_archive"], "feedback": "出土地不是今晚展馆位置；布展单才写本次展馆。"},
				{"text": "瓷器厅", "correct": false, "feedback": "瓷器厅不是这件目标的本展位。"},
			],
			"spot": [
				{"text": "西侧服务门 G-04", "correct": true, "requires": ["askos_service"], "feedback": "门牌 G-04 与展柜号对应上了。"},
				{"text": "北侧服务门 E-09", "correct": false, "feedback": "E-09 是埃及线，不是这件。"},
			],
		},
	},
}


static func target_ids() -> Array[String]:
	var out: Array[String] = []
	for id in TARGETS.keys():
		out.append(id)
	return out


## 只返回已完成可玩线的目标；埃及/希腊在补全并核事实前不进入板面选择。
static func ready_target_ids() -> Array[String]:
	var out: Array[String] = []
	for id in TARGETS.keys():
		var entry: Dictionary = TARGETS[id]
		if bool(entry.get("ready", false)):
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


static func default_position(target_id: String, material_id: String) -> Vector2:
	var entry: Dictionary = TARGETS.get(target_id, {})
	var positions: Dictionary = entry.get("positions", {})
	if positions.has(material_id):
		return positions[material_id]
	# 无预设时按材料顺序排成环形，避免全部叠在原点。
	var ids: Array = materials(target_id).keys()
	var idx := ids.find(material_id)
	if idx < 0:
		idx = 0
	var angle := TAU * float(idx) / maxf(1.0, float(ids.size()))
	return Vector2(0.5 + cos(angle) * 0.28, 0.5 + sin(angle) * 0.28)


## 某份材料可以作为哪些问题的证据；返回 [{question_id, relation_index, text, correct, requires, feedback}]。
static func relation_options_for_material(target_id: String, material_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var mat := material(target_id, material_id)
	for q in questions(target_id):
		var qid: String = q.get("id", "")
		if not (qid in mat.get("answers", [])):
			continue
		var rels: Array = relations(target_id, qid)
		for i in rels.size():
			var rel: Dictionary = rels[i]
			out.append({
				"question_id": qid,
				"relation_index": i,
				"text": rel.get("text", ""),
				"correct": rel.get("correct", false),
				"requires": rel.get("requires", []),
				"feedback": rel.get("feedback", ""),
			})
	return out


## 记录一次玩家连线选择。linked_materials 是当前已连到中心卡的材料 ID 列表。
## 正确关系要求其 requires 全部在 linked_materials 中；错误关系给出对应反馈但可重试。
static func record_relation(target_id: String, question_id: String, relation_index: int, linked_materials: Array[String]) -> Dictionary:
	var rels: Array = relations(target_id, question_id)
	if relation_index < 0 or relation_index >= rels.size():
		return {"ok": false, "feedback": "无效关系。"}
	var rel: Dictionary = rels[relation_index]
	for req in rel.get("requires", []):
		if not (String(req) in linked_materials):
			return {"ok": false, "feedback": "还缺少另一份材料，先把相关卡片连到中央档案。"}
	var ok := rel.get("correct", false) as bool
	if ok:
		Game.set_story_flag("inv_%s_%s_ok" % [target_id, question_id])
	return {"ok": ok, "feedback": rel.get("feedback", "")}


static func material_type_label(mtype: String) -> String:
	match mtype:
		"web": return "网页"
		"archive": return "档案"
		"mail": return "邮件"
		"chat": return "聊天"
		_: return "笔记"
