class_name PhoneUI
extends Control
## In-game smartphone: home screen with 6 apps. Fills the screen with a phone-like frame
## (a tiny phone inside a real phone would make text unreadable).

signal adopted(cat: CatData)
signal closed

const APPS := [
	{"id": "market", "name": "냥마켓", "color": Color("f2a65a"), "glyph": "마켓"},
	{"id": "adopt", "name": "분양센터", "color": Color("7fc8a9"), "glyph": "분양"},
	{"id": "camera", "name": "카메라", "color": Color("8aa6d6"), "glyph": "촬영"},
	{"id": "notes", "name": "냥이 노트", "color": Color("f08ca0"), "glyph": "노트"},
	{"id": "dex", "name": "도감", "color": Color("b59ad6"), "glyph": "도감"},
	{"id": "help", "name": "냥냥 상담소", "color": Color("e6c86e"), "glyph": "상담"},
]
const INK := Color("3a2f28")
const SUB := Color("6e5f55")
const PAPER := Color("fdf8f2")
const CARD := Color("ffffff")

var household: Household
var now_fn: Callable

var clock_label: Label
var screen: VBoxContainer       # current app content goes here
var notes_filter := ""          # "" = all cats
var dex_tab := "behavior"


func setup(house: Household, now_callable: Callable) -> void:
	household = house
	now_fn = now_callable
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_frame()
	visible = false


func open() -> void:
	visible = true
	_show_home()


func close() -> void:
	visible = false
	closed.emit()


func unread_count() -> int:
	return maxi(0, household.diary.size() - household.diary_seen)


func _process(_delta: float) -> void:
	if visible:
		var t := Time.get_datetime_dict_from_system()
		clock_label.text = "%02d:%02d" % [t["hour"], t["minute"]]


# ---------- building blocks ----------

func _box(color: Color, radius := 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


func _label(text: String, size := 26, color := INK, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable, color := Color("f2a65a"), size := 26, height := 72) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
	b.add_theme_stylebox_override("normal", _box(color, 18))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.08), 18))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.12), 18))
	b.add_theme_stylebox_override("disabled", _box(Color("c9bfb5"), 18))
	b.pressed.connect(cb)
	return b


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(CARD, 22))
	screen.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	return v


func _clear() -> void:
	for ch in screen.get_children():
		ch.queue_free()


func _fmt_time(t: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(t + bias)
	return "%d월 %d일 %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var body := PanelContainer.new()
	var frame_style := _box(PAPER, 56)
	frame_style.border_color = Color("2b2420")
	frame_style.set_border_width_all(14)
	frame_style.content_margin_left = 30
	frame_style.content_margin_right = 30
	frame_style.content_margin_top = 26
	frame_style.content_margin_bottom = 22
	body.add_theme_stylebox_override("panel", frame_style)
	margin.add_child(body)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	body.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	clock_label = _label("", 26, INK, false)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(clock_label)
	top.add_child(_btn("닫기", close, Color("6e5f55"), 24, 56))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	screen = VBoxContainer.new()
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.add_theme_constant_override("separation", 14)
	scroll.add_child(screen)

	var home := _btn("홈", _show_home, Color("2b2420"), 24, 60)
	col.add_child(home)


func _header(title: String) -> void:
	_clear()
	screen.add_child(_label(title, 38, INK, false))


# ---------- home ----------

func _show_home() -> void:
	_header("홈")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 24)
	screen.add_child(grid)
	for app in APPS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		grid.add_child(cell)
		var id: String = app["id"]
		var glyph: String = app["glyph"]
		if id == "notes" and unread_count() > 0:
			glyph = "노트 %d" % unread_count()
		var icon := _btn(glyph, func(): _open_app(id), app["color"], 28, 150)
		cell.add_child(icon)
		var name_label := _label(app["name"], 22, INK, false)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)


func _open_app(id: String) -> void:
	match id:
		"market":
			_coming_soon("냥마켓", "사료, 간식, 장난감, 가구를 주문하면 실제 시간이 지나 택배로 도착해요. 다 쓴 택배 상자는 고양이들의 놀이터가 돼요.")
		"camera":
			_coming_soon("카메라", "고양이를 촬영하고 앨범에 모아요. 찍는 순간 어떤 고양이가 무슨 행동을 하는지 자동으로 기록돼요.")
		"adopt":
			_show_adopt()
		"notes":
			_show_notes()
		"dex":
			_show_dex()
		"help":
			_show_help()


func _coming_soon(title: String, desc: String) -> void:
	_header(title)
	var card := _card()
	card.add_child(_label("곧 문을 열어요", 30, INK))
	card.add_child(_label(desc, 24, SUB))


# ---------- adoption center ----------

func _show_adopt() -> void:
	_header("분양센터")
	var now: int = now_fn.call()
	screen.add_child(_label("우리 집 고양이 %d / %d마리 · 매일 새로운 고양이가 찾아와요" % [household.cats.size(), Household.MAX_CATS], 22, SUB))
	for cand in household.adoption_candidates(now):
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var swatch := Panel.new()
		swatch.custom_minimum_size = Vector2(84, 84)
		var coat: Dictionary = Traits.COATS[cand["coat"]]
		var sw := _box(coat["fur"], 42)
		sw.border_color = coat["cream"]
		sw.set_border_width_all(6)
		swatch.add_theme_stylebox_override("panel", sw)
		row.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_label("%s · %s" % [cand["name"], coat["label"]], 30, INK))
		var first: String = Traits.personality(cand["personalities"][0])["label"]
		var more := " 외 ?" if cand["personalities"].size() > 1 else ""
		info.add_child(_label("성격 미리보기: %s%s" % [first, more], 22, SUB))
		card.add_child(_label("숨겨진 성격과 습관은 함께 살면서 알게 돼요.", 20, SUB))
		var full := household.cats.size() >= Household.MAX_CATS
		var text := "입양 완료" if cand["taken"] else ("집이 가득 찼어요" if full else "입양하기")
		var c: Dictionary = cand
		var b := _btn(text, func(): _adopt(c), Color("7fc8a9"))
		b.disabled = cand["taken"] or full
		card.add_child(b)


func _adopt(cand: Dictionary) -> void:
	var cat := household.adopt_candidate(cand, now_fn.call())
	if cat:
		household.save()
		adopted.emit(cat)
	_show_adopt()


# ---------- notes (auto diary) ----------

func _show_notes() -> void:
	_header("냥이 노트")
	household.diary_seen = household.diary.size()
	household.save()
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 10)
	filters.add_theme_constant_override("v_separation", 10)
	screen.add_child(filters)
	var options: Array = [["", "전체"]]
	for c in household.cats:
		options.append([c.id, c.cat_name])
	for opt in options:
		var fid: String = opt[0]
		var active := fid == notes_filter
		filters.add_child(_btn(opt[1], _set_notes_filter.bind(fid), Color("f08ca0") if active else Color("c9a99a"), 22, 56))

	var shown := 0
	for i in range(household.diary.size() - 1, -1, -1):
		var e: Dictionary = household.diary[i]
		if notes_filter != "" and e.get("cat_id", "") != notes_filter:
			continue
		var card := _card()
		var cat := household.find(str(e.get("cat_id", "")))
		var who := cat.cat_name if cat else ""
		card.add_child(_label("%s  %s" % [_fmt_time(int(e.get("t", 0))), who], 20, SUB))
		card.add_child(_label(str(e.get("text", "")), 24, INK))
		shown += 1
	if shown == 0:
		screen.add_child(_label("아직 기록이 없어요. 고양이와 시간을 보내면 자동으로 적혀요.", 24, SUB))


func _set_notes_filter(fid: String) -> void:
	notes_filter = fid
	_show_notes()


# ---------- dex ----------

func _set_dex_tab(tid: String) -> void:
	dex_tab = tid
	_show_dex()



func _show_dex() -> void:
	_header("도감")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	screen.add_child(tabs)
	for t in [["behavior", "행동"], ["habit", "습관"], ["title", "칭호"]]:
		var tid: String = t[0]
		var b := _btn(t[1], _set_dex_tab.bind(tid), Color("b59ad6") if dex_tab == tid else Color("c9bfd6"), 24, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)

	match dex_tab:
		"behavior":
			var found := 0
			for id in Catalog.BEHAVIORS:
				if not id in household.discovered_behaviors:
					continue
				found += 1
				var info: Dictionary = Catalog.BEHAVIORS[id]
				var card := _card()
				card.add_child(_label("%s  [%s]" % [info["name"], info["tone"]], 28, INK))
				card.add_child(_label(info["meaning"], 22, SUB))
			var hidden := Catalog.BEHAVIORS.size() - found
			if hidden > 0:
				screen.add_child(_label("아직 발견하지 못한 행동이 %d개 있어요. 고양이를 지켜봐 주세요." % hidden, 22, SUB))
		"habit":
			for c in household.cats:
				var card := _card()
				card.add_child(_label("%s · %s" % [c.cat_name, c.personality_labels()], 28, INK))
				for h in c.discovered_habits:
					var info: Dictionary = Traits.HABITS[h]
					card.add_child(_label("%s — %s" % [info["label"], info["hint"]], 22, SUB))
				var left := c.habits.size() - c.discovered_habits.size()
				if left > 0:
					card.add_child(_label("??? 숨겨진 습관 %d개" % left, 22, SUB))
		"title":
			var card := _card()
			card.add_child(_label("칭호는 다음 업데이트에서 열려요", 26, INK))
			card.add_child(_label("예: 묘연의 시작, 골골송 입문자, 눈키스 장인, 새벽 3시 목격자 …", 22, SUB))


# ---------- help (Q&A) ----------

func _show_help() -> void:
	_header("냥냥 상담소")
	screen.add_child(_label("궁금한 질문을 눌러 보세요.", 22, SUB))
	for qa in Catalog.FAQ:
		var card := _card()
		var answer := _label(qa[1], 22, SUB)
		answer.visible = false
		var q := Button.new()
		q.text = "Q. " + qa[0]
		q.alignment = HORIZONTAL_ALIGNMENT_LEFT
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.add_theme_font_size_override("font_size", 24)
		q.add_theme_color_override("font_color", INK)
		q.add_theme_color_override("font_hover_color", INK)
		q.add_theme_color_override("font_pressed_color", INK)
		q.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		q.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		q.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		q.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		q.pressed.connect(func(): answer.visible = not answer.visible)
		card.add_child(q)
		card.add_child(answer)
