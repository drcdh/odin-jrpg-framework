import os

from processing import name_to_enum

ROOT = "./assets/audio"
DEST = "./src/game"
EXTENSIONS = (".wav", ".mp3", ".ogg", ".flac", ".qoa", ".xm", ".mod")

# Each audio file in `folder` becomes an enum value named after the file
# (door_knock.wav -> Door_Knock) and an entry in the table of filenames.
def write_audio_data(folder, enum, table, out_name, none=False):
	files = sorted(f for f in os.listdir(f"{ROOT}/{folder}") if f.lower().endswith(EXTENSIONS))
	names = [name_to_enum(os.path.splitext(f)[0]) for f in files]

	out_f = open(f"{DEST}/{out_name}", "w")
	out_f.write("package game\n\n")
	out_f.write(f"{enum} :: enum {{\n")
	if none:
		out_f.write("\tNone, // silence\n")
	for name in names:
		out_f.write(f"\t{name},\n")
	out_f.write("}\n\n")

	out_f.write(f"// Files in assets/audio/{folder}\n")
	out_f.write("@(rodata)\n")
	out_f.write(f"{table} := [{enum}]string {{\n")
	if none:
		out_f.write("\t.None = \"\",\n")
	for name, f in zip(names, files):
		out_f.write(f"\t.{name} = \"{f}\",\n")
	out_f.write("}\n")
	out_f.close()

write_audio_data("sounds", "Sound_Name", "sound_files", "sound_data.odin")
write_audio_data("music", "Music_Name", "music_files", "music_data.odin", none=True)
