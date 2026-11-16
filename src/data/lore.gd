class_name Lore
extends RefCounted
## 文物档案数据：每件文物的史实展签卡与端详热点。
##
## 设计约定（见 docs/ARTIFACT_SYSTEM_PROPOSAL.md）：
##   - 史实一律走展签卡（card），所有演绎/虚构内容已在 GDD v2 中移除。
##   - 卡片文本用世界观内的「展签」口吻，正式来源与声明集中在 src/data/statements.gd（声明页）。
##   - 文本数据独立于 game_state.gd（避免与并行窗口冲突；加载通过 Game/Lore 静态访问）。
##
## 尺寸约定：hotspots 的 pos 为归一化坐标（0..1），对应 `closeup` 图。

const CLOSEUPS := {
	"mask": "res://assets/sprites/mask_closeup.png",
	# 双羊尊没有对话剧本，但档案/端详页可以直接用 2.5D 特写大图（由混元 3D 渲染）
	"ram_zun": "res://assets/sprites/relic_ram_zun_closeup.png",
	# 埃及/希腊目标当前为占位图，待史料重绘（见 docs/art_direction/EVIDENCE_ART.md）。
	"egypt_heart_scarab": "res://assets/sprites/relic_egypt_heart_scarab_closeup.png",
	"akrotiri_askos": "res://assets/sprites/relic_akrotiri_askos_closeup.png",
}

## 哪些特写图是占位图（需在展示处加显式披露）。
const PLACEHOLDER_CLOSEUPS: Array[String] = ["egypt_heart_scarab", "akrotiri_askos"]

const ENTRIES := {
	"mask": {
		"title": "青铜人面具",
		"closeup": "res://assets/sprites/mask_closeup.png",
		"cards": {
			"mask_1": {
				"title": "商代青铜人面饰 · 基础",
				"body": "商代晚期（约公元前 13—前 11 世纪）。1976 年 10 月，陕西城固县苏村小冢的一处窖藏被村民清理姜窖时发现：一个直径约 1.3 米的坑里，有 23 件青铜面具，同出方罍、铜戈、兽面具与铜泡共 400 余件。面具脸形有椭圆与圆形两种。同类器物器身较薄、周边多有小穿孔，用途尚存争议——可能是祭祀礼仪用具，也可能是悬挂装饰或器物附饰。",
			},
			"mask_2": {
				"title": "城洋铜器群 · 汉中的青铜之河",
				"body": "自 20 世纪 50 年代以来，陕西汉中城固、洋县境内的湑水河沿岸陆续出土商代青铜器 700 余件，学界称「城洋铜器群」。其年代从商代中期延续到商代晚期，特色器物正是人面与兽面面具、以及大量兵器。学者认为，这里处在商文化与巴蜀、地方文化交汇的要道上，是研究商代南方铜料流通与文化交流的关键材料。",
			},
			"mask_3": {
				"title": "文物现状",
				"body": "这批面具主要收藏于城固县博物馆，部分同类器物见于陕西历史博物馆等机构。1976 年苏村小冢窖藏是城洋铜器群最重要的发现之一；面具上扬的嘴角常被观众称为「三千年前的微笑」——它究竟是神祇、祖先，还是某个无名工匠的自画像，至今没有定论。",
			},
		},
		"hotspots": [
			{
				"pos": Vector2(0.50, 0.66),
				"label": "微笑的嘴",
				"fact": "嘴角明显上扬，是同类面具里最富表情的一件特征；这一「微笑」是观众的直观感受，古人是否在表达笑意，并无记载。",
			},
			{
				"pos": Vector2(0.50, 0.36),
				"label": "双目",
				"fact": "双眼呈杏核形，眼球微凸。商周人面饰的眼睛多强调「注视感」，与祭祀中「代神受祭」的观念相关。",
			},
			{
				"pos": Vector2(0.14, 0.52),
				"label": "侧缘穿孔",
				"fact": "器身较薄，边缘常留有小孔，说明它可能被固定在木器、织物或器物表面——这也是学者称其为「面饰」而非单纯「面具」的原因。",
			},
		],
	},
	"ram_zun": {
		"title": "商代双羊尊",
		"closeup": "res://assets/sprites/relic_ram_zun_closeup.png",
		"cards": {
			"zun_1": {
				"title": "商代双羊尊 · 形制与年代",
				"body": "商代晚期，约公元前 1200—1050 年。高 45.1 厘米，宽 41.0 厘米，重 10.6 千克。双羊背向而立，共负一尊；羊角盘曲，角尖内卷。器身满饰兽面纹与雷纹，扉棱突出。现藏大英博物馆，馆藏编号 1936,1118.1。同类器存世仅两件，另一件藏于日本东京根津美术馆。",
			},
			"zun_2": {
				"title": "南方青铜 · 湖南推定",
				"body": "此器风格与安阳殷墟所出铜器不同：羊角先铸后接，器身大量使用垫片，被认为属长江流域的南方青铜传统。馆方与研究者均称其「传出自湖南」（said to be from Hunan）——这是产地推定，不是出土地记录。具体出土时间、地点与器主，至今没有可查的考古记录。",
			},
			"zun_3": {
				"title": "1936 · 一次有记录的转手",
				"body": "可考的是：1934—1936 年间，英国收藏家乔治·尤摩弗帕勒斯（George Eumorfopoulos）因经济压力将大批中国艺术品售予大英博物馆与 V&A；双羊尊于 1936 年入藏，编号 1936,1118.1。不可考的是：他如何获得此器、它何时以何种方式离开中国。民间相传它 1860 年毁于圆明园——此说只见于现代文章与文学化叙述，目前没有博物馆记录或学术来源支持。",
			},
		},
		"hotspots": [
			{
				"pos": Vector2(0.32, 0.30),
				"label": "羊角",
				"fact": "羊角先铸成形，再与器身锁接；角尖内卷，接缝处可见铸接痕。这种分铸再合的做法，是南方青铜器工艺的特征之一。",
			},
			{
				"pos": Vector2(0.50, 0.42),
				"label": "背脊接缝",
				"fact": "双羊背向而立，共用一尊腹。器身以多块陶范分铸合范，接缝多以扉棱掩盖。两羊之间没有留下焊缝。",
			},
			{
				"pos": Vector2(0.62, 0.66),
				"label": "垫片痕",
				"fact": "器腹与足部可见垫片痕。垫片用于在铸造时支撑内外范，是商代青铜器工艺的常见证据；它留下的痕迹不是损伤。",
			},
			{
				"pos": Vector2(0.24, 0.72),
				"label": "锈色",
				"fact": "青铜表面锈色不均，是埋藏环境与后世清理共同留下的痕迹。博物馆通常保留稳定的锈层，不把它磨成新铜的颜色。",
			},
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
	if CLOSEUPS.has(item_id):
		return String(CLOSEUPS[item_id])
	var entry: Dictionary = ENTRIES.get(item_id, {})
	return String(entry.get("closeup", ""))


static func is_placeholder_closeup(item_id: String) -> bool:
	return item_id in PLACEHOLDER_CLOSEUPS
