class_name OpeningCG
extends RefCounted
## 用户q6分镜：原图保留，四个气泡短对白，六个多边形在运行时裁切。
const ART_PATH := "res://assets/art/opening/q6_chibi_storyboard_dialogue.png"
const SOURCE_SIZE := Vector2(1536, 1024)
const PANEL_SECONDS := 5.0
const PANELS := [
	{"title": "桥下 · 结账", "caption": "线人：钱只剩这些了。", "points": [Vector2(20, 20), Vector2(625, 20), Vector2(571, 479), Vector2(511, 505), Vector2(20, 505)]},
	{"title": "戒指 · 抵款", "caption": "线人：这枚戒指抵余款。", "points": [Vector2(646, 22), Vector2(1028, 22), Vector2(958, 496), Vector2(612, 463), Vector2(590, 433)]},
	{"title": "意外 · 收下", "caption": "我：这能值几个钱？", "points": [Vector2(1049, 20), Vector2(1516, 20), Vector2(1516, 530), Vector2(1000, 510)]},
	{"title": "住处 · 异样", "caption": "回到住处，戒指忽然发烫。", "points": [Vector2(20, 520), Vector2(510, 520), Vector2(436, 1004), Vector2(20, 1004)]},
	{"title": "恶魔 · 契约", "caption": "恶魔：收下即签约。先偷青铜面具。违约，命归我。", "points": [Vector2(540, 526), Vector2(612, 483), Vector2(985, 520), Vector2(901, 1004), Vector2(455, 1004)]},
	{"title": "第一单 · 出发", "caption": "我：先去博物馆拿青铜面具。", "points": [Vector2(1007, 531), Vector2(1516, 551), Vector2(1516, 1004), Vector2(921, 1004)]},
]
