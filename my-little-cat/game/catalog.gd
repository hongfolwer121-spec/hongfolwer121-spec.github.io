class_name Catalog
extends RefCounted
## Static game content shared by the room and the in-game phone.

const BEHAVIORS := {
	"purr_pet": {"name": "골골송", "meaning": "쓰다듬어 주면 목을 울려요. 편안하고 기분이 좋다는 뜻이에요.", "tone": "긍정"},
	"tail_lash": {"name": "꼬리 세차게 흔들기", "meaning": "강아지와 달리 고양이에게는 '귀찮아, 그만해'라는 신호예요. 잠시 혼자 두세요.", "tone": "부정"},
	"slow_blink": {"name": "천천히 눈 깜빡이기", "meaning": "고양이의 눈인사예요. 당신을 믿는다는 뜻이에요. 같이 천천히 깜빡여 주세요.", "tone": "긍정"},
	"sleep": {"name": "낮잠", "meaning": "고양이는 하루의 절반 이상을 자요. 자는 동안엔 깨우지 않는 게 좋아요.", "tone": "기본"},
	"groom": {"name": "그루밍", "meaning": "혀로 털을 정리해요. 몸을 깨끗이 하고 마음을 진정시키는 행동이에요.", "tone": "기본"},
	"box_sit": {"name": "상자 안에 쏙", "meaning": "고양이는 좁고 아늑한 상자를 좋아해요. 비싼 집보다 택배 상자를 더 좋아할 때도 있어요.", "tone": "긍정"},
	"scratch": {"name": "발톱 긁기", "meaning": "발톱을 다듬고 자기 냄새를 남겨 영역을 표시해요. 스크래처가 있으면 가구를 덜 긁어요.", "tone": "기본"},
	"tower_perch": {"name": "높은 곳에서 내려다보기", "meaning": "높은 곳은 안전하고 모든 걸 살필 수 있어서 고양이가 좋아하는 자리예요.", "tone": "긍정"},
	"zoomies": {"name": "우다다", "meaning": "남은 에너지를 한 번에 쏟아내며 달려요. 주로 밤이나 새벽에 나타나요.", "tone": "기본"},
}

## Market items. kind: food (consumable servings), toy/furniture (owned once, unlocks behavior).
## delivery in minutes of real time.
const ITEMS := {
	"dry_food": {"name": "건식 사료", "kind": "food", "price": 30, "servings": 5, "hunger": 40.0, "happy": 0.0, "delivery": 10,
		"desc": "기본 사료 5회분. 배부름 +40"},
	"wet_food": {"name": "습식 사료", "kind": "food", "price": 60, "servings": 3, "hunger": 60.0, "happy": 5.0, "delivery": 10,
		"desc": "촉촉한 사료 3회분. 배부름 +60, 행복 +5"},
	"treat": {"name": "츄르 간식", "kind": "treat", "price": 45, "servings": 3, "hunger": 10.0, "happy": 15.0, "delivery": 10,
		"desc": "고양이가 사랑하는 간식 3개. 행복 +15, 친밀도 +2"},
	"feather": {"name": "낚싯대 장난감", "kind": "toy", "price": 120, "delivery": 20,
		"desc": "놀아주기 효과가 1.3배가 돼요"},
	"cushion": {"name": "푹신한 방석", "kind": "furniture", "price": 150, "delivery": 60,
		"desc": "고양이들이 이 위에서 낮잠을 자요"},
	"scratcher": {"name": "스크래처", "kind": "furniture", "price": 200, "delivery": 60,
		"desc": "발톱 긁기 행동이 생겨요"},
	"cat_tower": {"name": "캣타워", "kind": "furniture", "price": 400, "delivery": 60,
		"desc": "높은 곳에 올라가 방을 내려다봐요"},
}

const NAME_POOL := ["나비", "까망", "구름", "치즈", "보리", "콩이", "모카", "두부", "호두", "라떼", "망고", "율무"]

const FAQ := [
	["고양이가 꼬리를 세차게 흔들어요", "기분이 좋지 않다는 신호예요. 그때 쓰다듬으면 친밀도가 내려가요. 신호가 사라질 때까지 기다려 주면 오히려 친밀도가 올라요."],
	["친밀도를 빨리 올리는 방법이 있나요?", "하루에 쌓을 수 있는 친밀도에는 한도가 있어요. 매일 조금씩 밥을 주고, 놀아 주고, 고양이의 신호를 읽어 주는 것이 가장 좋아요."],
	["고양이가 눈을 천천히 깜빡여요", "고양이의 눈인사예요! '눈인사로 답하기' 버튼을 누르면 친밀도가 크게 올라요. 친밀도가 어느 정도 쌓여야 볼 수 있어요."],
	["오랫동안 접속을 못 했어요", "걱정 마세요. 고양이는 배가 고프고 심심해할 뿐, 아프거나 떠나지 않아요. 돌아와서 밥을 주면 금방 회복돼요."],
	["다른 고양이가 질투해요", "한 고양이만 계속 챙기면 질투쟁이 고양이가 다가와요. 그 고양이도 쓰다듬거나 놀아 주면 금방 기분이 풀려요."],
	["습관은 어떻게 알 수 있나요?", "고양이마다 숨겨진 습관이 2~3개 있어요. 고양이를 지켜보다 보면 자연스럽게 발견되고, 냥이 노트에 기록돼요."],
	["코인은 어떻게 모으나요?", "매일 처음 접속하면 출석 코인을 받아요. 고양이를 돌보거나 새로운 습관과 행동을 발견해도 코인이 생겨요. 돌봄으로 얻는 코인은 하루 한도가 있어요."],
	["주문한 물건은 언제 오나요?", "냥마켓에서 주문하면 실제 시간이 지나 택배로 도착해요. 사료는 10분, 장난감은 20분, 가구는 1시간 정도 걸려요."],
	["택배 상자가 방에 남아 있어요", "고양이들이 상자를 정말 좋아하거든요! 상자 안에 들어간 모습을 볼 수 있어요. 냥마켓의 보관함에서 정리할 수도 있어요."],
	["몇 마리까지 키울 수 있나요?", "지금은 한 집에 3마리까지 함께 살 수 있어요."],
]


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func behavior_name(id: String) -> String:
	return BEHAVIORS.get(id, {}).get("name", id)
