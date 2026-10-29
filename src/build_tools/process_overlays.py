import fnmatch
import os
import subprocess

ROOT = "./assets/overlays"
DEST = "./src/game"

overlays = {"None": ""}

def process_ase(file):
	name = file[:-4]
	png_file = f"{name}.png"
	subprocess.run(f"aseprite -b {ROOT}/{file} --save-as {ROOT}/{png_file}".split())
	overlays[name.title()] = png_file

def process_png(file):
	name = file[:-4]
	overlays[name.title()] = file

def write_odin(f):
	f.write("package game\n\n")
	f.write("Overlay :: enum {\n")
	for enum in overlays.keys():
		f.write(f"\t{enum},\n")
	f.write("}\n\n")

	f.write("@(rodata)\n")
	f.write("overlay_paths := [Overlay]cstring{\n")
	for enum, s in overlays.items():
		f.write(f"\t.{enum} = \"{s}\",\n")
	f.write("}")

def main():
	for file in os.listdir(ROOT):
		if fnmatch.fnmatch(file, "*.png"):
			process_png(file)
		elif fnmatch.fnmatch(file, "*.ase*"):
			print(f"processing {file}")
			process_ase(file)
	with open(f"{DEST}/overlay_data.odin", "w") as f:
		write_odin(f)

if __name__ == "__main__":
	main()
