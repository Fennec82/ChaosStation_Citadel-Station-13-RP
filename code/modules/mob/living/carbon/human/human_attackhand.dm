/mob/living/carbon/human/proc/get_unarmed_attack(var/mob/living/carbon/human/target, var/hit_zone)

	if(nif && nif.flag_check(NIF_C_HARDCLAWS,NIF_FLAGS_COMBAT)){return unarmed_hardclaws}
	if(src.default_attack && src.default_attack.is_usable(src, target, hit_zone))
		if(pulling_punches)
			var/datum/unarmed_attack/soft_type = src.default_attack.get_sparring_variant()
			if(soft_type)
				return soft_type
		return src.default_attack

	if(src.gloves)
		var/obj/item/clothing/gloves/G = src.gloves
		if(istype(G) && G.special_attack && G.special_attack.is_usable(src, target, hit_zone))
			if(pulling_punches)
				var/datum/unarmed_attack/soft_type = G.special_attack.get_sparring_variant()
				if(soft_type)
					return soft_type
			return G.special_attack
	for(var/datum/unarmed_attack/u_attack in species.unarmed_attacks)
		if(u_attack.is_usable(src, target, hit_zone))
			if(pulling_punches)
				var/datum/unarmed_attack/soft_variant = u_attack.get_sparring_variant()
				if(soft_variant)
					return soft_variant
			return u_attack
	return null

/mob/living/carbon/human/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	var/datum/gender/TT = GLOB.gender_datums[user.get_visible_gender()]
	var/mob/living/carbon/human/H = user
	if(istype(H))
		var/obj/item/organ/external/temp = H.organs_by_name["r_hand"]
		if(H.active_hand % 2)
			temp = H.organs_by_name["l_hand"]
		if(!temp || !temp.is_usable())
			to_chat(H, "<font color='red'>You can't use your hand.</font>")
			return
	if(H.lying)
		return
	user.break_cloak()

	. = ..()
	if(. & CLICKCHAIN_DO_NOT_PROPAGATE)
		return

	// Should this all be in Touch()?
	if(istype(H))
		if(H.get_accuracy_penalty() && H != src)	//Should only trigger if they're not aiming well
			var/hit_zone = get_zone_with_miss_chance(H.zone_sel.selecting, src, H.get_accuracy_penalty())
			if(!hit_zone)
				H.do_attack_animation(src)
				playsound(loc, 'sound/weapons/punchmiss.ogg', 25, 1, -1)
				visible_message("<font color='red'><B>[H] reaches for [src], but misses!</B></font>")
				return FALSE

		if(user.a_intent != INTENT_HARM)
			var/shieldcall_results = atom_shieldcall_handle_touch(new /datum/event_args/actor/clickchain(user))
			if(shieldcall_results & SHIELDCALL_FLAGS_BLOCK_ATTACK)
				H.do_attack_animation(src)
				return FALSE

	if(istype(user,/mob/living/carbon))
		var/mob/living/carbon/C = user
		C.spread_disease_to(src, "Contact")

	var/mob/living/L = user
	if(!istype(L))
		return

	switch(L.a_intent)
		if(INTENT_HELP)
			if(iscarbon(L) && attempt_cpr_interaction(L))
				return TRUE
			else if(!(L == src && apply_pressure(L, L.zone_sel.selecting)))
				help_shake_act(L)
			return TRUE

		if(INTENT_GRAB)
			if(L == src || anchored)
				return 0
			for(var/obj/item/grab/G in src.grabbed_by)
				if(G.assailant == L)
					to_chat(L, "<span class='notice'>You already grabbed [src].</span>")
					return
			if(w_uniform)
				w_uniform.add_fingerprint(L)

			var/obj/item/grab/G = new /obj/item/grab(L, src)
			if(buckled)
				to_chat(L, "<span class='notice'>You cannot grab [src], [TT.he] is buckled in!</span>")
				return
			if(!G)	//the grab will delete itself in New if affecting is anchored
				return
			L.put_in_active_hand(G)
			LAssailant = L

			H.do_attack_animation(src)
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
			visible_message("<span class='warning'>[L] has grabbed [src] [(L.zone_sel.selecting == BP_L_HAND || L.zone_sel.selecting == BP_R_HAND)? "by [(gender==FEMALE)? "her" : ((gender==MALE)? "his": "their")] hands": "passively"]!</span>")

			return TRUE

		if(INTENT_HARM)

			if(L.zone_sel.selecting == "mouth" && wear_mask && istype(wear_mask, /obj/item/grenade))
				var/obj/item/grenade/G = wear_mask
				if(!G.active)
					visible_message("<span class='danger'>\The [L] pulls the pin from \the [src]'s [G.name]!</span>")
					G.activate(L)
					update_inv_wear_mask()
				else
					to_chat(L, "<span class='warning'>\The [G] is already primed! Run!</span>")
				return

			if(!istype(H))
				attack_generic(H,rand(1,3),"punched")
				return

			// var/rand_damage = rand(1, 5)
			var/rand_damage = 0
			var/block = 0
			var/accurate = 0
			var/hit_zone = H.zone_sel.selecting
			var/obj/item/organ/external/affecting = get_organ(hit_zone)

			if(!affecting || affecting.is_stump())
				to_chat(L, "<span class='danger'>They are missing that limb!</span>")
				return TRUE

			switch(src.a_intent)
				if(INTENT_HELP)
					// We didn't see this coming, so we get the full blow
					// rand_damage = 5
					accurate = 1
				if(INTENT_HARM, INTENT_GRAB)
					// We're in a fighting stance, there's a chance we block
					if(CHECK_MOBILITY(src, MOBILITY_CAN_MOVE) && src!=H && prob(20))
						block = 1

			// if (L.grabbed_by.len)
				// Someone got a good grip on them, they won't be able to do much damage
				// rand_damage = max(1, rand_damage - 2)

			if(src.grabbed_by.len || src.buckled || !CHECK_MOBILITY(src, MOBILITY_CAN_MOVE) || src==H)
				accurate = 1 // certain circumstances make it impossible for us to evade punches

			// Process evasion and blocking
			var/miss_type = 0
			var/attack_message
			if(!accurate)
				/* ~Hubblenaut
					This place is kind of convoluted and will need some explaining.
					ran_zone() will pick out of 11 zones, thus the chance for hitting
					our target where we want to hit them is circa 9.1%.

					Now since we want to statistically hit our target organ a bit more
					often than other organs, we add a base chance of 20% for hitting it.

					This leaves us with the following chances:

					If aiming for chest:
						27.3% chance you hit your target organ
						70.5% chance you hit a random other organ
						 2.2% chance you miss

					If aiming for something else:
						23.2% chance you hit your target organ
						56.8% chance you hit a random other organ
						15.0% chance you miss

					Note: We don't use get_zone_with_miss_chance() here since the chances
						  were made for projectiles.
					TODO: proc for melee combat miss chances depending on organ?
				*/

				if(!hit_zone)
					attack_message = "[H] attempted to strike [src], but missed!"
					miss_type = 1

				if(prob(80))
					hit_zone = ran_zone(hit_zone, 70) //70% chance to hit what you're aiming at seems fair?
				if(prob(15) && hit_zone != BP_TORSO) // Missed!
					if(!src.lying)
						attack_message = "[H] attempted to strike [src], but missed!"
					else
						attack_message = "[H] attempted to strike [src], but [TT.he] rolled out of the way!"
						src.setDir(pick(GLOB.cardinal))
					miss_type = 1

			if(!miss_type && block)
				attack_message = "[H] went for [src]'s [affecting.name] but was blocked!"
				miss_type = 2

			// See what attack they use
			var/datum/unarmed_attack/attack = H.get_unarmed_attack(src, hit_zone)
			if(!attack)
				return FALSE

			var/shieldcall_results = atom_shieldcall_handle_unarmed_melee(attack, new /datum/event_args/actor/clickchain(user))
			if(shieldcall_results & SHIELDCALL_FLAGS_BLOCK_ATTACK)
				H.do_attack_animation(src)
				return FALSE

			if(attack.unarmed_override(H, src, hit_zone))
				return FALSE

			H.animate_swing_at_target(src)
			animate_hit_by_attack(attack.animation_type)
			if(!attack_message)
				attack.show_attack(H, src, hit_zone, rand_damage)
			else
				H.visible_message("<span class='danger'>[attack_message]</span>")

			playsound(loc, ((miss_type) ? (miss_type == 1 ? attack.miss_sound : 'sound/weapons/thudswoosh.ogg') : attack.attack_sound), 25, 1, -1)

			add_attack_logs(H,src,"Melee attacked with fists (miss/block)")

			if(miss_type)
				return FALSE

			var/real_damage = rand_damage
			var/hit_dam_type = attack.damage_type
			real_damage += attack.get_unarmed_damage(H)
			if(H.gloves)
				if(istype(H.gloves, /obj/item/clothing/gloves))
					var/obj/item/clothing/gloves/G = H.gloves
					real_damage += G.punch_force
					hit_dam_type = G.punch_damtype
					if(H.pulling_punches && !(attack.damage_mode & (DAMAGE_MODE_EDGE | DAMAGE_MODE_SHARP)))	//SO IT IS DECREED: PULLING PUNCHES WILL PREVENT THE ACTUAL DAMAGE FROM RINGS AND KNUCKLES, BUT NOT THE ADDED PAIN, BUT YOU CAN'T "PULL" A KNIFE
						hit_dam_type = AGONY
			real_damage *= damage_multiplier
			rand_damage *= damage_multiplier
			if(MUTATION_HULK in H.mutations)
				real_damage *= 2 // Hulks do twice the damage
				rand_damage *= 2
			real_damage = max(1, real_damage)

			var/armour = run_armor_check(hit_zone, "melee")
			var/soaked = get_armor_soak(hit_zone, "melee")
			// Apply additional unarmed effects.
			attack.apply_effects(H, src, armour, rand_damage, hit_zone)

			// Finally, apply damage to target
			apply_damage(real_damage, hit_dam_type, hit_zone, armour, soaked, sharp = attack.damage_mode & DAMAGE_MODE_SHARP, edge = attack.damage_mode & DAMAGE_MODE_EDGE)

		if(INTENT_DISARM)
			add_attack_logs(H,src,"Disarmed")

			L.do_attack_animation(src)

			if(w_uniform)
				w_uniform.add_fingerprint(L)
			var/obj/item/organ/external/affecting = get_organ(ran_zone(L.zone_sel.selecting))

			var/list/holding = list(get_active_held_item() = 40, get_inactive_held_item = 20)

			//See if they have any guns that might go off
			for(var/obj/item/gun/W in holding)
				if(W && prob(holding[W]))
					var/list/turfs = list()
					for(var/turf/T in view())
						turfs += T
					if(turfs.len)
						var/turf/target = pick(turfs)
						visible_message("<span class='danger'>[src]'s [W] goes off during the struggle!</span>")
						return W.afterattack(target,src)

			if(last_push_time + 30 > world.time)
				visible_message("<span class='warning'>[L] has weakly pushed [src]!</span>")
				return

			var/randn = rand(1, 100)
			last_push_time = world.time
			if(!(species.species_flags & NO_SLIP) && randn <= 25)
				var/armor_check = run_armor_check(affecting, "melee")
				apply_effect(3, WEAKEN, armor_check)
				playsound(src, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
				if(armor_check < 60)
					if(L.zone_sel.selecting == BP_L_LEG || L.zone_sel.selecting == BP_R_LEG || L.zone_sel.selecting == BP_L_FOOT || L.zone_sel.selecting == BP_R_FOOT)
						visible_message("<span class='danger'>[L] has leg swept [src]!</span>")
					else
						visible_message("<span class='danger'>[L] has pushed [src]!</span>")
				else
					visible_message("<span class='warning'>[L] attempted to push [src]!</span>")
				return

			if(randn <= 60)
				//See about breaking grips or pulls
				if(break_all_grabs(L))
					playsound(src, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
					return

				//Actually disarm them
				drop_held_items()

				visible_message("<span class='danger'>[L] has disarmed [src]!</span>")
				playsound(src, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
				return

			playsound(src, 'sound/weapons/punchmiss.ogg', 25, 1, -1)
			visible_message("<font color='red'> <B>[L] attempted to disarm [src]!</B></font>")
	return

/mob/living/carbon/human/proc/afterattack(atom/target, mob/user, clickchain_flags, list/params)
	return

//can move this to a different .dm if needed
/mob/living/carbon/human/AltClick(mob/user)
	. = ..()
	if(!Adjacent(user) || !user.canClick() || user.incapacitated() || user.stat)
		return
	var/mob/living/carbon/human/H = user
	if (istype(H) && attempt_to_scoop(H))
		return
	//if someone else ever decides altclicking people should do other things, bare in mind it currently continues if the person fails to be scooped

/mob/living/carbon/human/attack_generic(var/mob/user, var/damage, var/attack_message, var/armor_type = "melee", var/armor_pen = 0, var/a_sharp = 0, var/a_edge = 0)

	if(!damage)
		return

	add_attack_logs(user,src,"Melee attacked with fists (miss/block)",admin_notify = FALSE) //No admin notice since this is usually fighting simple animals
	src.visible_message("<span class='danger'>[user] has [attack_message] [src]!</span>")
	user.do_attack_animation(src)

	var/dam_zone = pick(organs_by_name)
	var/obj/item/organ/external/affecting = get_organ(ran_zone(dam_zone))
	var/armor_block = run_armor_check(affecting, armor_type, armor_pen)
	var/armor_soak = get_armor_soak(affecting, armor_type, armor_pen)
	apply_damage(damage, DAMAGE_TYPE_BRUTE, affecting, armor_block, armor_soak, sharp = a_sharp, edge = a_edge)
	update_health()
	return TRUE

//Used to attack a joint through grabbing
/mob/living/carbon/human/proc/grab_joint(var/mob/living/user, var/def_zone)
	if(user.check_grab(src) < GRAB_NECK)
		return

	if(!def_zone) def_zone = user.zone_sel.selecting
	var/target_zone = check_zone(def_zone)
	if(!target_zone)
		return FALSE
	var/obj/item/organ/external/organ = get_organ(check_zone(target_zone))
	if(!organ || organ.dislocated > 0 || organ.dislocated == -1) //don't use is_dislocated() here, that checks parent
		return FALSE

	user.visible_message("<span class='warning'>[user] begins to dislocate [src]'s [organ.joint]!</span>")
	if(do_after(user, 100))
		organ.dislocate(1)
		src.visible_message("<span class='danger'>[src]'s [organ.joint] [pick("gives way","caves in","crumbles","collapses")]!</span>")
		return TRUE
	return FALSE

//Breaks all grips and pulls that the mob currently has.
/mob/living/carbon/human/proc/break_all_grabs(mob/living/carbon/user)
	var/success = FALSE
	if(pulling)
		visible_message("<span class='danger'>[user] has broken [src]'s grip on [pulling]!</span>")
		success = TRUE
		stop_pulling()

	for(var/obj/item/grab/grab as anything in get_held_items_of_type(/obj/item/grab))
		if(grab.affecting)
			visible_message("<span class='danger'>[user] has broken [src]'s grip on [grab.affecting]!</span>")
			success = TRUE
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), grab)
	return success

/*
	We want to ensure that a mob may only apply pressure to one organ of one mob at any given time. Currently this is done mostly implicitly through
	the behaviour of do_after() and the fact that applying pressure to someone else requires a grab:
	If you are applying pressure to yourself and attempt to grab someone else, you'll change what you are holding in your active hand which will stop do_mob()
	If you are applying pressure to another and attempt to apply pressure to yourself, you'll have to switch to an empty hand which will also stop do_mob()
	Changing targeted zones should also stop do_mob(), preventing you from applying pressure to more than one body part at once.
*/
/mob/living/carbon/human/proc/apply_pressure(mob/living/user, var/target_zone)
	var/obj/item/organ/external/organ = get_organ(target_zone)
	if(!organ || !(organ.status & ORGAN_BLEEDING) || (organ.robotic >= ORGAN_ROBOT))
		return FALSE

	if(organ.applied_pressure)
		to_chat(user, "<span class='warning'>Someone is already applying pressure to [user == src? "your [organ.name]" : "[src]'s [organ.name]"].</span>")
		return FALSE

	var/datum/gender/TU = GLOB.gender_datums[user.get_visible_gender()]

	if(user == src)
		user.visible_message("\The [user] starts applying pressure to [TU.his] [organ.name]!", "You start applying pressure to your [organ.name]!")
	else
		user.visible_message("\The [user] starts applying pressure to [src]'s [organ.name]!", "You start applying pressure to [src]'s [organ.name]!")
	spawn(0)
		organ.applied_pressure = user

		//apply pressure as long as they stay still and keep grabbing
		do_mob(user, src, INFINITY, target_zone, progress = 0)

		organ.applied_pressure = null

		if(user == src)
			user.visible_message("\The [user] stops applying pressure to [TU.his] [organ.name]!", "You stop applying pressure to your [organ]!")
		else
			user.visible_message("\The [user] stops applying pressure to [src]'s [organ.name]!", "You stop applying pressure to [src]'s [organ.name]!")

	return TRUE

/mob/living/carbon/human
	var/datum/unarmed_attack/default_attack

/mob/living/carbon/human/verb/check_attacks()
	set name = "Check Attacks"
	set category = VERB_CATEGORY_IC
	set src = usr

	var/dat = "<b><font size = 5>Known Attacks</font></b><br/><br/>"

	for(var/datum/unarmed_attack/u_attack in species.unarmed_attacks)
		dat += "<b>Primarily [u_attack.attack_name] </b><br/><br/><br/>"

	src << browse(HTML_SKELETON(dat), "window=checkattack")
	return

/mob/living/carbon/human/check_attacks()
	var/dat = "<b><font size = 5>Known Attacks</font></b><br/><br/>"

	if(default_attack)
		dat += "Current default attack: [default_attack.attack_name] - <a href='byond://?src=\ref[src];default_attk=reset_attk'>reset</a><br/><br/>"

	for(var/datum/unarmed_attack/u_attack in species.unarmed_attacks)
		if(u_attack == default_attack)
			dat += "<b>Primarily [u_attack.attack_name]</b> - default - <a href='byond://?src=\ref[src];default_attk=reset_attk'>reset</a><br/><br/><br/>"
		else
			dat += "<b>Primarily [u_attack.attack_name]</b> - <a href='byond://?src=\ref[src];default_attk=\ref[u_attack]'>set default</a><br/><br/><br/>"

	src << browse(HTML_SKELETON(dat), "window=checkattack")

/mob/living/carbon/human/Topic(href, href_list)
	if(href_list["default_attk"])
		if(href_list["default_attk"] == "reset_attk")
			set_default_attack(null)
		else
			var/datum/unarmed_attack/u_attack = locate(href_list["default_attk"])
			if(u_attack && (u_attack in species.unarmed_attacks))
				set_default_attack(u_attack)
		check_attacks()
		return 1
	else
		return ..()

/mob/living/carbon/human/proc/set_default_attack(var/datum/unarmed_attack/u_attack)
	default_attack = u_attack

/mob/living/carbon/human/unarmed_attack_style()
	return get_unarmed_attack() || ..()

/datum/unarmed_attack
	var/attack_name = "fist"


/datum/unarmed_attack/bite
	attack_name = "bite"
/datum/unarmed_attack/bite/sharp
	attack_name = "sharp bite"
/datum/unarmed_attack/bite/strong
	attack_name = "strong bite"
/datum/unarmed_attack/punch
	attack_name = "punch"
/datum/unarmed_attack/kick
	attack_name = "kick"
/datum/unarmed_attack/stomp
	attack_name = "stomp"
/datum/unarmed_attack/stomp/weak
	attack_name = "weak stomp"
/datum/unarmed_attack/light_strike
	attack_name = "light hit"
/datum/unarmed_attack/diona
	attack_name = "tendrils"
/datum/unarmed_attack/claws
	attack_name = "claws"
/datum/unarmed_attack/claws/strong
	attack_name = "strong claws"
/datum/unarmed_attack/slime_glomp
	attack_name = "glomp"
/datum/unarmed_attack/bite/sharp/numbing
	attack_name = "numbing bite"
