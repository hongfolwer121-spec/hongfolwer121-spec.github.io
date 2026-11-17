class_name Traits
extends RefCounted
## Personality (big tendencies, 1-2 per cat) and habits (small quirks, 2-3 per cat).
## Habits start hidden and are discovered by watching the cat.

const PERSONALITIES := {
	"affectionate": {
		"label": "애교쟁이",
		"approach": 0.6,        # chance to come toward the player when idle
		"play_mult": 1.0,
		"sleep_bias": 0.2,
		"pet_tolerance": 6,     # pets within the window before getting annoyed
		"intimacy_mult": 1.2,
		"annoy_chance": 0.02,   # spontaneous "leave me alone" moments per decision
	},
	"aloof": {
		"label": "도도함",
		"approach": 0.1,
		"play_mult": 0.8,
		"sleep_bias": 0.3,
		"pet_tolerance": 2,
		"intimacy_mult": 0.8,
		"annoy_chance": 0.12,
	},
	"playful": {
		"label": "장난꾸러기",
		"approach": 0.3,
		"play_mult": 1.6,
		"sleep_bias": 0.1,
		"pet_tolerance": 4,
		"intimacy_mult": 1.0,
		"annoy_chance": 0.05,
	},
	"timid": {
		"label": "겁쟁이",
		"approach": 0.05,
		"play_mult": 0.9,
		"sleep_bias": 0.3,
		"pet_tolerance": 3,
		"intimacy_mult": 0.9,
		"annoy_chance": 0.08,
	},
	"sleepy": {
		"label": "잠꾸러기",
		"approach": 0.2,
		"play_mult": 0.7,
		"sleep_bias": 0.6,
		"pet_tolerance": 4,
		"intimacy_mult": 1.0,
		"annoy_chance": 0.04,
	},
}

const HABITS := {
	"window_spot": {"label": "창가 자리 애호가", "hint": "창가 쪽에 자주 앉아 있어요"},
	"night_zoomies": {"label": "밤의 우다다", "hint": "밤이 되면 방을 가로질러 달려요"},
	"groom_after_meal": {"label": "식후 그루밍", "hint": "밥을 먹고 나면 꼭 세수를 해요"},
	"jealous": {"label": "질투쟁이", "hint": "다른 고양이만 예뻐하면 끼어들어요"},
	"curious": {"label": "호기심쟁이", "hint": "새로운 물건이 생기면 먼저 가 봐요"},
	"loner": {"label": "혼자가 좋아", "hint": "가끔은 다른 고양이와 떨어져 쉬어요"},
}

## albedo = texture index of the purchased cat asset (CatSimple_Albedo_N.png).
## fur/cream are used by UI swatches and the placeholder body.
const COATS := {
	"cheese": {"label": "치즈", "albedo": 5, "fur": Color("e39a4f"), "cream": Color("fbe3c4")},
	"tabby": {"label": "고등어", "albedo": 6, "fur": Color("7a6450"), "cream": Color("d8c3a5")},
	"black": {"label": "올블랙", "albedo": 1, "fur": Color("2e2a2a"), "cream": Color("4a4444")},
	"white": {"label": "하양", "albedo": 2, "fur": Color("f1ede6"), "cream": Color("faf6f0")},
	"tuxedo": {"label": "턱시도", "albedo": 3, "fur": Color("26262b"), "cream": Color("f4f4f4")},
	"cow": {"label": "젖소", "albedo": 4, "fur": Color("f4f1ec"), "cream": Color("2b2b2b")},
}


static func coat(id: String) -> Dictionary:
	return COATS.get(id, COATS["cheese"])


static func personality(id: String) -> Dictionary:
	return PERSONALITIES.get(id, PERSONALITIES["affectionate"])


## Combined parameter for a cat with 1-2 personalities: average of the values.
static func param(personalities: Array, key: String) -> float:
	if personalities.is_empty():
		return float(PERSONALITIES["affectionate"][key])
	var total := 0.0
	for p in personalities:
		total += float(personality(p)[key])
	return total / personalities.size()
