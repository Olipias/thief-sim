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
				"title": "卡片一 · 1936 年（馆藏记录）",
				"body": "1936 年，伦敦。购自乔治·尤摩弗帕勒斯（George Eumorfopoulos）旧藏，馆藏编号 1936,1118.1。其中有一件：商代双羊尊。",
			},
			"card_1860": {
				"title": "卡片二 · 1860 年（网络传闻）",
				"body": "1860 年，圆明园。网上抄来的，没有任何档案编号与出处。",
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

	"p00_devil_contract": {
		"cards": {
			"contract_clause": {
				"title": "无名契约 · 附页",
				"body": "「甲方替乙方进入指定馆藏地取回三件旧物之一；契约期间，乙方借予甲方穿过夜色与听见器物残响之能。逾期或私吞，连本带利收回。」",
			},
		},
		"script": [
			{"speaker": "旁白", "text": "雨夜。洗衣店后屋的灯还没亮，桌上一纸契约自己燃着暗红色的边。"},
			{"speaker": "恶魔（低语）", "text": "按了手印，这双手就暂时归我使唤。"},
			{"card": "contract_clause"},
			{"speaker": "恶魔（低语）", "text": "先去城西博物馆拿那张青铜面具——算我教你认认门路。"},
			{"speaker": "恶魔（低语）", "text": "真正的差事在伦敦。三个展厅，三件旧物，你替我查清楚、带一件回来。"},
			{
				"choices": [
					{"text": "「只拿一件？」", "goto": "p00_one"},
					{"text": "「要是我半路反悔呢？」", "goto": "p00_regret"},
					{"text": "（按手印，不废话。）", "goto": "p00_sign"},
				],
			},
			{"label": "p00_one"},
			{"speaker": "恶魔（低语）", "text": "贪多的人走不出那扇玻璃门。查清哪一件的锁绽了，就拿哪一件。"},
			{"goto": "p00_done"},
			{"label": "p00_regret"},
			{"speaker": "恶魔（低语）", "text": "你可以试试看。上一个试的人，现在还贴在展柜玻璃上当影子。"},
			{"goto": "p00_done"},
			{"label": "p00_sign"},
			{"speaker": "恶魔（低语）", "text": "干脆。我喜欢不问东问西的合作者。"},
			{"label": "p00_done"},
			{"speaker": "旁白", "text": "灰烬落进铁皮桶。前屋传来老猫开卷帘门的声音。"},
		],
	},

	"p05_devil_demand": {
		"cards": {
			"wrath_scene": {
				"title": "恶魔发火 · 契约灼烧",
				"body": "安全屋的灯泡瞬间炸裂。墙面渗出暗红裂纹，桌上的契约纸腾起黑焰，整间屋子的影子都在朝你脚下聚拢。",
			},
			"ending_comply_card": {
				"title": "结局一 · 契约履行（顺从）",
				"body": "文物被装进没有编号的黑木匣，随契约灰烬一同消失在雨夜。你的账户多了一笔干净的赎金，指尖再也听不见器物的声音。\n\n【史实与虚构声明】现实中，商代双羊尊（1936,1118.1）、古埃及彩绘墓碑（EA191）与帕特农浮雕（1816,0610.28）仍藏于大英博物馆；本作中的恶魔契约、盗取与交割结局均为虚构演绎。来源见 docs/SOURCES.md。",
			},
			"ending_rebel_return_card": {
				"title": "结局二 · 反抗到底（归还建档）",
				"body": "你顶着灼烧的掌心把文物交到城南旧棉纺厂。阿岚在毛毡桌上拍下每一道铸痕，将 1936 年以来的流转一笔一笔写进公开档案——它不再是任何人的私产。\n\n【史实与虚构声明】现实中相关馆藏仍在大英博物馆；本作的归还渠道与结局为虚构的艺术讨论，旨在呈现「把每一笔流转写进档案」的公共史学理念。来源见 docs/SOURCES.md。",
			},
			"ending_rebel_broker_card": {
				"title": "结局三 · 反抗到底（背叛交易）",
				"body": "你甩开契约，将文物推上老秤的台秤。现金塞进帆布包，木箱钉死发往私人密室。你赢了恶魔一局，却让那件器物彻底沉入看不见光的地下账本。\n\n【史实与虚构声明】现实中相关馆藏仍在大英博物馆；本结局中的黑市交易与人物均为虚构演绎。来源见 docs/SOURCES.md。",
			},
		},
		"script": [
			{"speaker": "旁白", "text": "刚推开安全屋后门，屋里的灯就矮了一截。那个声音已经在桌边等着你了。"},
			{"speaker": "恶魔", "text": "东西带回来了。放桌上，按契约两清。"},
			{
				"choices": [
					{"text": "直接上交文物。（履行契约）", "goto": "p05_hand_over"},
					{"text": "按住背包，拒绝交出。", "goto": "p05_refuse"},
				],
			},
			{"label": "p05_hand_over"},
			{"set_flag": "ending_id", "value": "comply"},
			{"speaker": "恶魔", "text": "聪明人。不该听的故事，忘掉最安全。"},
			{"card": "ending_comply_card"},
			{"goto": "p05_end"},

			{"label": "p05_refuse"},
			{"card": "wrath_scene"},
			{"speaker": "恶魔（震怒）", "text": "你用我借你的眼睛看清了路，现在想赖账？我再给你最后一次松手的机会！"},
			{
				"choices": [
					{"text": "屈服补交。（顺从契约）", "goto": "p05_submit_late"},
					{"text": "反抗到底：连夜送往阿岚的旧棉纺厂。（归还建档）", "goto": "p05_rebel_return"},
					{"text": "反抗到底：转手卖给黑市中间人老秤。（背叛交易）", "goto": "p05_rebel_broker"},
				],
			},
			{"label": "p05_submit_late"},
			{"set_flag": "ending_id", "value": "comply"},
			{"speaker": "恶魔", "text": "算你识相。记住今晚手腕上的烫痕。"},
			{"card": "ending_comply_card"},
			{"goto": "p05_end"},

			{"label": "p05_rebel_return"},
			{"set_flag": "ending_id", "value": "return"},
			{"speaker": "阿岚", "text": "手怎么烫成这样？……别说话，放毛毡上。只要公开建了档，谁也别想再悄悄抹掉它。"},
			{"card": "ending_rebel_return_card"},
			{"goto": "p05_end"},

			{"label": "p05_rebel_broker"},
			{"set_flag": "ending_id", "value": "broker"},
			{"speaker": "老秤", "text": "敢截那位爷的胡，你胆子肥了。成，现金拿好，今夜之后换个城市喘气吧。"},
			{"card": "ending_rebel_broker_card"},
			{"label": "p05_end"},
			{"set_flag": "saw_p05"},
			{"speaker": "旁白", "text": "雨又下起来了。（可在结算页选择「从检查点返回安全屋」体验其余目标与分支）"},
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
