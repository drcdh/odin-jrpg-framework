import csv

from processing import name_to_enum

ROOT = "./content"
DEST = "./src/game"

MAX_ENCOUNTER_SIZE = 6

encounters = {}

def odin_encounter(row):
	spots = ["{}"] * MAX_ENCOUNTER_SIZE
	for i in range(1, MAX_ENCOUNTER_SIZE + 1):
		baddy_id = name_to_enum(row[f"m{i}"])
		if not baddy_id:
			break
		spots[i - 1] = f"{{ {{ {row[f'p{i}']} }}, .{baddy_id} }}"
	return "{{ {{ {} }}, {} }}".format(", ".join(spots), int(row["exp"] or 0))

in_f = open(f"{ROOT}/encounters.csv")
reader = csv.DictReader(in_f, delimiter=",")
for row in reader:
	encounters[name_to_enum(row["name"])] = odin_encounter(row)
in_f.close()

out_f = open(f"{DEST}/encounter_data.odin", "w")
out_f.write("package game\n\n")

out_f.write("Encounter_Name :: enum {\n")
for name in encounters:
	out_f.write(f"\t{name},\n")
out_f.write("}\n\n")

out_f.write("@(rodata)\n")
out_f.write("encounters := [Encounter_Name]Encounter {\n")
for name, encounter in encounters.items():
	out_f.write(f"\t.{name} = {encounter},\n")
out_f.write("}\n")

out_f.close()
