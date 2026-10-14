class_name Items
extends RefCounted
## Static item definitions: display names, descriptions and inventory order.
## GameState holds the counts; this holds what each item *is*.

## Inventory display order.
const ORDER: Array[StringName] = [&"wood", &"meat", &"cooked_meat", &"yarrow", &"angelica", &"wolfsbane",
		&"yarrow_poultice", &"angelica_mash", &"wolfsbane_paste"]

const NAMES: Dictionary[StringName, String] = {
	&"wood": "Wood",
	&"meat": "Wolf meat",
	&"cooked_meat": "Cooked meat",
	&"yarrow": "Yarrow",
	&"angelica": "Angelica",
	&"wolfsbane": "Wolfsbane",
	&"yarrow_poultice": "Yarrow poultice",
	&"angelica_mash": "Angelica mash",
	&"wolfsbane_paste": "Wolfsbane paste",
}

const DESCRIPTIONS: Dictionary[StringName, String] = {
	&"wood": "Split pine logs from felled trees. Feed the campfire (E) to keep it burning through the night.",
	&"meat": "Raw meat from a slain wolf. Eat it (F), or roast it on the spit by the fire for a better meal.",
	&"cooked_meat": "Wolf meat roasted on the spit. Far more filling than raw – eaten first when you press F.",
	&"yarrow": "A feathery wound herb. Grind it at the herb mortar to make a healing poultice.",
	&"angelica": "A sweet, crunchy stalk. Grind it at the herb mortar into a filling mash.",
	&"wolfsbane": "Deadly poison – too dangerous to handle raw. Grind it at the herb mortar into a paste.",
	&"yarrow_poultice": "Crushed yarrow packed onto a wound. Heals your injuries. Use with 1.",
	&"angelica_mash": "Pounded angelica stalk that takes the edge off hunger. Use with 2.",
	&"wolfsbane_paste": "Smear it on your axe to deal double damage for a short time. Use with 3.",
}


static func display_name(item: StringName) -> String:
	return NAMES.get(item, String(item).capitalize())


static func description(item: StringName) -> String:
	return DESCRIPTIONS.get(item, "")
