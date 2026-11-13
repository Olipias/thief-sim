class_name EvidenceData
extends RefCounted
## 安全屋推理链与电脑/手机跨应用线索数据库（P3 / P6）。
##
## 设计约定（见 docs/GDD_V2.md）：
##   - 无任何倒计时。
##   - 三条推理链：ram_zun（中国·商代双羊尊）、egypt_stela（埃及·第19王朝彩绘墓碑）、greek_relief（希腊·帕特农骑手浮雕）。
##   - 每条链包含分布在「电脑·档案库 / 电脑·浏览器 / 电脑·邮件 / 手机·聊天与通讯录」中的 3 张核心线索卡；
##     收集 3 张卡并在推理板完成两两连线（cl_1->cl_2, cl_2->cl_3）即解锁对应展厅盗取目标。

const CHAINS := {
	"ram_zun": {
		"title": "中国馆 · 商代双羊尊",
		"target_id": "ram_zun",
		"flag_unlocked": "chain_ram_zun_done",
		"summary": "大英博物馆 Room 33 青铜礼器厅核心展品（1936,1118.1），重 10.6kg，需核清入藏展位、底座承重与夜巡换岗窗口。",
		"clues": {
			"zun_archive": {
				"id": "zun_archive",
				"source_app": "pc_archive",
				"title": "1936 尤摩弗帕勒斯入藏批次",
				"body": "【馆藏档案】编号 1936,1118.1，商代晚期双羊尊，1936 年购自 George Eumorfopoulos 旧藏。现陈列于中国馆青铜礼器厅中央独立恒温柜。",
			},
			"zun_tech": {
				"id": "zun_tech",
				"source_app": "pc_browser",
				"title": "双羊尊金相与承重底座报告",
				"body": "【研究摘录】器高 45.1cm，重 10.6kg，传出自湖南（羊角分铸锁接、器身垫片）。展台采用重力感应卡扣，必须在切断侧墙配电箱后 3 秒内平稳托起。",
			},
			"zun_chat": {
				"id": "zun_chat",
				"source_app": "phone_chat",
				"title": "内线：青铜厅夜巡交接单",
				"body": "【手机密信·老猫】青铜厅夜班只有两名保安按回字路线对穿，东侧装卸走廊的机械锁密码与 1936 入藏年份后四位一致。",
			},
		},
		"required_links": [
			["zun_archive", "zun_tech"],
			["zun_tech", "zun_chat"],
		],
	},

	"egypt_stela": {
		"title": "埃及馆 · 第19王朝彩绘墓碑",
		"target_id": "egypt_stela",
		"flag_unlocked": "chain_egypt_stela_done",
		"summary": "大英博物馆埃及雕塑侧厅馆藏（EA191），出自底比斯代尔麦地那工匠村，需核清索尔特入藏记录、碑文工匠身份与通风廊路线。",
		"clues": {
			"egypt_archive": {
				"id": "egypt_archive",
				"source_app": "pc_archive",
				"title": "1823 亨利·索尔特入藏目录",
				"body": "【馆藏档案】编号 EA191（1823,0614.1），新王国第 19 王朝石灰岩彩绘墓碑，英国驻埃及总领事 Henry Salt 采办并售予本馆，现置西侧埃及廊。",
			},
			"egypt_browser": {
				"id": "egypt_browser",
				"source_app": "pc_browser",
				"title": "代尔麦地那工匠墓葬考据",
				"body": "【学术网页】碑主为王陵石匠 Qaha，碑体薄而边缘留有楔槽；展柜仅在正面布设红外幕帘，从背面检修槽可绕开光束。",
			},
			"egypt_mail": {
				"id": "egypt_mail",
				"source_app": "pc_mail",
				"title": "中间人邮件：西侧通风廊图纸",
				"body": "【加密邮件】买主指名要底比斯工匠碑。西侧通道的旧通风栅栏螺丝已松动，带一把十字改锥即可从埃及廊北门直通撤离口。",
			},
		},
		"required_links": [
			["egypt_archive", "egypt_browser"],
			["egypt_browser", "egypt_mail"],
		],
	},

	"greek_relief": {
		"title": "希腊馆 · 帕特农骑手浮雕残块",
		"target_id": "greek_relief",
		"flag_unlocked": "chain_greek_relief_done",
		"summary": "大英博物馆杜维恩展厅馆藏（1816,0610.28），原属雅典卫城帕特农神庙北翼浮雕，需核清 1816 收购卷宗、维护支架位置与外包商通道钥匙。",
		"clues": {
			"greek_archive": {
				"id": "greek_archive",
				"source_app": "pc_archive",
				"title": "1816 议会收购卷宗与杜维恩图",
				"body": "【馆藏档案】编号 1816,0610.28，帕特农神庙北翼骑手浮雕，1801–1805 年由额尔金伯爵拆运，1816 年议会购入。本周因激光清洗移至杜维恩厅南端独立维护架。",
			},
			"greek_browser": {
				"id": "greek_browser",
				"source_app": "pc_browser",
				"title": "卫城博物馆浮雕复原对照表",
				"body": "【公开数据库】该残块为切割减薄后的边角块（可单人装入加固背架）；维护架配有定角摄像头，每 4 秒左右摆动一次，盲区在立柱内侧。",
			},
			"greek_chat": {
				"id": "greek_chat",
				"source_app": "phone_chat",
				"title": "外包维修工的聊天记录",
				"body": "【手机截屏】清洗队把杜维恩西侧消防门的备用钥匙卡忘在门卫储物格里了，拿到卡就能走西通道直达装卸区。",
			},
		},
		"required_links": [
			["greek_archive", "greek_browser"],
			["greek_browser", "greek_chat"],
		],
	},
}


static func chain_ids() -> Array[String]:
	return ["ram_zun", "egypt_stela", "greek_relief"]


static func chain(chain_id: String) -> Dictionary:
	return CHAINS.get(chain_id, {})


static func clues_for_app(app_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cid in chain_ids():
		var c: Dictionary = CHAINS[cid]
		var clues: Dictionary = c.get("clues", {})
		for clue_id in clues:
			var item: Dictionary = clues[clue_id]
			if String(item.get("source_app", "")) == app_id:
				var copy := item.duplicate()
				copy["chain_id"] = cid
				out.append(copy)
	return out
