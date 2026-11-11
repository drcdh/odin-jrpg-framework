package game

import "core:log"
import "core:math"
import "core:math/rand"

VERBOSE :: #config(VERBOSE, false) // log the damage formula

Effect_Type :: enum {
	Attack,
	Heal,
	Level_Up,
	Death,
}

Attack_Data :: struct {
	acc:        int,
	constant:   int,
	power:      int,
	psy_power:  int,
	pierce:     int,
	psy_pierce: int,
	stg_acc:    int,
	stagger:    int,
	int_acc:    int,
	// ranged:     bool,
	// risk:       int,
}

Heal_Data :: struct {
	acc:    int,
	constant:   int,
	psy_power:  int,
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
	None, // no attempt made (e.g., a downed character was a candidate target for an all-team attack)
	Miss, // skill failed
	Evade, // target evaded (think of dodging with body)
	Resist, // target resisted (think of armor or enchantments)
	Hit, // damage or stagger done
}

Status_Result :: enum {
	None,
	Added,
	Ineffective,
	Resisted,
	Removed,
	Remove_Missed,
}

Heal_Result :: enum {
	None,
	Miss,
	Ineffective, // e.g., Zombie
	Effective,
}

Effect_Result :: struct {
	hit:           Hit_Result,
	hp_change:     int,  // < 0 damage, > 0 healing
	downed:        bool, // hitpoints reached 0
	status:        Maybe(Status_Name),
	status_result: Status_Result,
	levels:        int,
	stagger:       bool, // the target lost ticks (Characters only)
	interrupted:   bool, // the target's windup was broken (Characters only)
}

ASI_Result :: struct {
	attack_result: Hit_Result,
	damage: int,
	stagger_result: Hit_Result,
	stagger: int,
	interrupt_result: Hit_Result,
}

try_attack_damage :: proc(actor, target: Character, attack: Attack_Data) -> (h: Hit_Result, d: int) {
	h = try_attack_hit(actor, target, attack.acc)
	if h == .Hit do d = attack_damage(actor, target, attack)
	return
}

try_attack_stagger :: proc(actor, target: Character, attack: Attack_Data) -> (h: Hit_Result, d: int) {
	h = try_stagger_hit(actor, target, attack.stg_acc)
	if h == .Hit do d = attack.stagger
	return
}

try_attack_interrupt :: proc(actor, target: Character, attack: Attack_Data) -> Hit_Result {
	return try_interrupt_hit(actor, target, attack.int_acc)
}

try_attack :: proc(actor, target: Character, attack: Attack_Data) -> (r: ASI_Result) {
	// if attack never does damage, skip the attack attempt and go immediately to the stagger attempt
	if attack.power + attack.psy_power > 0 {
		r.attack_result, r.damage = try_attack_damage(actor, target, attack)
	} else {
		r.attack_result, r.damage = .None, 0
	}
	if r.attack_result == .Hit || r.attack_result == .None {
		r.stagger_result, r.stagger = try_attack_stagger(actor, target, attack)
		if r.stagger_result == .Hit do r.interrupt_result = try_attack_interrupt(actor, target, attack)
	}
	return
}

attack_damage :: proc(actor, target: Character, effect: Attack_Data) -> (int, bool) #optional_ok {
	if effect.constant <= 0 && effect.power <= 0 && effect.psy_power <= 0 {return 0, false}

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

	if actor.team == target.team && !has_any_status(actor, .Confuse, .Control, .Rage, .Zombie) {
		log.info("reducing damage because actor and target are on same team and actor is not afflicted")
		hp_loss_f *= 0.2
	}

	hp_loss_f += C
	hp_loss := int(hp_loss_f + .5)

	when VERBOSE {
		log.debugf("  DMG   = %d * %.3f * (%.0f + %.0f) / %.0f = %.0f", ATTACK_COEFF, LL_, Nm, Np, D_, hp_loss_f)
		log.debugf("  SWING = %.3f, CONST = %.0f", swing, C)
		log.debugf("  DMG   = %f = %d", hp_loss_f, hp_loss)
	}

	return hp_loss, true
}

try_attack_hit :: proc(actor, target: Character, skill_acc: int) -> Hit_Result {
	// TODO: Character accuracy
	// c_acc := get_stat(actor, .Acc)
	// acc = skill_acc * c_acc
	acc := Stat(skill_acc)
	log.infof("%s rolling for attack on %s with accuracy = %.0f", actor.name, target.name, acc)
	// log.infof("%s rolling for attack on %s with accuracy = %.0f * %.0f = %.0f", actor.name, target.name, skill_acc, c_acc, acc)
	roll := Stat(rand.int_max(100)) // [0, n)
	if roll >= acc {
		log.infof("Miss (%s)", target.name)
		return .Miss
	}
	if roll >= acc - get_stat(target, .Evasion) {
		log.infof("Evade (%s)", target.name)
		return .Evade
	}
	log.infof("Hit (%s)", target.name)
	return .Hit
}

try_stagger_hit :: proc(actor, target: Character, skill_acc: int) -> Hit_Result {
	// TODO: Character accuracy
	// c_acc := get_stat(actor, .Acc)
	// acc = skill_acc * c_acc
	acc := Stat(skill_acc)
	log.infof("%s rolling for stagger on %s with accuracy = %.0f", actor.name, target.name, acc)
	// log.infof("%s rolling for stagger on %s with accuracy = %.0f * %.0f = %.0f", actor.name, target.name, skill_acc, c_acc, acc)
	roll := Stat(rand.int_max(100)) // [0, n)
	if roll >= acc {
		log.infof("Miss (%s)", target.name)
		return .Miss
	}
	// if roll >= acc - get_stat(target, .Stagger_Resist) {
	// 	log.infof("Resist (%s)", target.name)
	// 	return .Evade
	// }
	log.infof("Hit (%s)", target.name)
	return .Hit
}

try_interrupt_hit :: proc(actor, target: Character, skill_acc: int) -> Hit_Result {
	// TODO: Character accuracy
	// c_acc := get_stat(actor, .Acc)
	// acc = skill_acc * c_acc
	acc := Stat(skill_acc)
	log.infof("%s rolling for interrupt on %s with accuracy = %.0f", actor.name, target.name, acc)
	// log.infof("%s rolling for interrupt on %s with accuracy = %.0f * %.0f = %.0f", actor.name, target.name, skill_acc, c_acc, acc)
	roll := Stat(rand.int_max(100)) // [0, n)
	if roll >= acc {
		log.infof("Miss (%s)", target.name)
		return .Miss
	}
	// if roll >= acc - get_stat(target, .Interrupt_Resist) {
	// 	log.infof("Resist (%s)", target.name)
	// 	return .Evade
	// }
	log.infof("Hit (%s)", target.name)
	return .Hit
}

try_status_hit :: proc(target: Character, status_effect: Status_Effect) -> Hit_Result {
	acc := Stat(status_effect.acc)
	log.infof("rolling for %v on %s with accuracy = %.0f", status_effect.status, target.name, acc)
	roll := Stat(rand.int_max(100)) // [0, n)
	if roll >= acc {
		log.infof("Miss (%s)", target.name)
		return .Miss
	}
	// if roll >= acc - get_stat(target, resist_status_stat(status_effect.status)) {
	// 	log.infof("Resist (%s)", target.name)
	// 	return .Evade
	// }
	log.infof("Hit (%s)", target.name)
	return .Hit
}

// effect_attack :: proc(actor, target: ^Character, effect: Effect_Data) -> (r: Effect_Result) {
// 	acc := Stat(effect.hit_acc) // percentage
// 	// TODO: accuracy is affected by Berserk, Blind, etc.
// 	roll := Stat(rand.int_max(100)) // [0, n)
// 	if roll >= acc {
// 		log.infof("Miss! (%s)", target.name)
// 		r.hit = .Miss
// 		return
// 	}
// 	if roll >= acc - get_stat(target^, .Evasion) {
// 		log.infof("Evade! (%s)", target.name)
// 		r.hit = .Evade
// 		return
// 	}
//
// 	// TODO: "actor-agnostic" calc_damage for items
// 	if actor != nil {
// 		if hp_loss, ok := calc_damage(actor^, target^, effect); ok {
// 			if has_status(target^, .Sleep) {
// 				log.info("removing Sleep from hit target")
// 				remove_status(target, .Sleep)
// 			}
// 			take_damage(target, hp_loss)
// 			log.infof("%s takes %d damage", target.name, hp_loss)
// 			r.hp_change = -hp_loss
// 			if target.hitpoints == 0 {
// 				// battle: the target's downed callback
// 				log.infof("%s is down", target.name)
// 				r.downed = true
// 				return
// 			}
// 		}
// 	}
//
// 	r.status = effect.status
// 	r.status_result = _add_status(target, effect.sts_acc, effect.status)
//
// 	if r.hit != .Hit || r.downed do return
// 	if r.status == .Control && r.status_result == .Added {
// 		add_status(actor, .Controller)
// 		target.controller = actor
// 	}
// 	r.stagger, r.interrupted = _stagger(target, effect.stg_acc, effect.stagger, effect.int_acc)
// 	// TODO: risk is affected by Berserk, Blind, Confuse
// 	roll_for_counter(target, actor, f32(effect.risk) / 100)
// 	return
// }

// `actor` may be nil (an item), which adds no psy power.
try_heal :: proc(actor, target: ^Character, effect: Heal_Data) -> (r: Heal_Result, g: int) {
	if has_status(target^, .Zombie) {
		r, g = .Ineffective, 0
		return
	}
	acc := Stat(effect.acc)
	hp_gain_f := Stat(effect.constant)
	psy_power := Stat(effect.psy_power) / 100
	if actor != nil {
		if has_status(actor^, .Migraine) do acc *= .5
		if psy_power > 0 do hp_gain_f += psy_power * get_stat(actor^, .Psy_Power)
	}
	if actor != nil {
		log.infof("%s rolling for heal on %s with accuracy = %.0f", actor.name, target.name, acc)
	} else {
		log.infof("rolling for heal on %s with accuracy = %.0f", target.name, acc)
	}
	roll := Stat(rand.int_max(100)) // [0, n)
	if roll >= acc {
		log.info("Miss")
		r, g = .Miss, 0
		return
	}
	log.info("Hit")
	hp_gain_f = max(0, hp_gain_f)
	g = int(hp_gain_f)
	r = .Ineffective if g == 0 else .Effective
	return
}

try_add_status :: proc(target: ^Character, sts_acc: int, status: Status_Name) -> Status_Result {
	log.infof("attempting to affect %s with %v", target.name, status)
	// Think of prior status as affecting the accuracy of incoming status, NOT as granting resistance
	acc := Stat(sts_acc) * interstatus_accuracy_mod(target^, status)
	roll := Stat(rand.int_max(100))
	if roll >= acc {
		log.infof("Ineffective status %s on %s (rolled %.0f >= %.0f)", status, target.name, roll, acc)
		return .Ineffective
	}
	res := Stat(0) // TODO: get_stat(target, resistance_stat(status))
	if roll >= acc - res {
		log.infof("%s resisted status %s (rolled %.0f >= %.0f)", target.name, status, roll, acc - res)
		return .Resisted
	}
	log.infof("Adding status %s to %s (rolled %.0f < %.0f)", status, target.name, roll, acc - res)
	add_status(target, status)
	// FIXME: Character.controller needs to get set when adding .Control status
	return .Added
}

@(private = "file")
_add_status :: proc(target: ^Character, sts_acc: int, status: Maybe(Status_Name)) -> Status_Result {
	s, ok := status.?
	if !ok do return .None
	// Think of prior status as affecting the accuracy of incoming status, NOT as granting resistance
	acc := Stat(sts_acc) * interstatus_accuracy_mod(target^, s)
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
	// FIXME: Character.controller needs to get set when adding .Control status
	return .Added
}

try_remove_status :: proc(target: ^Character, sts_acc: int, status: Status_Name) -> Status_Result {
	acc := Stat(sts_acc)
	roll := Stat(rand.int_max(100))
	if roll >= acc {
		log.infof("Missed removing status %s on %s (rolled %.0f >= %.0f)", status, target.name, roll, acc)
		return .Remove_Missed
	}
	log.infof("Removing status %s from %s (rolled %.0f < %.0f)", status, target.name, roll, acc)
	remove_status(target, status)
	return .Removed
}

@(private = "file")
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
// @(private = "file")
// _stagger :: proc(target: ^Character, stg_acc, stagger, int_acc: int) -> (staggered, interrupted: bool) {
// 	if stagger <= 0 && int_acc <= 0 do return
// 	acc := Stat(stg_acc)
// 	roll := Stat(rand.int_max(100))
// 	if roll >= acc {
// 		log.infof("Stagger resisted by %s (rolled %.0f >= %.0f)", target.name, roll, acc)
// 		return
// 	}
// 	if stagger > 0 {
// 		if skill_play_idx, ok := get_combatant_skill_play(target).?; ok {
// 			log.infof("Staggering %s skill charge by %d (rolled %.0f < %.0f)", target.name, stagger, roll, acc)
// 			delay_charge(&battle.skill_plays[skill_play_idx].charge, Ticks(stagger))
// 			staggered = true
// 		} else {
// 			log.infof("Staggering %s turn charge by %d (rolled %.0f < %.0f)", target.name, stagger, roll, acc)
// 			delay_charge(&target.charge, Ticks(stagger))
// 			staggered = true
// 		}
// 	}
// 	if rand.int_max(100) < int_acc {
// 		interrupted = interrupt_windup(target)
// 	}
// 	return
// }

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
//
// do_effect :: proc(actor, target: ^Character, effect: Effect_Data, effect_type: Effect_Type) -> Effect_Result {
// 	if actor != nil {
// 		when VERBOSE do log.debugf("%s -> %s: %v", actor.name, target.name, effect)
// 	} else {
// 		log.debugf("%s: %v", target.name, effect)
// 	}
// 	switch effect_type {
// 	case .Attack:   return effect_attack(actor, target, effect)
// 	case .Heal:     return effect_heal(actor, target, effect)
// 	case .Level_Up: return effect_level_up(actor, target, effect)
// 	case .Death:    return effect_death(actor, target, effect)
// 	}
// 	return {}
// }
