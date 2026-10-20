def name_to_enum(name):
	return name \
		.replace("-", "_") \
		.replace(" ", "_") \
		.replace("'", "") \
		.title()

def process_text(text, width=28):
	result = ""
	while text:
		if len(text) <= width:
			result += text
			text = ""
		elif (newline := text[:width].find("\\n")) >= 0:
			result += text[:newline] + "\\n"
			text = text[newline+2:]
		else:
			space = text[:width].rfind(" ")
			result += text[:space] + "\\n"
			text = text[space+1:]
	result = result.replace("’", "'")
	result = result.replace("‘", "'")
	result = " " + result
	return result

if __name__ == "__main__":
	print(process_text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.", 20))
