class_name Items
extends RefCounted
## Static item definitions: display names, descriptions and inventory order.
## GameState holds the counts; this holds what each item *is*.

## Inventory display order.
const ORDER: Array[StringName] = [&"wood", &"meat", &"cooked_meat", &"yarrow", &"angelica", &"wolfsbane"]

const NAMES: Dictionary[StringName, String] = {
	&"wood": "Wood",
	&"meat": "Wolf meat",
	&"cooked_meat": "Cooked meat",
	&"yarrow": "Yarrow",
	&"angelica": "Angelica",
	&"wolfsbane": "Wolfsbane",
}

const DESCRIPTIONS: Dictionary[StringName, String] = {
	&"wood": "Split pine logs from felled trees. Feed the campfire (E) to keep it burning through the night.",
	&"meat": "Raw meat from a slain wolf. Eat it (F), or roast it on the spit by the fire for a better meal.",
	&"cooked_meat": "Wolf meat roasted on the spit. Far more filling than raw – eaten first when you press F.",
	&"yarrow": "A feathery wound herb. Crushed into a poultice, it heals your injuries. Use with 1.",
	&"angelica": "A sweet, crunchy stalk that takes the edge off hunger. Use with 2.",
	&"wolfsbane": "Deadly poison. Smear it on your axe to deal double damage for a short time. Use with 3.",
}


static func display_name(item: StringName) -> String:
	return NAMES.get(item, String(item).capitalize())


static func description(item: StringName) -> String:
	return DESCRIPTIONS.get(item, "")
