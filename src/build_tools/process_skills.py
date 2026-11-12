import csv
import pathlib

from processing import name_to_enum, process_text

ROOT = "./content/skills"
DEST = "./src/game"

DEFAULTS = dict(
	risk=100,
	ranged="false",
	# traits="???",
)
TYPES = dict(
	ranged=str,
	status=str,
) # others are int

skills = []

def effect_data(row):
	return {k: str(bool(v)).lower() if k == "ranged" else TYPES.get(k, int)(v if v != "" else DEFAULTS[k]) for k, v in row.items() if k in DEFAULTS}

def blah(k, v):
	if k == "status" and v != "nil":
		return f".{v}"
	return v

def effect_data_str(row):
	d = effect_data(row)
	return "{" + ",".join([f"{k}={blah(k, v)}" for k, v in d.items()]) + "}"

def odin_skill(row):
	return {
		"name": row["name"],
		# "effect": effect_data_str(row),
		# "effect_type": row["effect_type"],
		"target": "." + row["target"],
		"offensive": "true" if bool(row["offensive"]) else "false",
		"windup": row["windup"] or 0,
		"cost": row["cost"] or 100,
		"cooldown": row["cooldown"] or 0,
		# "animation": ("." + row["animation"]) if row["animation"] else "nil",
		# "sound": ("." + row["sound"]) if row["sound"] else "nil",
		"description": process_text(row.get("description", "")),
		"procedure": "skill_proc_" + name_to_enum(row["proc"] or row["name"]).lower(),
	}
def write_skill(f, oskill):
	f.write("\t{{ \"{name}\", {target}, {offensive}, {windup}, {cost}, {cooldown}, \"{description}\", {procedure} }},\n".format(**oskill))
	# f.write("\t{{ \"{name}\", {effect}, .{effect_type}, {target}, {offensive}, {windup}, {cost}, {cooldown}, {animation}, {sound}, \"{description}\" }},\n".format(**oskill))


for file in sorted(pathlib.Path(ROOT).rglob("*.csv")):
	in_f = open(file)
	reader = csv.DictReader(in_f, delimiter=",")
	for row in reader:
		skills.append(odin_skill(row))
	in_f.close()

out_f = open(f"{DEST}/skill_data.odin", "w")
out_f.write("package game\n\n")

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
