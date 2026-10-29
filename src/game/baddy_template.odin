package game

Downed_Proc :: #type proc(c_idx: int, runner_idx: Maybe(int)) -> Maybe(int)

Spoil :: struct {
	item: Maybe(Item_Name),
	p:    u8,
}

Spoils :: #type [2]Spoil

Baddy_Template :: struct {
	name:    string,
	skills:  Skill_Set,
	stats:   Stats,
	level:   int,
	downed:  Downed_Proc,
	spoils:  Spoils,
	texture: Sprite_Name,
}

sudden_death: bool // debug mode

new_baddy :: proc(template: Baddy_Template) -> ^Character {
	baddy := new(Character)
	baddy.name = template.name
	baddy.hitpoints = 1 if sudden_death else int(get_stat(template.stats, .Hitpoints))
	baddy.skills = new_charged_skills(template.skills)
	baddy.stats = template.stats
	baddy.level = template.level
	return baddy
}
