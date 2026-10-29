import csv

from processing import name_to_enum

ROOT = "./content"
DEST = "./src/game"
SPRITE_ROOT = "./assets/sprites"

baddy_id_enums = ["None"]
baddy_templates = [""]

n = 1

with open(f"{ROOT}/baddies.csv") as f:
	reader = csv.DictReader(f, delimiter=",")
	for row in reader:
		baddy_id_enum = name_to_enum(row["name"])
		row["name"] = row["name"]
		if not row["texture"]:
			row["texture"] = baddy_id_enum
		row["texture"] = row["texture"].title()
		if baddy_id_enum == baddy_id_enums[-1] or f"{baddy_id_enum}_{n}" == baddy_id_enums[-1]:
			if n == 1:
				baddy_id_enums[-1] += "_1"
			n += 1
			baddy_id_enum += f"_{n}"
		else:
			n = 1
		baddy_id_enums.append(baddy_id_enum)
		template_str = """
	name = \"{name}\",
	stats = {{
		{hitpoints},
		{vigor},
		{speed},
		{stamina},
		{psy_pow},
		{weap},
		{armor},
		{psy_def},
		{evasion},
	}},
	level = {level},
	texture = .{texture},
""".format(**row)
		if row.get("downed"):
			template_str += "downed = {downed},\n".format(**row)
		template_str += "skills = {" + ",".join(["."+skill for skill in row["skills"].split(",")]) + "},"
		spoils = ["{}", "{}"]
		spoils[0] = "{{ .{}, {} }}".format(row["s1"] or "None", row["s1p"] or "0")
		spoils[1] = "{{ .{}, {} }}".format(row["s2"] or "None", row["s2p"] or "0")
		template_str += "spoils = {" + ",".join(spoils) + "},"
		baddy_templates.append(template_str)

out_f = open(f"{DEST}/baddy_data.odin", "w")

out_f.write("""package game

@(rodata)
baddy_templates := [Baddy_Id]Baddy_Template{
""")
for enum, template in zip(baddy_id_enums, baddy_templates):
	out_f.write(f".{enum} = {{ {template} }},\n")

out_f.write("""}

Baddy_Id :: enum {
""")

out_f.write(",\n".join(baddy_id_enums + [""]))
out_f.write("}\n")

out_f.write(f"NUM_BADDY_TEMPLATES :: {len(baddy_id_enums)}")

out_f.close()
