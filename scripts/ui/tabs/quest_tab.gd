class_name QuestTab
extends CharacterSheetTab

## Placeholder quest tab — v1 shows a friendly empty message. The
## ItemsTab with category `&"quest"` would be the future home of
## collected quest items; this tab is reserved for active quests once
## that system lands.


func tab_title() -> String:
	return "Quests"


func _on_configured() -> void:
	var label: Label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	label.text = "No active quests."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
