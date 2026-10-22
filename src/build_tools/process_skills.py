import csv

from processing import name_to_enum, process_text

ROOT = "./content"
DEST = "./src/rules"

DEFAULTS = dict(
	constant=0,
	power=0,
	psy_power=0,
	pierce=0,
	psy_pierce=0,
	hit_acc=100,
	risk=100,
	ranged="false",
	sts_acc=100,
	status="nil",
	stg_acc=100,
	stagger=0,
	int_acc=0,
	# traits="???",
)
TYPES = dict(
	ranged=str,
	status=str,
) # others are int

skills = []

def effect_data(row):
	return {k: str(bool(v)).lower() if k == "ranged" else TYPES.get(k, int)(v if v != "" else DEFAULTS[k]) for k, v in row.items() if k in DEFAULTS}

def effect_data_str(row):
	d = effect_data(row)
	return "{" + ",".join([f"{k}={v}" for k, v in d.items()]) + "}"

def odin_skill(row):
	return {
		"name": row["name"],
		# "effect": effect_data_str(row),
		# "effect_type": row["effect_type"],
		"targeting": "." + row["targeting"],
		"windup": row["windup"] or 0,
		"cost": row["cost"] or 100,
		"cooldown": row["cooldown"] or 0,
		# "animation": ("." + row["animation"]) if row["animation"] else "nil",
		# "sound": ("." + row["sound"]) if row["sound"] else "nil",
		"description": process_text(row.get("description", "")),
	}
def write_skill(f, oskill):
	f.write("\t{{ \"{name}\", {targeting}, {windup}, {cost}, {cooldown}, \"{description}\" }},\n".format(**oskill))
	# f.write("\t{{ \"{name}\", {effect}, .{effect_type}, {targeting}, {windup}, {cost}, {cooldown}, {animation}, {sound}, \"{description}\" }},\n".format(**oskill))

in_f = open(f"{ROOT}/skills.csv")
reader = csv.DictReader(in_f, delimiter=",")
for row in reader:
	skills.append(odin_skill(row))
in_f.close()

out_f = open(f"{DEST}/skill_data.odin", "w")
out_f.write("package rules\n\n")

out_f.write("Skill_Name :: enum {\n")

for skill in skills:
	enum = name_to_enum(skill["name"])
	out_f.write(f"\t{enum},\n")
out_f.write("}\n\n")

out_f.write("@(rodata)\n")
out_f.write(f"skills := [{len(skills)}]Skill {{\n")
for skill in skills:
	write_skill(out_f, skill)
out_f.write("}\n")

out_f.close()

