package rules

import "core:log"
import "core:math"
import "core:math/rand"

// Skill effects: these work out an effect, change the characters and return
// what happened. Showing it (numbers, sprites, sounds) is the game package's
// job, which differs between the world menu and battles.
//
// Each proc has a Character version and a Combatant version. Only Combatants
// can be staggered or counter.

VERBOSE :: #config(VERBOSE, false) // log the damage formula

Effect_Type :: enum {
	Attack,
	Heal,
	Level_Up,
	Death,
}

Effect_Data :: struct {
	constant:   int,
	power:      int,
	psy_power:  int,
	pierce:     int,
	psy_pierce: int,
	hit_acc:    int,
	stg_acc:    int,
	stagger:    int,
	int_acc:    int,
	sts_acc:    int,
	status:     Maybe(Status_Name),
	risk:       int,
	// traits
	ranged:     bool,
}

Hit_Result :: enum {
	Hit,
	Miss,
	Evade,
}

Status_Result :: enum {
	None,
	Added,
	Ineffective,
	Resisted,
	Removed,
	Remove_Missed,
}

Effect_Result :: struct {
	hit:           Hit_Result,
	hp_change:     int,  // < 0 damage, > 0 healing
	downed:        bool, // hitpoints reached 0
	status:        Maybe(Status_Name),
	status_result: Status_Result,
	levels:        int,
	stagger:       bool, // the target lost ticks (Combatants only)
	interrupted:   bool, // the target's windup was broken (Combatants only)
}

calc_damage :: proc(actor, target: Character, effect: Effect_Data) -> (int, bool) #optional_ok {
	if effect.power <= 0 && effect.psy_power <= 0 {return 0, false}

	ATTACK_COEFF :: 4
	SPREAD :: 10

	C := f16(effect.constant)
	Km := f16(effect.power) / 100
	Im := f16(effect.pierce) / 100
	Kp := f16(effect.psy_power) / 100
	Ip := f16(effect.psy_pierce) / 100

	L := f16(actor.level)
	Vg := get_stat(actor, .Vigor)
	Wp := get_stat(actor, .Weapon_Power)
	PP := get_stat(actor, .Psy_Power)

	L_ := f16(target.level)
	St_ := get_stat(target, .Stamina) * clamp(2 - Im, 0, 1)
	Ar_ := get_stat(target, .Armor) * clamp(1 - Im, 0, 1)
	PD_ := get_stat(target, .Psy_Defense) * clamp(1 - Ip, 0, 1) * Kp / (Km + Kp)

	LL_ := L / math.sqrt(L_)
	Nm := (Vg + Wp + 2 * math.sqrt(Vg * Wp)) * Km
	Np := 4 * PP * Kp
	D_ := (St_ + Ar_ + PD_)

	hp_loss_f := ATTACK_COEFF * LL_ * (Nm + Np) / D_
	swing := f16(rand.float32()) / SPREAD
	hp_loss_f -= hp_loss_f * swing

	hp_loss_f += C
	hp_loss := int(hp_loss_f + .5)

	when VERBOSE {
		log.debugf("  DMG   = %d * %.3f * (%.0f + %.0f) / %.0f = %.0f", ATTACK_COEFF, LL_, Nm, Np, D_, hp_loss_f)
		log.debugf("  SWING = %.3f, CONST = %.0f", swing, C)
		log.debugf("  DMG   = %f = %d", hp_loss_f, hp_loss)
	}

	return hp_loss, true
}

// The hit roll, damage and status. `actor` may be nil (an item), which deals no
// damage.
effect_attack_character :: proc(actor, target: ^Character, effect: Effect_Data) -> (r: Effect_Result) {
	acc := Stat(effect.hit_acc) // percentage
	roll := Stat(rand.int_max(100)) // [0, n)
	if roll >= acc {
		log.infof("Miss! (%s)", target.name)
		r.hit = .Miss
		return
	}
	if roll >= acc - get_stat(target^, .Evasion) {
		log.infof("Evade! (%s)", target.name)
		r.hit = .Evade
		return
	}

	if actor != nil {
		if hp_loss, ok := calc_damage(actor^, target^, effect); ok {
			take_damage(target, hp_loss)
			log.infof("%s takes %d damage", target.name, hp_loss)
			r.hp_change = -hp_loss
			if target.hitpoints == 0 {
				// battle: the target's downed callback
				log.infof("%s is down", target.name)
				r.downed = true
				return
			}
		}
	}

	r.status = effect.status
	r.status_result = _add_status(target, effect.sts_acc, effect.status)
	return
}

// The Character attack, then stagger and the target's chance to counter.
effect_attack_combatant :: proc(actor, target: ^Combatant, effect: Effect_Data) -> (r: Effect_Result) {
	r = effect_attack_character(actor, target, effect)
	if r.hit != .Hit || r.downed do return
	r.stagger, r.interrupted = _stagger(target, effect.stg_acc, effect.stagger, effect.int_acc)
	roll_for_counter(target, actor, f32(effect.risk) / 100)
	return
}

effect_attack :: proc {
	effect_attack_character,
	effect_attack_combatant,
}

// `actor` may be nil (an item), which adds no psy power.
effect_heal :: proc(actor, target: ^Character, effect: Effect_Data) -> (r: Effect_Result) {
	psy_power := Stat(effect.psy_power) / 100
	hp_gain_f := Stat(effect.constant)
	if psy_power > 0 && actor != nil {
		hp_gain_f += psy_power * get_stat(actor^, .Psy_Power)
	}
	hp_gain_f = max(0, hp_gain_f)
	before := target.hitpoints
	target.hitpoints = min(target.hitpoints + int(hp_gain_f), int(get_stat(target^, .Hitpoints))) // TODO: put this everywhere
	r.hp_change = target.hitpoints - before
	if r.hp_change > 0 do log.infof("%s gains %d HP", target.name, r.hp_change)

	r.status = effect.status
	r.status_result = _remove_status(target, effect.sts_acc, effect.status)
	return
}

_add_status :: proc(target: ^Character, sts_acc: int, status: Maybe(Status_Name)) -> Status_Result {
	s, ok := status.?
	if !ok do return .None
	acc := Stat(sts_acc)
	roll := Stat(rand.int_max(100))
	if roll >= acc {
		log.infof("Ineffective status %s on %s (rolled %.0f >= %.0f)", s, target.name, roll, acc)
		return .Ineffective
	}
	res := Stat(0) // TODO: get_stat(target, resistance_stat(status))
	if roll >= acc - res {
		log.infof("%s resisted status %s (rolled %.0f >= %.0f)", target.name, s, roll, acc - res)
		return .Resisted
	}
	log.infof("Adding status %s to %s (rolled %.0f < %.0f)", s, target.name, roll, acc - res)
	add_status(target, s)
	return .Added
}

_remove_status :: proc(target: ^Character, sts_acc: int, status: Maybe(Status_Name)) -> Status_Result {
	s, ok := status.?
	if !ok do return .None
	acc := Stat(sts_acc)
	roll := Stat(rand.int_max(100))
	if roll >= acc {
		log.infof("Missed removing status %s on %s (rolled %.0f >= %.0f)", s, target.name, roll, acc)
		return .Remove_Missed
	}
	log.infof("Removing status %s from %s (rolled %.0f < %.0f)", s, target.name, roll, acc)
	remove_status(target, s)
	return .Removed
}

// Takes `stagger` ticks from the target and may interrupt their windup.
_stagger :: proc(target: ^Combatant, stg_acc, stagger, int_acc: int) -> (staggered, interrupted: bool) {
	if stagger <= 0 && int_acc <= 0 do return
	acc := Stat(stg_acc)
	roll := Stat(rand.int_max(100))
	if roll >= acc {
		log.infof("Stagger resisted by %s (rolled %.0f >= %.0f)", target.name, roll, acc)
		return
	}
	if stagger > 0 {
		log.infof("Staggering %s by %d (rolled %.0f < %.0f)", target.name, stagger, roll, acc)
		target.ticks -= Ticks(stagger)
		staggered = true
	}
	if rand.int_max(100) < int_acc {
		interrupted = interrupt_windup(target)
	}
	return
}

effect_level_up :: proc(_, target: ^Character, effect: Effect_Data) -> (r: Effect_Result) {
	n := effect.constant
	set_level(target, target.level + n)
	set_all_skills() // FIXME: shouldn't be necessary to reset all
	log.infof("%s gains %d level(s)", target.name, n)
	r.levels = n
	return
}

effect_death :: proc(_, target: ^Character, effect: Effect_Data) -> (r: Effect_Result) {
	acc := Stat(effect.hit_acc)
	roll := Stat(rand.int_max(100))
	if roll >= acc {
		log.infof("Missed instant death on %s (rolled %.0f >= %.0f)", target.name, roll, acc)
		r.hit = .Miss
		return
	}
	r.hp_change = -target.hitpoints
	instakill(target)
	log.infof("%s is down", target.name)
	r.downed = true
	return
}

do_effect_character :: proc(actor, target: ^Character, effect: Effect_Data, effect_type: Effect_Type) -> Effect_Result {
	if actor != nil {
		when VERBOSE do log.debugf("%s -> %s: %v", actor.name, target.name, effect)
	} else {
		log.debugf("%s: %v", target.name, effect)
	}
	switch effect_type {
	case .Attack:   return effect_attack_character(actor, target, effect)
	case .Heal:     return effect_heal(actor, target, effect)
	case .Level_Up: return effect_level_up(actor, target, effect)
	case .Death:    return effect_death(actor, target, effect)
	}
	return {}
}

// Only attacks differ for Combatants (stagger and counter).
do_effect_combatant :: proc(actor, target: ^Combatant, effect: Effect_Data, effect_type: Effect_Type) -> Effect_Result {
	if effect_type == .Attack do return effect_attack_combatant(actor, target, effect)
	return do_effect_character(actor, target, effect, effect_type)
}

do_effect :: proc {
	do_effect_character,
	do_effect_combatant,
}
