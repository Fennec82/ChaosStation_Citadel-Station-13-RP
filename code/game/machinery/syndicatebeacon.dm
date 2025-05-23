
//  Beacon randomly spawns in space
//	When a non-traitor (no special role in /mind) uses it, he is given the choice to become a traitor
//	If he accepts there is a random chance he will be accepted, rejected, or rejected and killed
//	Bringing certain items can help improve the chance to become a traitor

/obj/machinery/syndicate_beacon
	name = "ominous beacon"
	desc = "This looks suspicious..."
	icon = 'icons/obj/device.dmi'
	icon_state = "syndbeacon"
	anchored = TRUE
	density = TRUE
	var/temptext = ""
	var/selfdestructing = FALSE
	var/charges = 1

/obj/machinery/syndicate_beacon/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	usr.set_machine(src)
	var/dat = "<font color=#005500><i>Scanning [pick("retina pattern", "voice print", "fingerprints", "dna sequence")]...<br>Identity confirmed,<br></i></font>"
	if(istype(user, /mob/living/carbon/human) || istype(user, /mob/living/silicon/ai))
		if(is_special_character(user))
			dat += "<font color=#07700><i>Operative record found. Greetings, Agent [user.name].</i></font><br>"
		else if(charges < 1)
			dat += "<TT>Connection severed.</TT><BR>"
		else
			var/honorific = "Mr."
			if(user.gender == FEMALE)
				honorific = "Ms."
			dat += "<font color=red><i>Identity not found in operative database. What can the Syndicate do for you today, [honorific] [user.name]?</i></font><br>"
			if(!selfdestructing)
				dat += "<br><br><A href='?src=\ref[src];betraitor=1;traitormob=\ref[user]'>\"[pick("I want to switch teams.", "I want to work for you.", "Let me join you.", "I can be of use to you.", "You want me working for you, and here's why...", "Give me an objective.", "How's the 401k over at the Syndicate?")]\"</A><BR>"
	dat += temptext
	user << browse(HTML_SKELETON(dat), "window=syndbeacon")
	onclose(user, "syndbeacon")

/obj/machinery/syndicate_beacon/Topic(href, href_list)
	if(..())
		return
	if(href_list["betraitor"])
		if(charges < 1)
			updateUsrDialog()
			return
		var/mob/M = locate(href_list["traitormob"])
		if(M.mind.special_role || jobban_isbanned(M, "Syndicate"))
			temptext = "<i>We have no need for you at this time. Have a pleasant day.</i><br>"
			updateUsrDialog()
			return
		charges -= 1
		if(prob(50))
			temptext = "<font color=red><i><b>Double-crosser. You planned to betray us from the start. Allow us to repay the favor in kind.</b></i></font>"
			updateUsrDialog()
			spawn(rand(50,200)) selfdestruct()
			return
		if(istype(M, /mob/living/carbon/human))
			var/mob/living/carbon/human/N = M
			to_chat(N, "<B>You have joined the ranks of the Syndicate and become a traitor to the station!</B>")
			traitors.add_antagonist(N.mind)
			traitors.equip(N)
			message_admins("[N]/([N.ckey]) has accepted a traitor objective from a syndicate beacon.")

	updateUsrDialog()
	return

/obj/machinery/syndicate_beacon/proc/selfdestruct()
	selfdestructing = 1
	spawn() explosion(src.loc, 1, rand(1,3), rand(3,8), 10)

////////////////////////////////////////
//Singularity beacon
////////////////////////////////////////
/obj/machinery/power/singularity_beacon
	name = "ominous beacon"
	desc = "This looks suspicious..."
	icon = 'icons/obj/singularity.dmi'
	icon_state = "beacon"

	anchored = FALSE
	density = TRUE
	layer = MOB_LAYER - 0.1 //so people can't hide it and it's REALLY OBVIOUS

	var/active = FALSE
	var/icontype = "beacon"

/obj/machinery/power/singularity_beacon/proc/Activate(mob/user = null)
	if(surplus() < 1.5)
		if(user)
			to_chat(user, "<span class='notice'>The connected wire doesn't have enough current.</span>")
		return
	for(var/obj/singularity/singulo in GLOB.all_singularities)
		if(singulo.z == z)
			singulo.target = src
	icon_state = "[icontype]1"
	active = 1
	START_MACHINE_PROCESSING(src)
	if(user)
		to_chat(user, "<span class='notice'>You activate the beacon.</span>")

/obj/machinery/power/singularity_beacon/proc/Deactivate(mob/user = null)
	for(var/obj/singularity/singulo in GLOB.all_singularities)
		if(singulo.target == src)
			singulo.target = null
	icon_state = "[icontype]0"
	active = 0
	if(user)
		to_chat(user, "<span class='notice'>You deactivate the beacon.</span>")

/obj/machinery/power/singularity_beacon/attack_ai(mob/user)
	return

/obj/machinery/power/singularity_beacon/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	if(anchored)
		return active ? Deactivate(user) : Activate(user)
	else
		to_chat(user, "<span class='danger'>You need to screw the beacon to the floor first!</span>")
		return

/obj/machinery/power/singularity_beacon/attackby(obj/item/W, mob/user)
	if(W.is_screwdriver())
		if(active)
			to_chat(user, "<span class='danger'>You need to deactivate the beacon first!</span>")
			return

		if(anchored)
			anchored = 0
			to_chat(user, "<span class='notice'>You unscrew the beacon from the floor.</span>")
			playsound(src, W.tool_sound, 50, 1)
			disconnect_from_network()
			return
		else
			if(!connect_to_network())
				to_chat(user, "This device must be placed over an exposed cable.")
				return
			anchored = 1
			to_chat(user, "<span class='notice'>You screw the beacon to the floor and attach the cable.</span>")
			playsound(src, W.tool_sound, 50, 1)
			return
	..()
	return

/obj/machinery/power/singularity_beacon/Destroy()
	if(active)
		Deactivate()
	..()

//stealth direct power usage
/obj/machinery/power/singularity_beacon/process(delta_time)
	if(!active)
		return PROCESS_KILL
	else
		// 1.5 kw
		if(draw_power(1.5) < 1.5)
			Deactivate()

/obj/machinery/power/singularity_beacon/syndicate
	icontype = "beaconsynd"
	icon_state = "beaconsynd0"

//! ## VR FILE MERGE ## !//
//  Virgo modified syndie beacon, does not give objectives

/obj/machinery/syndicate_beacon/virgo/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	usr.set_machine(src)
	var/dat = "<font color=#005500><i>Scanning [pick("retina pattern", "voice print", "fingerprints", "dna sequence")]...<br>Identity confirmed,<br></i></font>"
	if(istype(user, /mob/living/carbon/human) || istype(user, /mob/living/silicon/ai))
		if(is_special_character(user))
			dat += "<font color=#07700><i>Operative record found. Greetings, Agent [user.name].</i></font><br>"
		else if(charges < 1)
			dat += "<TT>Connection severed.</TT><BR>"
		else
			var/honorific = "Mr."
			if(user.gender == FEMALE)
				honorific = "Ms."
			dat += "<font color=red><i>Identity not found in operative database. What can the Black Market do for you today, [honorific] [user.name]?</i></font><br>"
			if(!selfdestructing)
				dat += "<br><br><A href='?src=\ref[src];betraitor=1;traitormob=\ref[user]'>\"[pick("Send me some supplies!", "Transfer supplies.")]\"</A><BR>"
	dat += temptext
	user << browse(HTML_SKELETON(dat), "window=syndbeacon")
	onclose(user, "syndbeacon")

/obj/machinery/syndicate_beacon/virgo/Topic(href, href_list)
	if(href_list["betraitor"])
		if(charges < 1)
			updateUsrDialog()
			return
		var/mob/M = locate(href_list["traitormob"])
		if(M.mind.special_role || jobban_isbanned(M, "Syndicate"))
			temptext = "<i>We have no need for you at this time. Have a pleasant day.</i><br>"
			updateUsrDialog()
			return
		charges -= 1
		if(istype(M, /mob/living/carbon/human))
			var/mob/living/carbon/human/N = M
			to_chat(N, "<B>Access granted, here are the supplies!</B>")
			traitors.equip(N)
			message_admins("[N]/([N.ckey]) has recieved an uplink and telecrystals from the syndicate beacon.")

	updateUsrDialog()
	return
