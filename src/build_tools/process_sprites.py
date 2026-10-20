from collections import OrderedDict
import fnmatch
import json
import os
import subprocess

import processing

ROOT = "./assets/sprites"
DEST = "./src/engine"

sprite_names = []
sprites = []

def process_ase(name):
	sprite_names.append(processing.name_to_enum(name))
	tags = subprocess.check_output(f"aseprite -b --list-tags {ROOT}/{name}.ase".split()).decode(encoding="utf-8").strip()
	if tags:
		return process_ase_tagged(name)

	metadata = dict()
	data = json.loads(subprocess.check_output(f"aseprite -b --sheet {ROOT}/{name}.png --sheet-type rows --split-tags {ROOT}/{name}.ase".split()))
	frames = data["frames"]

	metadata["name"] = processing.name_to_enum(name)
	metadata["filename"] = name

	frame_num = len(frames)
	if frame_num == 1:
		metadata["frame_width"] = data["meta"]["size"]["w"]
		metadata["frame_height"] = data["meta"]["size"]["h"]
		metadata["kind"] = ".Static"
		sprites.append(".{name} = {{\"{filename}\", {{ {frame_width}, {frame_height} }}, {kind}, {{}}, {{}}, 0 }},\n".format(**metadata))
		return

	metadata["num_frames"] = frame_num
	for f in frames.values():
		metadata["frame_t"] = f["duration"]  # assume duration is same for all frames
		metadata["frame_width"] = f["sourceSize"]["w"]
		metadata["frame_height"] = f["sourceSize"]["h"]
		break
	metadata["kind"] = ".Anim"

	sprites.append(".{name} = {{\"{filename}\", {{ {frame_width}, {frame_height} }}, {kind}, {{}}, {{ {num_frames} }}, {frame_t} }},\n".format(**metadata))

def process_ase_tagged(name):
	metadata = dict()
	tag_frame_counts = OrderedDict()

	data = json.loads(subprocess.check_output(f"aseprite -b --sheet {ROOT}/{name}.png --sheet-type rows --split-tags {ROOT}/{name}.ase".split()))
	for k, v in data["frames"].items():
		k = k.split("#")[1][:-4]
		tag = k.split(" ")[0]
		tag_frame_counts[tag] = tag_frame_counts.get(tag, 0) + 1
		metadata["frame_width"] = v["sourceSize"]["w"]
		metadata["frame_height"] = v["sourceSize"]["h"]
		metadata["frame_t"] = v["duration"]

	metadata["name"] = processing.name_to_enum(name)
	metadata["filename"] = name
	metadata["frames_str"] = f"{{ {','.join(str(c) for c in tag_frame_counts.values())} }}"
	metadata["poses_str"] = f"{{ {','.join('.'+tag for tag in tag_frame_counts.keys())} }}"
	# metadata["num_poses"] = len(tag_frame_counts)
	metadata["kind"] = ".Tagged"

	sprites.append(".{name} = {{\"{filename}\", {{ {frame_width}, {frame_height} }}, {kind}, {poses_str}, {frames_str}, {frame_t} }},\n".format(**metadata))

def write_sprite_data(f):
	f.write("package engine\n\n")

	sort_order = [i[0] for i in sorted(enumerate(sprite_names), key=lambda x:x[1])]

	f.write("Sprite_Name :: enum {\n")
	for i in sort_order:
		s = sprite_names[i]
		f.write(s + ",\n")
	f.write("}")

	f.write("\n\n")

	f.write("@(rodata)\n")
	f.write("sprite_metadata := [Sprite_Name]Sprite_Metadata {\n")
	for i in sort_order:
		s = sprites[i]
		f.write(s)

	f.write("}")

def main():
	for file in os.listdir(ROOT):
		if fnmatch.fnmatch(file, "*.ase*"):
			print(f"processing {file}")
			process_ase(file[:-4])

	with open(f"{DEST}/sprite_data.odin", "w") as f:
		write_sprite_data(f)

if __name__ == "__main__":
	main()
