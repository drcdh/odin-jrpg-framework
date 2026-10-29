import csv

from processing import name_to_enum, process_text

ROOT = "./content"
DEST = "./src/game"

items = []
def odin_consumable(row):
	skill = row.get("skill")
	price = row.get("price")
	return {
		"name": row["name"],
		"skill": f".{skill}" if skill else "nil",
		"description": process_text(row["description"]),
		"price": str(price) if price else "nil",
	}
def odin_equippable(row):
	price = row.get("price")
	return {
		"name": row["name"],
		"slot": "." + row["slot"],
		"stats_add": "{{ {} }}".format(
			",".join(map(str, [
			row["aHP"] or 0,
			row["aVG"] or 0,
			row["aSP"] or 0,
			row["aST"] or 0,
			row["aPP"] or 0,
			row["aWP"] or 0,
			row["aAR"] or 0,
			row["aPD"] or 0,
			row["aEV"] or 0,
			]))
		),
		"stats_mul": "{{ {} }}".format(
			",".join(map(str, [
			row["mHP"] or 0,
			row["mVG"] or 0,
			row["mSP"] or 0,
			row["mST"] or 0,
			row["mPP"] or 0,
			row["mWP"] or 0,
			row["mAR"] or 0,
			row["mPD"] or 0,
			row["mEV"] or 0,
			]))
		),
		"description": process_text(row["description"]),
		"price": str(price) if price else "nil",
	}

def write_item(f, oitem):
	if "skill" in oitem:
		f.write("\t{{ \"{name}\", {skill}, \"{description}\", {price} }},\n".format(**oitem))
	else:
		f.write("\t{{ \"{name}\", Equippable{{ {stats_add}, {stats_mul}, {slot} }}, \"{description}\", {price} }},\n".format(**oitem))

with open(f"{ROOT}/consumables.csv") as f:
	reader = csv.DictReader(f, delimiter=",")
	for row in reader:
		items.append(odin_consumable(row))

with open(f"{ROOT}/equippables.csv") as f:
	reader = csv.DictReader(f, delimiter=",")
	for row in reader:
		items.append(odin_equippable(row))

with open(f"{DEST}/item_data.odin", "w") as f:
	f.write("package game\n\n")
	f.write("Item_Name :: enum {\n")
	for item in items:
		enum = name_to_enum(item["name"])
		f.write(f"\t{enum},\n")
	f.write("\tNone,\n")
	f.write("}\n\n")

	f.write("// TODO @(rodata)\n")
	f.write(f"items := [{len(items)}]Item {{\n")
	for item in items:
		write_item(f, item)
	f.write("}\n")

