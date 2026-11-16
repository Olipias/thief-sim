class_name EvidenceData
extends RefCounted
## 用户资源包三目标；安保、借展和接洽均属虚构。
const CHAINS := {
	"ram_zun": {
		"title": "中国馆 · 商代双羊尊",
		"target_id": "ram_zun",
		"flag_unlocked": "chain_ram_zun_done",
		"summary": "对照来源、年代、材质与登记信息，分清公开史实和游戏虚构委托，再完成跨应用关联，确定本次行动的单件目标。",
		"clues": {
			"zun_archive": {
				"id": "zun_archive",
				"source_app": "pc_archive",
				"title": "1936 尤摩弗帕勒斯入藏批次",
				"body": "【馆藏档案】编号1936,1118.1，商代晚期双羊尊，1936年购自George Eumorfopoulos旧藏。更早的出境方式没有公开确证，不能据此断言1860年被掠。"
			},
			"zun_tech": {
				"id": "zun_tech",
				"source_app": "pc_browser",
				"title": "双羊尊来源断点与南方青铜传统",
				"body": "【研究摘录】高45.1厘米、重10.6千克；传出自湖南属于产地推定，并不是有记录的出土地。收藏记录与器物研究回答的是不同问题，应对照入藏编号。"
			},
			"zun_chat": {
				"id": "zun_chat",
				"source_app": "phone_chat",
				"title": "内线：青铜厅夜巡交接单",
				"body": "【虚构密信】老猫说：中国厅本周维护，东侧装卸走廊是撤离方向。1910年的捐赠单属于另一件器物；这件要核对1936年入藏的来源断点。"
			}
		},
		"required_links": [
			[
				"zun_archive",
				"zun_tech"
			],
			[
				"zun_tech",
				"zun_chat"
			]
		]
	},
	"egypt_heart_scarab": {
		"title": "埃及馆 · 心形圣甲虫",
		"target_id": "egypt_heart_scarab",
		"flag_unlocked": "chain_egypt_heart_scarab_done",
		"summary": "对照来源、年代、材质与登记信息，分清公开史实和游戏虚构委托，再完成跨应用关联，确定本次行动的单件目标。",
		"clues": {
			"scarab_archive": {
				"id": "scarab_archive",
				"source_app": "pc_archive",
				"title": "1910 古尔德捐赠与圣甲虫编号",
				"body": "【馆藏档案】心形圣甲虫，大都会艺术博物馆编号10.130.1650，来自埃及，约前664–332年，深绿色石材，长6.1厘米。Helen Miller Gould于1910年捐赠。"
			},
			"scarab_browser": {
				"id": "scarab_browser",
				"source_app": "pc_browser",
				"title": "晚期埃及护符的尺寸与来源断点",
				"body": "【公开馆藏】大都会条目可核对材质、尺寸与捐赠信息，未提供本件正式追索记录。不能把一般归还讨论当作本件已经被正式追索；游戏借展与追索委托均属虚构。"
			},
			"scarab_mail": {
				"id": "scarab_mail",
				"source_app": "pc_mail",
				"title": "学者来信：核对绿色护符而非墓碑",
				"body": "【虚构邮件】埃及裔学者：我找的是长6.1厘米的绿色护符，不是EA191墓碑。请对照1910年捐赠记录与编号。若愿意接洽，可以回复邮件，具体交易为虚构。"
			}
		},
		"required_links": [
			[
				"scarab_archive",
				"scarab_browser"
			],
			[
				"scarab_browser",
				"scarab_mail"
			]
		]
	},
	"akrotiri_askos": {
		"title": "希腊馆 · 阿克罗蒂里彩绘注壶",
		"target_id": "akrotiri_askos",
		"flag_unlocked": "chain_akrotiri_askos_done",
		"summary": "对照来源、年代、材质与登记信息，分清公开史实和游戏虚构委托，再完成跨应用关联，确定本次行动的单件目标。",
		"clues": {
			"askos_archive": {
				"id": "askos_archive",
				"source_app": "pc_archive",
				"title": "阿克罗蒂里西屋注壶登记",
				"body": "【公开登记】UNESCO失窃文物虚拟博物馆编号VM-GR-25-012，约前1650–1615年彩绘陶注壶，由希腊提交，发现于阿克罗蒂里西屋；公开条目未交代现藏地与失窃经过。"
			},
			"askos_browser": {
				"id": "askos_browser",
				"source_app": "pc_browser",
				"title": "侧嘴横柄与螺旋纹样的识别",
				"body": "【公开条目】注壶圆腹、平底、横柄，侧面有倾倒液体的壶嘴，肩部螺旋纹、腹部条纹。应把形制线索与西屋发现记录结合，不要误认为帕特农浮雕。"
			},
			"askos_chat": {
				"id": "askos_chat",
				"source_app": "phone_chat",
				"title": "基金会来电：核对西屋与侧嘴",
				"body": "【虚构来电】基金会：请核查西屋、侧嘴与螺旋肩纹是否指向同一编号。我们的接洽渠道和博物馆借展均是剧情安排；UNESCO的登记不证明现实中该器正在伦敦。"
			}
		},
		"required_links": [
			[
				"askos_archive",
				"askos_browser"
			],
			[
				"askos_browser",
				"askos_chat"
			]
		]
	}
}

static func chain_ids() -> Array[String]:
	return ["ram_zun", "egypt_heart_scarab", "akrotiri_askos"]


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
