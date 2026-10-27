import csv
import os

from processing import name_to_enum

ROOT = "./content"
DEST = "./src/rules"
GAME_DEST = "./src/game"
SPRITE_ROOT = "./assets/sprites"

# TODO: the downed column is scripting, not ported yet.

baddy_ids = []
templates = []
sprites = []

sprite_names = {name_to_enum(os.path.splitext(f)[0]) for f in os.listdir(SPRITE_ROOT) if f.endswith(".ase")}

# The texture column names the battle sprite; empty means a sprite named like
# the baddy, if there is one.
def baddy_sprite(row):
	if row["texture"]:
		return "." + name_to_enum(row["texture"])
	sprite = name_to_enum(row["name"])
	return "." + sprite if sprite in sprite_names else "nil"

def spoil(item, p):
	return "{{ {}, {} }}".format("." + item if item else "nil", p or "0")

def odin_template(row):
	skills = ",".join("." + name_to_enum(s) for s in row["skills"].split(","))
	return (
		f"name = \"{row['name']}\", "
		"stats = {{ {hitpoints},{vigor},{speed},{stamina},{psy_pow},{weap},{armor},{psy_def},{evasion} }}, ".format(**row)
		+ f"level = {row['level']}, "
		+ f"skills = {{ {skills} }}, "
		+ f"spoils = {{ {spoil(row['s1'], row['s1p'])}, {spoil(row['s2'], row['s2p'])} }}"
	)

# Repeated names get numbered: Tentacle_1, Tentacle_2, ...
n = 1
in_f = open(f"{ROOT}/baddies.csv")
reader = csv.DictReader(in_f, delimiter=",")
for row in reader:
	baddy_id = name_to_enum(row["name"])
	if baddy_ids and (baddy_id == baddy_ids[-1] or f"{baddy_id}_{n}" == baddy_ids[-1]):
		if n == 1:
			baddy_ids[-1] += "_1"
		n += 1
		baddy_id += f"_{n}"
	else:
		n = 1
	baddy_ids.append(baddy_id)
	templates.append(odin_template(row))
	sprites.append(baddy_sprite(row))
in_f.close()

out_f = open(f"{DEST}/baddy_data.odin", "w")
out_f.write("package rules\n\n")

out_f.write("Baddy_Id :: enum {\n")
for baddy_id in baddy_ids:
	out_f.write(f"\t{baddy_id},\n")
out_f.write("}\n\n")

out_f.write("@(rodata)\n")
out_f.write("baddy_templates := [Baddy_Id]Baddy_Template {\n")
for baddy_id, template in zip(baddy_ids, templates):
	out_f.write(f"\t.{baddy_id} = {{ {template} }},\n")
out_f.write("}\n")

out_f.close()


out_f = open(f"{GAME_DEST}/baddy_av_data.odin", "w")
out_f.write("package game\n\n")
out_f.write("import \"../rules\"\n\n")
out_f.write("Baddy_Id :: rules.Baddy_Id\n\n")
out_f.write("@(rodata)\n")
out_f.write("baddy_sprites := [Baddy_Id]Maybe(Sprite_Name) {\n")
for baddy_id, sprite in zip(baddy_ids, sprites):
	out_f.write(f"\t.{baddy_id} = {sprite},\n")
out_f.write("}\n")
out_f.close()
