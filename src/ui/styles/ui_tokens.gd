extends RefCounted
class_name UiTokens

const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 12
const SPACE_LG := 16

const RADIUS_SM := 4
const RADIUS_MD := 6
const RADIUS_LG := 8

const BUTTON_HEIGHT_SM := 36
const BUTTON_HEIGHT_MD := 48
const BUTTON_HEIGHT_LG := 60

const FONT_CAPTION := 11
const FONT_BODY := 13
const FONT_CARD_TITLE := 15
const FONT_ACTION := 17

const STATE_SELECTED := Color(0.34, 0.72, 1.0, 1.0)
const STATE_RECOMMENDED := Color(1.0, 0.78, 0.28, 1.0)
const STATE_PLAYABLE := Color(0.2, 0.82, 0.56, 1.0)
const STATE_TARGET := Color(1.0, 0.32, 0.26, 1.0)
const STATE_DISABLED := Color(0.36, 0.4, 0.48, 1.0)

static func card_metrics(mode: String, compact: bool = false, tight: bool = false) -> Dictionary:
	var title_font := FONT_CARD_TITLE
	var identity_font := FONT_CAPTION
	var summary_font := FONT_BODY
	var detail_font := FONT_CAPTION
	var separation := SPACE_SM
	match mode:
		"hand":
			title_font = 12 if compact else FONT_CARD_TITLE
			identity_font = 8 if tight else 10
			summary_font = 10 if compact else 12
			detail_font = 8 if tight else 9
			separation = 3 if tight else 5
		"field":
			title_font = 10 if tight and compact else (11 if tight else (12 if compact else 13))
			identity_font = 9 if tight else 10
			summary_font = 10 if tight else 11
			detail_font = 9
			separation = 2
		"reward":
			title_font = 12 if tight else (13 if compact else FONT_CARD_TITLE)
			identity_font = 10 if tight else FONT_CAPTION
			summary_font = 11 if tight else 12
			detail_font = FONT_CAPTION
			separation = 3 if tight else SPACE_XS
		"shop":
			title_font = 13 if tight else (14 if compact else FONT_CARD_TITLE)
			identity_font = FONT_CAPTION if tight else 12
			summary_font = FONT_CAPTION if compact else 12
			detail_font = FONT_CAPTION
			separation = SPACE_XS if tight else 5
		"collection":
			title_font = 14 if compact else FONT_CARD_TITLE
			identity_font = 12 if compact else FONT_BODY
			summary_font = 12 if compact else 14
			detail_font = FONT_CAPTION if compact else 12
			separation = 6
	return {
		"title_font": title_font,
		"identity_font": identity_font,
		"summary_font": summary_font,
		"detail_font": detail_font,
		"separation": separation,
	}

static func card_state_accent(state: String, race_accent: Color) -> Color:
	match state:
		"selected":
			return STATE_SELECTED
		"recommended":
			return STATE_RECOMMENDED
		"playable":
			return STATE_PLAYABLE
		"target":
			return STATE_TARGET
		"disabled":
			return STATE_DISABLED
		_:
			return race_accent

static func card_state_border_width(state: String) -> int:
	return 3 if state in ["selected", "recommended", "playable", "target"] else 1 if state == "disabled" else 2
