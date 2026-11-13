class_name Lore
extends RefCounted
## 文物志：每件文物的叙事数据（器灵对谈剧本 + 展签卡 + 端详热点）。
##
## 设计约定（见 docs/ARTIFACT_SYSTEM_PROPOSAL.md）：
##   - 剧本条目类型：speech / card / choices / label / goto
##   - **史实一律走展签卡（card）**，器灵台词（speech）一律属演绎；
##     卡片文本用世界观内的「展签」口吻，正式来源与声明集中在 src/data/statements.gd（声明页）。
##   - 文本数据独立于 game_state.gd（避免与并行窗口冲突；加载通过 Game/Lore 静态访问）。
##
## 尺寸约定：hotspots 的 pos 为归一化坐标（0..1），对应 `closeup` 图。

const CLOSEUPS := {
	"mask": "res://assets/sprites/mask_closeup.png",
	# 双羊尊没有文物志剧本，但档案/端详页可以直接用 2.5D 特写大图（由混元 3D 渲染）
	"ram_zun": "res://assets/sprites/relic_ram_zun_closeup.png",
}

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
				"ghost": "左羊：角是我身上最后装上去的。装的时候，铜还是热的。",
			},
			{
				"pos": Vector2(0.50, 0.42),
				"label": "背脊接缝",
				"fact": "双羊背向而立，共用一尊腹。器身以多块陶范分铸合范，接缝多以扉棱掩盖。两羊之间没有留下焊缝。",
				"ghost": "右羊：我们背对着。三千年，谁也看不见谁。你是第一个站在中间的人。",
			},
			{
				"pos": Vector2(0.62, 0.66),
				"label": "垫片痕",
				"fact": "器腹与足部可见垫片痕。垫片用于在铸造时支撑内外范，是商代青铜器工艺的常见证据；它留下的痕迹不是损伤。",
				"ghost": "左羊：那些小铜片不是伤。是骨头。撑着我，别让我在火里塌下去。",
			},
			{
				"pos": Vector2(0.24, 0.72),
				"label": "锈色",
				"fact": "青铜表面锈色不均，是埋藏环境与后世清理共同留下的痕迹。博物馆通常保留稳定的锈层，不把它磨成新铜的颜色。",
				"ghost": "右羊：他们管这叫「包浆」。我管这叫结痂。",
			},
		],
		"stages": [
			[
				{"speaker": "右羊", "text": "别跑。你一晃，我就想起船。"},
				{"speaker": "左羊", "text": "你是新来的。上一个碰我的人，戴手套。"},
				{
					"choices": [
						{"text": "「你们是两只羊？」", "goto": "two"},
						{"text": "「你们是同一件东西。」", "goto": "one"},
						{"text": "（不说话，等它们先说。）", "goto": "wait"},
					]
				},
				{"label": "two"},
				{"speaker": "右羊", "text": "一件东西。两段记性。"},
				{"speaker": "左羊", "text": "他记海。我记土。"},
				{"goto": "ask"},
				{"label": "one"},
				{"speaker": "左羊", "text": "对。也错。"},
				{"speaker": "右羊", "text": "你试试被铸在一起，再被卖一次。"},
				{"goto": "ask"},
				{"label": "wait"},
				{"speaker": "右羊", "text": "他不说话。像博物馆的人。"},
				{"speaker": "左羊", "text": "博物馆的人也不说话。"},
				{"label": "ask"},
				{"speaker": "左羊", "text": "你做的东西，会记得你吗？"},
				{
					"choices": [
						{"text": "「会。」", "goto": "yes"},
						{"text": "「不会。」", "goto": "no"},
						{"text": "「我不知道。」", "goto": "dunno"},
					]
				},
				{"label": "yes"},
				{"speaker": "左羊", "text": "那你得先做出点东西。"},
				{"goto": "wrap"},
				{"label": "no"},
				{"speaker": "左羊", "text": "诚实。我做了三千年，也没等到它叫我一声。"},
				{"goto": "wrap"},
				{"label": "dunno"},
				{"speaker": "左羊", "text": "我也不知道。我们可以一起不知道。"},
				{"label": "wrap"},
				{"card": "zun_1"},
				{"speaker": "右羊", "text": "有人来了。走。"},
			],
			[
				{"speaker": "左羊", "text": "我告诉你我是怎么来的。你替我记着。"},
				{"speaker": "左羊", "text": "范土是湿的。铜水是亮的。角先铸，再锁上去。那只手很稳。"},
				{"speaker": "右羊", "text": "他记得手。我记得箱子。"},
				{
					"choices": [
						{"text": "「先听左羊。」", "goto": "left"},
						{"text": "「先听右羊。」", "goto": "right"},
						{"text": "「先听展签。」", "goto": "card"},
					]
				},
				{"label": "left"},
				{"speaker": "左羊", "text": "铸我的人没留名字。器成，人散。"},
				{"goto": "sea"},
				{"label": "right"},
				{"speaker": "右羊", "text": "箱子有铁皮边。海上有盐。灯一照，我就知道我又被卖了。"},
				{"goto": "sea"},
				{"label": "card"},
				{"speaker": "左羊", "text": "你倒是省事。"},
				{"speaker": "右羊", "text": "标签上没写我们怎么想。"},
				{"label": "sea"},
				{"card": "zun_2"},
				{"speaker": "右羊", "text": "另一只羊在东京。它比我先到。它没等我。"},
				{"speaker": "左羊", "text": "我们本来背对着。看不见彼此。"},
				{"speaker": "右羊", "text": "前面有光。是出口，还是展柜？"},
				{"speaker": "左羊", "text": "有区别吗。"},
				{"speaker": "右羊", "text": "有。展柜有玻璃。"},
			],
			[
				{"speaker": "右羊", "text": "你还在。"},
				{"speaker": "左羊", "text": "灯要灭了。"},
				{
					"choices": [
						{"text": "「我带你们出去。」", "goto": "out"},
						{"text": "「我不知道带你们去哪。」", "goto": "lost"},
						{"text": "「你们想回家吗？」", "goto": "home"},
					]
				},
				{"label": "out"},
				{"speaker": "右羊", "text": "出去之后呢？"},
				{"speaker": "左羊", "text": "别问。问了他就不带了。"},
				{"goto": "ask"},
				{"label": "lost"},
				{"speaker": "左羊", "text": "诚实。"},
				{"speaker": "右羊", "text": "诚实不能当船票。"},
				{"goto": "ask"},
				{"label": "home"},
				{"speaker": "左羊", "text": "家是土。土没了。"},
				{"speaker": "右羊", "text": "家是没被标价的地方。那种地方不存在。"},
				{"label": "ask"},
				{"card": "zun_3"},
				{"speaker": "左羊", "text": "如果你要把我们交出去，别交给会包箱子的人。"},
				{"speaker": "右羊", "text": "交给会写字的人。"},
				{"speaker": "左羊", "text": "……还有。谢谢你站在中间。"},
				{"speaker": "右羊", "text": "（很轻）别把我们忘了。"},
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
	if CLOSEUPS.has(item_id):
		return String(CLOSEUPS[item_id])
	var entry: Dictionary = ENTRIES.get(item_id, {})
	return String(entry.get("closeup", ""))
