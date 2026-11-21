class_name MissionPhone
extends CanvasLayer
## 任务终端（手机）：右下角图标点开。
## R-04：安全屋模式以应用图标首页进入 委托 / 交易 / 联系人 / 日历（不复刻旧 Hub 栏目页）；
## 行动中保持旧「任务 / 档案」标签布局。「委托」确认只记录待出发（Game.pending_mission_level），
## 玩家走到安全屋房门才会真正出发；取消准备随时可做。
## 「档案」页可端详随身文物（特写热点 + 展签卡，见文物志预案 A/B）。

signal closed
signal card_requested(item_id: String, card_id: String)

const APPS := [
	{"id": "task", "label": "委托", "hint": "确认本次行动"},
	{"id": "trade", "label": "交易", "hint": "箱内战利品报价"},
	{"id": "contacts", "label": "联系人", "hint": "来电与联络记录"},
	{"id": "calendar", "label": "日历", "hint": "闭馆与维护排期"},
	{"id": "shop", "label": "采购", "hint": "烟雾弹与跑鞋"},
]

@onready var dim: ColorRect = $Root/Dim
@onready var panel: PanelContainer = $Root/Panel
@onready var task_page: VBoxContainer = $Root/Panel/Margin/VBox/TaskPage
@onready var archive_page: HBoxContainer = $Root/Panel/Margin/VBox/ArchivePage
@onready var tab_task: Button = $Root/Panel/Margin/VBox/Header/TabTask
@onready var tab_archive: Button = $Root/Panel/Margin/VBox/Header/TabArchive
@onready var item_list: VBoxContainer = $Root/Panel/Margin/VBox/ArchivePage/ItemList
@onready var inspect: InspectPage = $Root/Panel/Margin/VBox/ArchivePage/Inspect
@onready var relic: RelicView = $Root/Panel/Margin/VBox/TaskPage/Body/RelicCard/Relic
@onready var target_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/TargetName
@onready var meta_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/Meta
@onready var story_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/Story
@onready var archive_card: PanelContainer = $Root/Panel/Margin/VBox/TaskPage/Body/Info/ArchiveCard
@onready var archive_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/ArchiveCard/Archive
@onready var notes_label: Label = $Root/Panel/Margin/VBox/TaskPage/Body/Info/Notes
@onready var footer_label: Label = $Root/Panel/Margin/VBox/Footer

var extra_page: VBoxContainer
var call_label: Label
## R-04：安全屋模式的应用首页（2×2 图标）与交易页，均代码构建。
var home_page: VBoxContainer
var trade_list: VBoxContainer
var shop_list: VBoxContainer
var shop_money_label: Label
var missions_box: VBoxContainer
var _item_ids: Array[String] = []
var _hub_mode := false


func _ready() -> void:
	visible = false
	extra_page = VBoxContainer.new()
	$Root/Panel/Margin/VBox.add_child(extra_page)
	home_page = VBoxContainer.new()
	home_page.name = "HomePage"
	home_page.add_theme_constant_override("separation", 8)
	$Root/Panel/Margin/VBox.add_child(home_page)
	_build_app_grid()
	trade_list = VBoxContainer.new()
	trade_list.name = "TradePage"
	trade_list.add_theme_constant_override("separation", 4)
	$Root/Panel/Margin/VBox.add_child(trade_list)
	shop_list = VBoxContainer.new()
	shop_list.name = "ShopPage"
	shop_list.add_theme_constant_override("separation", 6)
	$Root/Panel/Margin/VBox.add_child(shop_list)
	missions_box = VBoxContainer.new()
	missions_box.name = "MissionsBox"
	missions_box.add_theme_constant_override("separation", 4)
	$Root/Panel/Margin/VBox/TaskPage.add_child(missions_box)
	var back := Button.new()
	back.name = "HomeButton"
	back.text = "首页"
	back.add_theme_font_size_override("font_size", 10)
	back.visible = false
	$Root/Panel/Margin/VBox/Header.add_child(back)
	back.pressed.connect(func() -> void: _show_tab("home"))
	for title in ["日历", "通讯录"]:
		var button := Button.new()
		button.name = "Tab_" + title
		button.text = title
		button.add_theme_font_size_override("font_size", 10)
		$Root/Panel/Margin/VBox/Header.add_child(button)
		button.pressed.connect(_show_tab.bind(title))
	dim.gui_input.connect(_on_dim_input)
	tab_task.pressed.connect(func() -> void: _show_tab("task"))
	tab_archive.pressed.connect(func() -> void: _show_tab("archive"))
	inspect.card_requested.connect(func(item_id: String, card_id: String) -> void:
		card_requested.emit(item_id, card_id)
	)


## 应用首页：2 列图标按钮（委托 / 交易 / 联系人 / 日历 / 采购）。
func _build_app_grid() -> void:
	var grid := GridContainer.new()
	grid.name = "AppGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_page.add_child(grid)
	var hint := Label.new()
	hint.name = "HomeHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_page.add_child(hint)
	for app in APPS:
		var button := Button.new()
		button.name = "App_" + String(app["id"])
		button.custom_minimum_size = Vector2(120, 52)
		button.text = "%s\n%s" % [String(app["label"]), String(app["hint"])]
		button.add_theme_font_size_override("font_size", 11)
		grid.add_child(button)
		button.pressed.connect(_show_tab.bind(String(app["id"])))
	hint.text = "先在「委托」确认行动，再走到房门出发。\nP / B / ESC 关闭手机。"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))


## 供测试与外部定位应用图标按钮（路径 AppGrid/App_<id>）。
func app_button(app_id: String) -> Button:
	return home_page.get_node("AppGrid/App_" + app_id) as Button


func is_open() -> bool:
	return visible


func open(hub_mode := false) -> void:
	if visible:
		return
	_hub_mode = hub_mode
	tab_archive.visible = not _hub_mode
	tab_task.visible = not _hub_mode
	var back: Button = $Root/Panel/Margin/VBox/Header/HomeButton
	back.visible = _hub_mode
	for tab_name in ["Tab_日历", "Tab_通讯录"]:
		var button: Button = $Root/Panel/Margin/VBox/Header.get_node_or_null(tab_name)
		if button != null:
			button.visible = not _hub_mode
	footer_label.text = "首页 · P / B / ESC 关闭" if _hub_mode else "任务 / 档案 · P / B / ESC 关闭"
	_fill_archive()
	visible = true
	_show_tab("home" if _hub_mode else "task")


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _show_tab(tab: String) -> void:
	# 应用 id → 页面名映射（App_Grid 的 id 与页面名解耦）。
	match tab:
		"contacts":
			tab = "通讯录"
		"calendar":
			tab = "日历"
	task_page.visible = tab == "task"
	archive_page.visible = tab == "archive"
	extra_page.visible = tab == "日历" or tab == "通讯录"
	home_page.visible = tab == "home"
	trade_list.visible = tab == "trade"
	shop_list.visible = tab == "shop"
	if tab == "task" and _hub_mode:
		_fill_missions()
	elif tab == "task":
		_fill_task_briefing()
	if tab == "trade":
		_fill_trade()
	if tab == "shop":
		_fill_shop()
	tab_task.button_pressed = tab == "task"
	tab_archive.button_pressed = tab == "archive"
	for child in extra_page.get_children():
		child.queue_free()
	if tab == "日历":
		var label := Label.new()
		label.text = "行动周历（游戏虚构排期）\n周一：中国厅闭馆维护 · 编号 1936,1118.1\n周三：埃及廊通风检修 · 10.130.1650\n周五：希腊厅激光清洗 · VM-GR-25-012\n记录时间线：1910 圣甲虫捐赠 → 1936 双羊尊入藏\n排期可作为浏览器检索入口；并非真实馆方日程。"
		label.add_theme_font_size_override("font_size", 11)
		extra_page.add_child(label)
	if tab == "通讯录":
		for contact in ["恶魔", "老猫", "中国追索者", "埃及裔学者", "希腊文化基金会"]:
			var button := Button.new()
			button.text = "接听来电：" + contact
			button.add_theme_font_size_override("font_size", 10)
			extra_page.add_child(button)
			button.pressed.connect(func() -> void:
				Game.set_story_flag("contact_" + contact)
				call_label.text = contact + "（虚构人物）\n" + ("我要充满怨恨风味的旧物。查清来源再动手。" if contact == "恶魔" else "先查编号与来源，再比对维修排期。邮件可留下接洽记录。")
				for clue in EvidenceData.clues_for_app("phone_chat"):
					if (contact == "老猫" and clue.id == "zun_chat") or (contact == "希腊文化基金会" and clue.id == "askos_chat"):
						Game.collect_clue(clue.id)
			)
		call_label = Label.new()
		call_label.text = "选择来电查看对话。人物与联络渠道均为虚构。"
		call_label.add_theme_font_size_override("font_size", 10)
		extra_page.add_child(call_label)


## R-05 交易 App：箱内战利品报价 + 预约/取消（预约不扣货不发钱，买家到门外无倒计时）。
func _fill_trade() -> void:
	for child in trade_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "箱内战利品 · 交易"
	title.add_theme_font_size_override("font_size", 13)
	trade_list.add_child(title)

	# 按物品 id 聚合：件数 / 总价 / 已预约件数。
	var groups := {}
	for id in Game.loot_stash:
		groups[id] = int(groups.get(id, 0)) + 1
	if groups.is_empty():
		var empty := Label.new()
		empty.text = "箱内暂时没有普通文物。带回战利品存入文物箱后会出现在这里。"
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trade_list.add_child(empty)
		return

	var any_reserved := false
	for id in groups:
		var count := int(groups[id])
		var reserved_count := int(Game.loot_reserved.get(id, 0))
		any_reserved = any_reserved or reserved_count > 0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label := Label.new()
		label.text = "%s ×%d    %d 金/件    已预约 %d" % [Game.item_name(id), count, Game.item_value(id), reserved_count]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var first_index := Game.loot_stash.find(id)
		if reserved_count < count:
			var reserve := _trade_button("预约一件")
			reserve.pressed.connect(func() -> void:
				Game.reserve_loot(first_index)
				_fill_trade()
			)
			row.add_child(reserve)
		if reserved_count > 0:
			var cancel := _trade_button("取消预约")
			cancel.pressed.connect(func() -> void:
				Game.cancel_loot_reservation(first_index)
				_fill_trade()
			)
			row.add_child(cancel)
		trade_list.add_child(row)

	var status_text := "买家已到门外等待（无倒计时）：从文物箱取出预约货，走到房门按 E 交货。"
	if not any_reserved:
		status_text = "预约不扣货、不发钱；确认后买家到门外等待，随时可取消。"
	var status := Label.new()
	status.text = status_text
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_list.add_child(status)


## R-12a 采购 App：商品卡（消耗品/永久装备、效果、价格）+ 购买。
## 只在安全屋可下单（局内禁采购）；一次点击一次扣款一次发货，备货在下一次出发时并入携带。
func _fill_shop() -> void:
	for child in shop_list.get_children():
		child.queue_free()
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	var title_label := Label.new()
	title_label.text = "采购（安全屋下单）"
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(title_label)
	shop_money_label = Label.new()
	shop_money_label.text = "金币 %d" % Game.money
	shop_money_label.add_theme_font_size_override("font_size", 12)
	title.add_child(shop_money_label)
	shop_list.add_child(title)

	# 商品卡：id → 文案。跑鞋为永久装备（已拥有则不再上架）。
	var catalog := {
		"smoke": "烟雾弹（消耗品）\n近距离脱身：致盲附近保安并争取撤离窗口。\n价格 %d 金币 · 备货 %d 件" % [
			Game.upgrade_price("smoke"), Game.smoke_stock,
		],
		"sneakers": "跑鞋（永久装备）\n疾跑速度提升，缩短危险区暴露与往返。\n价格 %d 金币 · %s" % [
			Game.upgrade_price("sneakers"), "已拥有" if Game.has_sneakers else "未拥有",
		],
	}
	for id in catalog:
		if id == "sneakers" and Game.has_sneakers:
			continue
		var card := PanelContainer.new()
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 4)
		card.add_child(card_box)
		var info := Label.new()
		info.text = String(catalog[id])
		info.add_theme_font_size_override("font_size", 11)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(info)
		var buy := Button.new()
		buy.name = "Buy_" + id
		buy.text = "购买"
		buy.add_theme_font_size_override("font_size", 10)
		buy.custom_minimum_size = Vector2(72, 22)
		buy.disabled = not Game.can_buy(id)
		if Game.can_buy(id):
			buy.pressed.connect(func() -> void:
				if Game.buy(id):
					_fill_shop()
			)
		card_box.add_child(buy)
		shop_list.add_child(card)
		# R-12a 装载计划：本次出发携带 N 件（0 = 不带），− / + 实时调整。
		if id == "smoke":
			var plan_row := HBoxContainer.new()
			plan_row.name = "LoadoutRow"
			plan_row.add_theme_constant_override("separation", 6)
			var plan_label := Label.new()
			plan_label.name = "LoadoutLabel"
			var planned := Game.smoke_carry_plan if Game.smoke_carry_plan >= 0 else Game.smoke_stock
			plan_label.text = "本次出发携带：%d 件（备货 %d）" % [mini(planned, Game.smoke_stock), Game.smoke_stock]
			plan_label.add_theme_font_size_override("font_size", 11)
			plan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			plan_row.add_child(plan_label)
			var minus := Button.new()
			minus.name = "LoadoutMinus"
			minus.text = "−"
			minus.add_theme_font_size_override("font_size", 10)
			minus.disabled = planned <= 0
			minus.pressed.connect(func() -> void:
				Game.set_smoke_carry_plan(mini(Game.smoke_carry_plan if Game.smoke_carry_plan >= 0 else Game.smoke_stock, Game.smoke_stock) - 1)
				_fill_shop()
			)
			plan_row.add_child(minus)
			var plus := Button.new()
			plus.name = "LoadoutPlus"
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 10)
			plus.disabled = planned >= Game.smoke_stock
			plus.pressed.connect(func() -> void:
				var cur := Game.smoke_carry_plan if Game.smoke_carry_plan >= 0 else Game.smoke_stock
				Game.set_smoke_carry_plan(clampi(cur + 1, 0, Game.smoke_stock))
				_fill_shop()
			)
			plan_row.add_child(plus)
			card_box.add_child(plan_row)

	var note := Label.new()
	var planned_note := Game.smoke_carry_plan if Game.smoke_carry_plan >= 0 else Game.smoke_stock
	var stock_hint := "本次出发计划携带 %d 件（备货 %d 件）；未计划默认全部携带。" % [planned_note, Game.smoke_stock] if Game.smoke_stock > 0 else "暂无备货。"
	note.text = "采购只在安全屋可用，馆内不能购买。%s\n无钱也能继续主线：基础调查与地图记录免费。" % stock_hint
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_list.add_child(note)


func _trade_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 10)
	return btn


## 委托 App（安全屋）：列出可行动关卡，确认/取消待出发状态。
func _fill_missions() -> void:
	missions_box.visible = true
	for child in missions_box.get_children():
		child.queue_free()
	var pending := String(Game.pending_mission_level)
	var status := Label.new()
	if pending != "":
		status.text = "已确认：%s（到房门出发）" % Game.level_name_of(pending)
	else:
		status.text = "未确认行动。选择一项并点「准备出发」。"
	status.add_theme_font_size_override("font_size", 11)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	missions_box.add_child(status)
	for level_id in Game.LEVELS.keys():
		var info: Dictionary = Game.LEVELS[level_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		var target := String(info.get("target", ""))
		label.text = "%s · 目标 %s · %d 金币" % [
			String(info.get("name", level_id)), Game.item_name(target), int(info.get("reward", 0)),
		]
		label.add_theme_font_size_override("font_size", 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if level_id == pending:
			var cancel := Button.new()
			cancel.text = "取消准备"
			cancel.add_theme_font_size_override("font_size", 10)
			cancel.pressed.connect(func() -> void:
				Game.clear_pending_mission()
				_fill_missions()
			)
			row.add_child(cancel)
		else:
			var prepare := Button.new()
			prepare.text = "准备出发"
			prepare.add_theme_font_size_override("font_size", 10)
			prepare.pressed.connect(func() -> void:
				Game.prepare_mission(String(level_id))
				_fill_missions()
			)
			row.add_child(prepare)
		missions_box.add_child(row)
	var note := Label.new()
	note.text = "确认后手机可以关掉；走到房门按 E 才会出发，取消不扣任何东西。"
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	missions_box.add_child(note)


## 行动中（博物馆内）的任务页：单次行动简报。
func _fill_task_briefing() -> void:
	target_label.visible = true
	meta_label.visible = true
	story_label.visible = true
	archive_card.visible = true
	notes_label.visible = true
	relic.visible = true
	missions_box.visible = false
	var info := Game.level_info()
	var target_id := Game.mission_target_id
	target_label.text = Game.item_name(target_id)
	var location := Game.level_name()
	if Game.current_level_id == "british_museum":
		location += "·%s" % Game.bm_hall_name(target_id)
	meta_label.text = "行动地点：%s\n委托人：老猫 · 报酬：%d 金币" % [
		location,
		int(info.get("reward", 0)),
	]
	story_label.text = Game.item_story(target_id)
	var archive: Dictionary = Game.ARCHIVE.get(target_id, {})
	archive_card.visible = not archive.is_empty()
	if not archive.is_empty():
		archive_label.text = "文物档案 · %s · %s\n现藏：%s\n流转：%s\n备注：%s" % [
			String(archive.get("era", "")),
			String(archive.get("origin", "")),
			String(archive.get("collection", "")),
			String(archive.get("provenance", "")),
			String(archive.get("legend", "")),
		]
	notes_label.text = "恶魔：我要充满怨恨风味的旧物。\n规划（Tab）可看清守卫路线与监控扇区；\n一次一件；得手后前往出口撤离。"
	relic.zoom = 1.5
	relic.set_item(target_id)


## 档案页：列出随身文物（去重）；点击 → 端详。
func _fill_archive() -> void:
	_item_ids.clear()
	for item in Game.bag_items:
		var id := String(item["id"])
		if not _item_ids.has(id):
			_item_ids.append(id)
	for child in item_list.get_children():
		child.queue_free()
	if _item_ids.is_empty():
		var empty := Label.new()
		empty.text = "背包里还没有文物。"
		empty.add_theme_color_override("font_color", Color("8a8f9c"))
		item_list.add_child(empty)
		inspect.visible = false
		return
	inspect.visible = true
	for id in _item_ids:
		var button := Button.new()
		button.text = Game.item_name(id)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 24)
		button.pressed.connect(func() -> void: inspect.set_item(id))
		item_list.add_child(button)
	inspect.set_item(_item_ids[0])


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("phone") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("bag"):
		close()
		get_viewport().set_input_as_handled()
