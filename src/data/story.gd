class_name Story
extends RefCounted
## 据点剧情（P-01 / H-01 / H-02）与结局相关对话数据。
##
## 设计约定：
##   - 史实/档案信息一律走 card；角色台词与旁白属演绎。
##   - 文本独立于 game_state.gd，通过静态类访问，避免并行冲突。

const ENTRIES := {
	"p01_door_in_rain": {
		"cards": {
			"mask_photo": {
				"title": "老猫推来的照片",
				"body": "城西博物馆展台上的青铜面具，灯光很亮。照片背面有一行铅笔字：「夜里有人笑。」",
			},
		},
		"script": [
			{"speaker": "老猫", "text": "会撬锁吗？"},
			{
				"choices": [
					{"text": "会。", "goto": "p01_lock_yes"},
					{"text": "不会。", "goto": "p01_lock_no"},
					{"text": "会一点。", "goto": "p01_lock_little"},
				],
			},
			{"label": "p01_lock_yes"},
			{"speaker": "老猫", "text": "会的人一般活不长。"},
			{"goto": "p01_rules"},
			{"label": "p01_lock_no"},
			{"speaker": "老猫", "text": "诚实。这行不奖励诚实，但我奖励。"},
			{"goto": "p01_rules"},
			{"label": "p01_lock_little"},
			{"speaker": "老猫", "text": "会一点的最麻烦。"},
			{"goto": "p01_rules"},

			{"label": "p01_rules"},
			{"speaker": "老猫", "text": "三条规矩。不碰不该碰的。不问不该问的。不留名字。"},
			{
				"choices": [
					{"text": "什么是不该碰的？", "goto": "p01_rules_1"},
					{"text": "记住了。", "goto": "p01_rules_2"},
					{"text": "我能不能用假名？", "goto": "p01_rules_3"},
				],
			},
			{"label": "p01_rules_1"},
			{"speaker": "老猫", "text": "问得好。第二条作废。"},
			{"goto": "p01_job"},
			{"label": "p01_rules_2"},
			{"speaker": "老猫", "text": "你记性不错。可惜这行靠的是忘性。"},
			{"goto": "p01_job"},
			{"label": "p01_rules_3"},
			{"speaker": "老猫", "text": "可以。假名也是名字。"},
			{"goto": "p01_job"},

			{"label": "p01_job"},
			{"card": "mask_photo"},
			{"speaker": "老猫", "text": "城西博物馆。青铜人面饰。保安说，夜里有人笑。"},
			{
				"choices": [
					{"text": "是风声。", "goto": "p01_laugh_wind"},
					{"text": "是老鼠。", "goto": "p01_laugh_rat"},
					{"text": "是它在笑。", "goto": "p01_laugh_it"},
				],
			},
			{"label": "p01_laugh_wind"},
			{"speaker": "老猫", "text": "你倒是不怕。"},
			{"goto": "p01_end"},
			{"label": "p01_laugh_rat"},
			{"speaker": "老猫", "text": "怕的人活得久。"},
			{"goto": "p01_end"},
			{"label": "p01_laugh_it"},
			{"speaker": "老猫", "text": "……那你跟它聊。"},
			{"goto": "p01_end"},

			{"label": "p01_end"},
			{"speaker": "老猫", "text": "东西没有家。人有。记住这句，能少很多麻烦。"},
			{"speaker": "旁白", "text": "雨停了。你出门时，他把熨斗关了。衬衫还是湿的。"},
		],
	},

	"h01_label_lesson": {
		"cards": {
			"card_1936": {
				"title": "卡片一 · 1936 年",
				"body": "伦敦。一个英国收藏家把一批中国青铜器卖给了博物馆。其中有一件，双羊尊。",
			},
			"card_1860": {
				"title": "卡片二 · 1860 年",
				"body": "圆明园。网上抄的。",
			},
		},
		"script": [
			{"speaker": "沈先生", "text": "坐。别碰桌上的东西。"},
			{"card": "card_1936"},
			{"speaker": "沈先生", "text": "1936 年，伦敦。一个英国收藏家，把一批中国青铜器卖给了博物馆。其中有一件，双羊尊。"},
			{"card": "card_1860"},
			{"speaker": "沈先生", "text": "这张是网上抄的。1860 年，圆明园。"},
			{"speaker": "沈先生", "text": "一张说它被买过。一张说它被烧过。你信哪个？"},
			{
				"choices": [
					{"text": "信标签。它有编号。", "goto": "h01_trust_label"},
					{"text": "信留言。它有恨。", "goto": "h01_trust_note"},
					{"text": "都不信。", "goto": "h01_trust_none"},
				],
			},
			{"label": "h01_trust_label"},
			{"speaker": "沈先生", "text": "标签有编号，有日期，有买家。它不一定全对，但它可以被查。"},
			{"goto": "h01_lesson"},
			{"label": "h01_trust_note"},
			{"speaker": "沈先生", "text": "留言有情绪，没有证据。可情绪传得比档案快。"},
			{"goto": "h01_lesson"},
			{"label": "h01_trust_none"},
			{"speaker": "沈先生", "text": "聪明。也是懒。都不信，就不用去找了。"},
			{"goto": "h01_lesson"},

			{"label": "h01_lesson"},
			{"speaker": "沈先生", "text": "记住三个词。可考。不可考。传说。"},
			{"speaker": "沈先生", "text": "可考的，写进档案。不可考的，留白。传说的，别写成事实。"},
			{"speaker": "玩家", "text": "那它到底是不是被抢的？"},
			{"speaker": "沈先生", "text": "我不知道。档案也不知道。档案只知道它 1936 年在伦敦被卖过一次。"},
			{"speaker": "沈先生", "text": "明天你带回来的东西，会有一张新标签。标签上写什么，取决于你把它交给谁。"},
			{"speaker": "旁白", "text": "台灯闪了一下。你下楼时，听见他在背后咳嗽，咳了很久。"},
		],
	},

	"h02_two_addresses": {
		"cards": {
			"return_address": {
				"title": "阿岚递来的地址",
				"body": "城南，旧棉纺厂，第三排。纸是湿的，字没花。",
			},
		},
		"script": [
			{"speaker": "阿岚", "text": "你是新来的。"},
			{
				"choices": [
					{"text": "你是谁？", "goto": "h02_who"},
					{"text": "老猫不让陌生人进来。", "goto": "h02_stranger"},
					{"text": "（沉默）", "goto": "h02_silent"},
				],
			},
			{"label": "h02_who"},
			{"speaker": "阿岚", "text": "我是替东西收信的人。"},
			{"goto": "h02_paper"},
			{"label": "h02_stranger"},
			{"speaker": "阿岚", "text": "我不是陌生人。我认识他比认识你久。"},
			{"goto": "h02_paper"},
			{"label": "h02_silent"},
			{"speaker": "阿岚", "text": "沉默也好。沉默的人不容易卖人。"},
			{"goto": "h02_paper"},

			{"label": "h02_paper"},
			{"speaker": "旁白", "text": "她递过来一张折起来的纸。纸是湿的，字没花。"},
			{"speaker": "阿岚", "text": "如果你在里面听见什么，别急着回答。"},
			{
				"choices": [
					{"text": "收下。", "goto": "h02_take"},
					{"text": "不收。", "goto": "h02_refuse"},
					{"text": "为什么给我？", "goto": "h02_why"},
				],
			},
			{"label": "h02_take"},
			{"speaker": "阿岚", "text": "谢谢。"},
			{"goto": "h02_address"},
			{"label": "h02_refuse"},
			{"speaker": "阿岚", "text": "那我放在门缝里。你出门的时候会踩到。"},
			{"speaker": "旁白", "text": "她真的放在门缝里。"},
			{"goto": "h02_address"},
			{"label": "h02_why"},
			{"speaker": "阿岚", "text": "因为有些东西等不了一百年。"},
			{"goto": "h02_address"},

			{"label": "h02_address"},
			{"card": "return_address"},
			{"speaker": "阿岚", "text": "别把地址给老猫。他会烧了它。"},
			{"speaker": "旁白", "text": "地址上只有一行字——「城南，旧棉纺厂，第三排。」纸是湿的，字没花。"},
		],
	},
}


static func has_entry(entry_id: String) -> bool:
	return ENTRIES.has(entry_id)


static func script(entry_id: String) -> Array:
	var entry: Dictionary = ENTRIES.get(entry_id, {})
	return entry.get("script", [])


static func cards(entry_id: String) -> Dictionary:
	var entry: Dictionary = ENTRIES.get(entry_id, {})
	return entry.get("cards", {})
