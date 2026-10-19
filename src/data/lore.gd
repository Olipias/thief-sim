class_name Lore
extends RefCounted
## 文物志：每件文物的叙事数据（器灵对谈剧本 + 展签卡 + 端详热点）。
##
## 设计约定（见 docs/ARTIFACT_SYSTEM_PROPOSAL.md）：
##   - 剧本条目类型：speech / card / choices / label / goto
##   - **史实一律走展签卡（card）**，器灵台词（speech）一律属演绎；
##     真实文物的史实内容必须在 docs/SOURCES.md 登记（cards 的 source 字段对应条目号）。
##   - 文本数据独立于 game_state.gd（避免与并行窗口冲突；加载通过 Game/Lore 静态访问）。
##
## 尺寸约定：hotspots 的 pos 为归一化坐标（0..1），对应 `closeup` 图。

const CLOSEUPS := {
	"mask": "res://assets/sprites/mask_closeup.png",
}

const ENTRIES := {
	"mask": {
		"title": "青铜人面具",
		"closeup": "res://assets/sprites/mask_closeup.png",
		"cards": {
			"mask_1": {
				"title": "商代青铜人面饰 · 基础",
				"body": "商代晚期（约公元前 13—前 11 世纪）。1976 年 10 月，陕西城固县苏村小冢的一处窖藏被村民清理姜窖时发现：一个直径约 1.3 米的坑里，有 23 件青铜面具，同出方罍、铜戈、兽面具与铜泡共 400 余件。面具脸形有椭圆与圆形两种。同类器物器身较薄、周边多有小穿孔，用途尚存争议——可能是祭祀礼仪用具，也可能是悬挂装饰或器物附饰。",
				"source": "来源：docs/SOURCES.md S-002（城固县博物馆介绍；城洋铜器群研究综述）",
			},
			"mask_2": {
				"title": "城洋铜器群 · 汉中的青铜之河",
				"body": "自 20 世纪 50 年代以来，陕西汉中城固、洋县境内的湑水河沿岸陆续出土商代青铜器 700 余件，学界称「城洋铜器群」。其年代从商代中期延续到商代晚期，特色器物正是人面与兽面面具、以及大量兵器。学者认为，这里处在商文化与巴蜀、地方文化交汇的要道上，是研究商代南方铜料流通与文化交流的关键材料。",
				"source": "来源：docs/SOURCES.md S-002（成都博物馆《城洋青铜器群》专文；考古报道）",
			},
			"mask_3": {
				"title": "文物现状",
				"body": "这批面具主要收藏于城固县博物馆，部分同类器物见于陕西历史博物馆等机构。1976 年苏村小冢窖藏是城洋铜器群最重要的发现之一；面具上扬的嘴角常被观众称为「三千年前的微笑」——它究竟是神祇、祖先，还是某个无名工匠的自画像，至今没有定论。",
				"source": "来源：docs/SOURCES.md S-002（馆藏介绍与新闻报道）",
			},
		},
		"hotspots": [
			{
				"pos": Vector2(0.50, 0.66),
				"label": "微笑的嘴",
				"fact": "嘴角明显上扬，是同类面具里最富表情的一件特征；这一「微笑」是观众的直观感受，古人是否在表达笑意，并无记载。",
				"ghost": "铸我的匠人先笑了。他说，面具要笑，神才肯来。",
			},
			{
				"pos": Vector2(0.50, 0.36),
				"label": "双目",
				"fact": "双眼呈杏核形，眼球微凸。商周人面饰的眼睛多强调「注视感」，与祭祀中「代神受祭」的观念相关。",
				"ghost": "我看了三千年。你猜我看腻了吗？",
			},
			{
				"pos": Vector2(0.14, 0.52),
				"label": "侧缘穿孔",
				"fact": "器身较薄，边缘常留有小孔，说明它可能被固定在木器、织物或器物表面——这也是学者称其为「面饰」而非单纯「面具」的原因。",
				"ghost": "别扯我耳朵——那是穿绳子的孔。我被人挂过，也被人埋过。",
			},
		],
		"stages": [
			[
				{"speaker": "器灵", "text": "又来个摸黑进来的。别怕，我不咬人——我连嘴都是铸出来的。"},
				{"speaker": "器灵", "text": "你盯着我看了三秒。上一个盯我这么久的人，把我从姜窖底下挖了出来——1976 年，城固，苏村。"},
				{
					"choices": [
						{"text": "「你笑什么？」", "goto": "smile"},
						{"text": "「你从哪来？」", "goto": "origin"},
						{"text": "「你能帮我吗？」", "goto": "help"},
					]
				},
				{"label": "smile"},
				{"speaker": "器灵", "text": "铸我的匠人先笑了。他说：面具要笑，神才肯来。"},
				{"card": "mask_1"},
				{"goto": "wrap"},
				{"label": "origin"},
				{"speaker": "器灵", "text": "湑水河边。那地方后来叫城固。同我一坑出来的，还有二十三张脸。"},
				{"card": "mask_1"},
				{"goto": "wrap"},
				{"label": "help"},
				{"speaker": "器灵", "text": "……先听我说完，再谈买卖。"},
				{"card": "mask_1"},
				{"label": "wrap"},
				{"speaker": "器灵", "text": "想听下去的话，凑近点，再来找我。"},
			],
			[
				{"speaker": "器灵", "text": "你回来了。问吧——汉中离商都千里，为什么会有这么多商代青铜器？"},
				{
					"choices": [
						{"text": "「商人的车队？」", "goto": "road"},
						{"text": "「这里的人自己铸的？」", "goto": "local"},
						{"text": "「我不知道，你告诉我。」", "goto": "tell"},
					]
				},
				{"label": "road"},
				{"speaker": "器灵", "text": "铜、锡、盐、玉——商人的车队顺着汉水往南走，走到我们那儿。铜是硬的，路是软的。"},
				{"goto": "wrap2"},
				{"label": "local"},
				{"speaker": "器灵", "text": "学的手艺，长的是自己的脸。北边铸鼎，南边铸我们。"},
				{"goto": "wrap2"},
				{"label": "tell"},
				{"speaker": "器灵", "text": "诚实。那我就多说两句——记住，别只听我讲，去翻他们的书。"},
				{"label": "wrap2"},
				{"card": "mask_2"},
				{"speaker": "器灵", "text": "书里写的是「城洋铜器群」。写书的人吵了三代人，还没吵完。"},
			],
			[
				{"speaker": "器灵", "text": "三千年，我埋在土里也笑。你问为什么？——因为我知道，总有人会把我挖出来，问我同一个问题。"},
				{"speaker": "器灵", "text": "带我出去之后，替我看看湑水河。它还在的话，就说我来过。"},
				{"card": "mask_3"},
			],
		],
	},
}


static func has_lore(item_id: String) -> bool:
	return ENTRIES.has(item_id)


static func stages(item_id: String) -> Array:
	var entry: Dictionary = ENTRIES.get(item_id, {})
	return entry.get("stages", [])


static func stage_count(item_id: String) -> int:
	return stages(item_id).size()


static func cards(item_id: String) -> Dictionary:
	var entry: Dictionary = ENTRIES.get(item_id, {})
	return entry.get("cards", {})


static func hotspots(item_id: String) -> Array:
	var entry: Dictionary = ENTRIES.get(item_id, {})
	return entry.get("hotspots", [])


static func closeup_path(item_id: String) -> String:
	var entry: Dictionary = ENTRIES.get(item_id, {})
	return String(entry.get("closeup", ""))
