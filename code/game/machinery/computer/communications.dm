
// The communications computer
/obj/machinery/computer/communications
	name = "command and communications console"
	desc = "Used to command and control the station. Can relay long-range communications."
	icon_keyboard = "tech_key"
	icon_screen = "comm"
	light_color = "#0099ff"
	req_access = list(ACCESS_COMMAND_BRIDGE)
	circuit = /obj/item/circuitboard/communications
	var/prints_intercept = 1
	var/authenticated = 0
	var/list/messagetitle = list()
	var/list/messagetext = list()
	var/currmsg = 0
	var/aicurrmsg = 0
	var/state = STATE_DEFAULT
	var/aistate = STATE_DEFAULT
	var/message_cooldown = 0
	var/centcom_message_cooldown = 0
	var/tmp_alertlevel = 0
	var/const/STATE_DEFAULT = 1
	var/const/STATE_CALLSHUTTLE = 2
	var/const/STATE_CANCELSHUTTLE = 3
	var/const/STATE_MESSAGELIST = 4
	var/const/STATE_VIEWMESSAGE = 5
	var/const/STATE_DELMESSAGE = 6
	var/const/STATE_STATUSDISPLAY = 7
	var/const/STATE_ALERT_LEVEL = 8
	var/const/STATE_CONFIRM_LEVEL = 9
	var/const/STATE_CREWTRANSFER = 10
	var/const/STATE_NIGHTSHIFT = 11

	var/status_display_freq = "1435"
	var/stat_msg1
	var/stat_msg2

	var/datum/controller/subsystem/legacy_atc/ATC
	var/datum/legacy_announcement/priority/crew_announcement = new

/obj/machinery/computer/communications/Initialize(mapload)
	. = ..()
	ATC = SSlegacy_atc
	crew_announcement.newscast = 1

/obj/machinery/computer/communications/process(delta_time)
	if(..())
		if(state != STATE_STATUSDISPLAY)
			src.updateDialog()


/obj/machinery/computer/communications/Topic(href, href_list)
	if(..())
		return 1
	if ((LEGACY_MAP_DATUM) && !(src.z in (LEGACY_MAP_DATUM).contact_levels))
		to_chat(usr, "<font color='red'><b>Unable to establish a connection:</b></font> <font color='black'>You're too far away from the station!</font>")
		return
	usr.set_machine(src)

	if(!href_list["operation"])
		return
	switch(href_list["operation"])
		// main interface
		if("main")
			src.state = STATE_DEFAULT
		if("login")
			var/mob/M = usr
			var/obj/item/card/id/I = M.get_active_held_item()
			if (istype(I, /obj/item/pda))
				var/obj/item/pda/pda = I
				I = pda.id
			if (I && istype(I))
				if(src.check_access(I))
					authenticated = 1
				if(ACCESS_COMMAND_CAPTAIN in I.access)
					authenticated = 2
					crew_announcement.announcer = GetNameAndAssignmentFromId(I)
		if("logout")
			authenticated = 0
			crew_announcement.announcer = ""

		if("swipeidseclevel")
			if(src.authenticated) //Let heads change the alert level.
				var/old_level = GLOB.security_level
				if(!tmp_alertlevel) tmp_alertlevel = SEC_LEVEL_GREEN
				if(tmp_alertlevel < SEC_LEVEL_GREEN) tmp_alertlevel = SEC_LEVEL_GREEN
				if(tmp_alertlevel > SEC_LEVEL_RED) tmp_alertlevel = SEC_LEVEL_BLUE //Cannot engage delta with this
				set_security_level(tmp_alertlevel)
				if(GLOB.security_level != old_level)
					//Only notify the admins if an actual change happened
					log_game("[key_name(usr)] has changed the security level to [get_security_level()].")
					message_admins("[key_name_admin(usr)] has changed the security level to [get_security_level()].")
					switch(GLOB.security_level)
						if(SEC_LEVEL_GREEN)
							feedback_inc("alert_comms_green",1)
						if(SEC_LEVEL_BLUE)
							feedback_inc("alert_comms_blue",1)
						if(SEC_LEVEL_YELLOW)
							feedback_inc("alert_comms_yellow",1)
						if(SEC_LEVEL_VIOLET)
							feedback_inc("alert_comms_violet",1)
						if(SEC_LEVEL_ORANGE)
							feedback_inc("alert_comms_orange",1)
				tmp_alertlevel = 0
				state = STATE_DEFAULT

		if("announce")
			if(src.authenticated>=1)
				if(message_cooldown)
					to_chat(usr, "Please allow at least one minute to pass between announcements")
					return
				var/input = input(usr, "Please write a message to announce to the station crew.", "Priority Announcement")
				if(!input || !(usr in view(1,src)))
					return
				crew_announcement.Announce(input)
				message_cooldown = 1
				spawn(600)//One minute cooldown
					message_cooldown = 0

		if("callshuttle")
			src.state = STATE_DEFAULT
			if(src.authenticated)
				src.state = STATE_CALLSHUTTLE
		if("callshuttle2")
			if(src.authenticated)
				call_shuttle_proc(usr)
				if(SSemergencyshuttle.online())
					post_status("shuttle")
			src.state = STATE_DEFAULT
		if("cancelshuttle")
			src.state = STATE_DEFAULT
			if(src.authenticated)
				src.state = STATE_CANCELSHUTTLE
		if("cancelshuttle2")
			if(src.authenticated)
				cancel_call_proc(usr)
			src.state = STATE_DEFAULT
		if("messagelist")
			src.currmsg = 0
			src.state = STATE_MESSAGELIST
		if("toggleatc")
			src.ATC.toggle_broadcast()
		if("viewmessage")
			src.state = STATE_VIEWMESSAGE
			if (!src.currmsg)
				if(href_list["message-num"])
					src.currmsg = text2num(href_list["message-num"])
				else
					src.state = STATE_MESSAGELIST
		if("delmessage")
			src.state = (src.currmsg) ? STATE_DELMESSAGE : STATE_MESSAGELIST
		if("delmessage2")
			if(src.authenticated)
				if(src.currmsg)
					var/title = src.messagetitle[src.currmsg]
					var/text  = src.messagetext[src.currmsg]
					src.messagetitle.Remove(title)
					src.messagetext.Remove(text)
					if(src.currmsg == src.aicurrmsg)
						src.aicurrmsg = 0
					src.currmsg = 0
				src.state = STATE_MESSAGELIST
			else
				src.state = STATE_VIEWMESSAGE
		if("status")
			src.state = STATE_STATUSDISPLAY

		if("nightshift")
			src.state = STATE_NIGHTSHIFT

		// Status display stuff
		if("setstat")
			switch(href_list["statdisp"])
				if("message")
					post_status("message", stat_msg1, stat_msg2)
				if("alert")
					post_status("alert", href_list["alert"])
				else
					post_status(href_list["statdisp"])

		if("setmsg1")
			stat_msg1 = reject_bad_text(sanitize(input("Line 1", "Enter Message Text", stat_msg1) as text|null, 40), 40)
			src.updateDialog()
		if("setmsg2")
			stat_msg2 = reject_bad_text(sanitize(input("Line 2", "Enter Message Text", stat_msg2) as text|null, 40), 40)
			src.updateDialog()

		// OMG CENTCOM LETTERHEAD
		if("MessageCentCom")
			if(src.authenticated==2)
				if(centcom_message_cooldown)
					to_chat(usr, "<font color='red'>Arrays recycling.  Please stand by.</font>")
					return
				var/input = sanitize(input("Please choose a message to transmit to [(LEGACY_MAP_DATUM).boss_short] via quantum entanglement.  Please be aware that this process is very expensive, and abuse will lead to... termination.  Transmission does not guarantee a response. There is a 30 second delay before you may send another message, be clear, full and concise.", "To abort, send an empty message.", ""))
				if(!input || !(usr in view(1,src)))
					return
				message_centcom(input, usr)
				to_chat(usr, "<font color=#4F49AF>Message transmitted.</font>")
				log_game("[key_name(usr)] has made an IA [(LEGACY_MAP_DATUM).boss_short] announcement: [input]")
				centcom_message_cooldown = 1
				spawn(300)//10 minute cooldown
					centcom_message_cooldown = 0


		// OMG SYNDICATE ...LETTERHEAD
		if("MessageSyndicate")
			if((src.authenticated==2) && (src.emagged))
				if(centcom_message_cooldown)
					to_chat(usr, "<font color='red'>Arrays recycling.  Please stand by.</font>")
					return
				var/input = sanitize(input(usr, "Please choose a message to transmit to \[ABNORMAL ROUTING CORDINATES\] via quantum entanglement.  Please be aware that this process is very expensive, and abuse will lead to... termination. Transmission does not guarantee a response. There is a 30 second delay before you may send another message, be clear, full and concise.", "To abort, send an empty message.", ""))
				if(!input || !(usr in view(1,src)))
					return
				message_syndicate(input, usr)
				to_chat(usr, "<font color=#4F49AF>Message transmitted.</font>")
				log_game("[key_name(usr)] has made an illegal announcement: [input]")
				centcom_message_cooldown = 1
				spawn(300)//10 minute cooldown
					centcom_message_cooldown = 0

		if("RestoreBackup")
			to_chat(usr, "Backup routing data restored!")
			src.emagged = 0
			src.updateDialog()



		// AI interface
		if("ai-main")
			src.aicurrmsg = 0
			src.aistate = STATE_DEFAULT
		if("ai-callshuttle")
			src.aistate = STATE_CALLSHUTTLE
		if("ai-callshuttle2")
			call_shuttle_proc(usr)
			src.aistate = STATE_DEFAULT
		if("ai-messagelist")
			src.aicurrmsg = 0
			src.aistate = STATE_MESSAGELIST
		if("ai-viewmessage")
			src.aistate = STATE_VIEWMESSAGE
			if (!src.aicurrmsg)
				if(href_list["message-num"])
					src.aicurrmsg = text2num(href_list["message-num"])
				else
					src.aistate = STATE_MESSAGELIST
		if("ai-delmessage")
			src.aistate = (src.aicurrmsg) ? STATE_DELMESSAGE : STATE_MESSAGELIST
		if("ai-delmessage2")
			if(src.aicurrmsg)
				var/title = src.messagetitle[src.aicurrmsg]
				var/text  = src.messagetext[src.aicurrmsg]
				src.messagetitle.Remove(title)
				src.messagetext.Remove(text)
				if(src.currmsg == src.aicurrmsg)
					src.currmsg = 0
				src.aicurrmsg = 0
			src.aistate = STATE_MESSAGELIST
		if("ai-status")
			src.aistate = STATE_STATUSDISPLAY
		if("ai-nightshift")
			src.aistate = STATE_NIGHTSHIFT

		if("securitylevel")
			src.tmp_alertlevel = text2num( href_list["newalertlevel"] )
			if(!tmp_alertlevel) tmp_alertlevel = 0
			state = STATE_CONFIRM_LEVEL

		if("changeseclevel")
			state = STATE_ALERT_LEVEL

		if("setnightshift")
			var/oldactive = SSnightshift.nightshift_active
			var/newactive
			switch(href_list["newsetting"])
				if("auto")
					SSnightshift.overridden = FALSE
					newactive = oldactive
				if("on")
					SSnightshift.overridden = TRUE
					newactive = TRUE
				if("off")
					SSnightshift.overridden = TRUE
					newactive = FALSE
			if(oldactive != newactive)
				SSnightshift.update_nightshift(newactive)
			src.state = STATE_DEFAULT
	src.updateUsrDialog()

/obj/machinery/computer/communications/emag_act(var/remaining_charges, var/mob/user)
	if(!emagged)
		src.emagged = 1
		to_chat(user, "You scramble the communication routing circuits!")
		return 1

/obj/machinery/computer/communications/attack_ai(var/mob/user as mob)
	return src.attack_hand(user)

/obj/machinery/computer/communications/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	if(..())
		return
	if ((LEGACY_MAP_DATUM) && !(src.z in (LEGACY_MAP_DATUM).contact_levels))
		to_chat(user, "<font color='red'><b>Unable to establish a connection:</b></font> <font color='black'>You're too far away from the station!</font>")
		return

	user.set_machine(src)
	var/dat = "<head><title>Communications Console</title></head><body>"
	if (SSemergencyshuttle.has_eta())
		var/timeleft = SSemergencyshuttle.estimate_arrival_time()
		dat += "<B>Emergency shuttle</B>\n<BR>\nETA: [timeleft / 60 % 60]:[add_zero(num2text(timeleft % 60), 2)]<BR>"

	if (istype(user, /mob/living/silicon))
		var/dat2 = src.interact_ai(user) // give the AI a different interact proc to limit its access
		if(dat2)
			dat +=  dat2
			user << browse(dat, "window=communications;size=400x500")
			onclose(user, "communications")
		return

	switch(src.state)
		if(STATE_DEFAULT)
			if (src.authenticated)
				dat += "<BR>\[ <A HREF='?src=\ref[src];operation=logout'>Log Out</A> \]"
				if (src.authenticated>=1)
					dat += "<BR>\[ <A HREF='?src=\ref[src];operation=announce'>Make An Announcement</A> \]"
				if (src.authenticated==2)
					if(src.emagged == 0)
						dat += "<BR>\[ <A HREF='?src=\ref[src];operation=MessageCentCom'>Send an emergency message to [(LEGACY_MAP_DATUM).boss_short]</A> \]"
					else
						dat += "<BR>\[ <A HREF='?src=\ref[src];operation=MessageSyndicate'>Send an emergency message to \[UNKNOWN\]</A> \]"
						dat += "<BR>\[ <A HREF='?src=\ref[src];operation=RestoreBackup'>Restore Backup Routing Data</A> \]"

				dat += "<BR>\[ <A HREF='?src=\ref[src];operation=changeseclevel'>Change alert level</A> \]"
				if(SSemergencyshuttle.location())
					if (SSemergencyshuttle.online())
						dat += "<BR>\[ <A HREF='?src=\ref[src];operation=cancelshuttle'>Cancel Shuttle Call</A> \]"
					else
						dat += "<BR>\[ <A HREF='?src=\ref[src];operation=callshuttle'>Call Emergency Shuttle</A> \]"

				dat += "<BR>\[ <A HREF='?src=\ref[src];operation=status'>Set Status Display</A> \]"
				dat += "<BR>\[ <A HREF='?src=\ref[src];operation=nightshift'>Set Nightshift Setting</A> \]"
			else
				dat += "<BR>\[ <A HREF='?src=\ref[src];operation=login'>Log In</A> \]"
			dat += "<BR>\[ <A HREF='?src=\ref[src];operation=messagelist'>Message List</A> \]"
			dat += "<BR>\[ <A HREF='?src=\ref[src];operation=toggleatc'>[ATC.squelched ? "Enable" : "Disable"] ATC Relay</A> \]"
		if(STATE_CALLSHUTTLE)
			dat += "Are you sure you want to call the shuttle? \[ <A HREF='?src=\ref[src];operation=callshuttle2'>OK</A> | <A HREF='?src=\ref[src];operation=main'>Cancel</A> \]"
		if(STATE_CANCELSHUTTLE)
			dat += "Are you sure you want to cancel the shuttle? \[ <A HREF='?src=\ref[src];operation=cancelshuttle2'>OK</A> | <A HREF='?src=\ref[src];operation=main'>Cancel</A> \]"
		if(STATE_MESSAGELIST)
			dat += "Messages:"
			for(var/i = 1; i<=src.messagetitle.len; i++)
				dat += "<BR><A HREF='?src=\ref[src];operation=viewmessage;message-num=[i]'>[src.messagetitle[i]]</A>"
		if(STATE_VIEWMESSAGE)
			if (src.currmsg)
				dat += "<B>[src.messagetitle[src.currmsg]]</B><BR><BR>[src.messagetext[src.currmsg]]"
				if (src.authenticated)
					dat += "<BR><BR>\[ <A HREF='?src=\ref[src];operation=delmessage'>Delete \]"
			else
				src.state = STATE_MESSAGELIST
				src.attack_hand(user)
				return
		if(STATE_DELMESSAGE)
			if (src.currmsg)
				dat += "Are you sure you want to delete this message? \[ <A HREF='?src=\ref[src];operation=delmessage2'>OK</A> | <A HREF='?src=\ref[src];operation=viewmessage'>Cancel</A> \]"
			else
				src.state = STATE_MESSAGELIST
				src.attack_hand(user)
				return
		if(STATE_STATUSDISPLAY)
			dat += "Set Status Displays<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=blank'>Clear</A> \]<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=time'>Station Time</A> \]<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=shuttle'>Shuttle ETA</A> \]<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=message'>Message</A> \]"
			dat += "<ul><li> Line 1: <A HREF='?src=\ref[src];operation=setmsg1'>[ stat_msg1 ? stat_msg1 : "(none)"]</A>"
			dat += "<li> Line 2: <A HREF='?src=\ref[src];operation=setmsg2'>[ stat_msg2 ? stat_msg2 : "(none)"]</A></ul><br>"
			dat += "\[ Alert: <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=default'>None</A> |"
			dat += " <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=redalert'>Red Alert</A> |"
			dat += " <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=lockdown'>Lockdown</A> |"
			dat += " <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=biohazard'>Biohazard</A> \]<BR><HR>"
		if(STATE_NIGHTSHIFT)
			if(!SSnightshift.overridden)
				dat += "Current Nightshift Setting: <b>Auto ([SSnightshift.nightshift_active ? "On" : "Off"])</b><BR>"
				dat += "\[ <A HREF='?src=\ref[src];operation=setnightshift;newsetting=off'>Off</A> \]<BR>"
				dat += "Auto<BR>"
				dat += "\[ <A HREF='?src=\ref[src];operation=setnightshift;newsetting=on'>On</A> \]<BR>"
			else if(SSnightshift.nightshift_active)
				dat += "Current Nightshift Setting: <b>On</b><BR>"
				dat += "\[ <A HREF='?src=\ref[src];operation=setnightshift;newsetting=off'>Off</A> \]<BR>"
				dat += "\[ <A HREF='?src=\ref[src];operation=setnightshift;newsetting=auto'>Auto</A> \]<BR>"
				dat += "On<BR>"
			else
				dat += "Current Nightshift Setting: <b>Off</b><BR>"
				dat += "Off<BR>"
				dat += "\[ <A HREF='?src=\ref[src];operation=setnightshift;newsetting=auto'>Auto</A> \]<BR>"
				dat += "\[ <A HREF='?src=\ref[src];operation=setnightshift;newsetting=on'>On</A> \]<BR>"
		if(STATE_ALERT_LEVEL)
			dat += "Current alert level: [get_security_level()]<BR>"
			if(GLOB.security_level == SEC_LEVEL_DELTA)
				dat += "<font color='red'><b>The ship is in immediate danger of destruction. Find a way to neutralize the threat to lower the alert level or evacuate.</b></font>"
			else
				dat += "<A HREF='?src=\ref[src];operation=securitylevel;newalertlevel=[SEC_LEVEL_ORANGE]'>Orange</A><BR>"
				dat += "<A HREF='?src=\ref[src];operation=securitylevel;newalertlevel=[SEC_LEVEL_VIOLET]'>Violet</A><BR>"
				dat += "<A HREF='?src=\ref[src];operation=securitylevel;newalertlevel=[SEC_LEVEL_YELLOW]'>Yellow</A><BR>"
				dat += "<A HREF='?src=\ref[src];operation=securitylevel;newalertlevel=[SEC_LEVEL_BLUE]'>Blue</A><BR>"
				dat += "<A HREF='?src=\ref[src];operation=securitylevel;newalertlevel=[SEC_LEVEL_GREEN]'>Green</A>"
		if(STATE_CONFIRM_LEVEL)
			dat += "Current alert level: [get_security_level()]<BR>"
			dat += "Confirm the change to: [num2seclevel(tmp_alertlevel)]<BR>"
			dat += "<A HREF='?src=\ref[src];operation=swipeidseclevel'>OK</A> to confirm change.<BR>"

	dat += "<BR>\[ [(src.state != STATE_DEFAULT) ? "<A HREF='?src=\ref[src];operation=main'>Main Menu</A> | " : ""]<A HREF='?src=\ref[user];mach_close=communications'>Close</A> \]"
	dat += "</body>"
	user << browse(dat, "window=communications;size=400x500")
	onclose(user, "communications")




/obj/machinery/computer/communications/proc/interact_ai(var/mob/living/silicon/ai/user as mob)
	var/dat = ""
	switch(src.aistate)
		if(STATE_DEFAULT)
			if(SSemergencyshuttle.location() && !SSemergencyshuttle.online())
				dat += "<BR>\[ <A HREF='?src=\ref[src];operation=ai-callshuttle'>Call Emergency Shuttle</A> \]"
			dat += "<BR>\[ <A HREF='?src=\ref[src];operation=ai-messagelist'>Message List</A> \]"
			dat += "<BR>\[ <A HREF='?src=\ref[src];operation=ai-status'>Set Status Display</A> \]"
			dat += "<BR>\[ <A HREF='?src=\ref[src];operation=toggleatc'>[ATC.squelched ? "Enable" : "Disable"] ATC Relay</A> \]"
			dat += "<BR>\[ <A HREF='?src=\ref[src];operation=ai-nightshift'>Set Nightshift Setting</A> \]"
		if(STATE_CALLSHUTTLE)
			dat += "Are you sure you want to call the shuttle? \[ <A HREF='?src=\ref[src];operation=ai-callshuttle2'>OK</A> | <A HREF='?src=\ref[src];operation=ai-main'>Cancel</A> \]"
		if(STATE_MESSAGELIST)
			dat += "Messages:"
			for(var/i = 1; i<=src.messagetitle.len; i++)
				dat += "<BR><A HREF='?src=\ref[src];operation=ai-viewmessage;message-num=[i]'>[src.messagetitle[i]]</A>"
		if(STATE_VIEWMESSAGE)
			if (src.aicurrmsg)
				dat += "<B>[src.messagetitle[src.aicurrmsg]]</B><BR><BR>[src.messagetext[src.aicurrmsg]]"
				dat += "<BR><BR>\[ <A HREF='?src=\ref[src];operation=ai-delmessage'>Delete</A> \]"
			else
				src.aistate = STATE_MESSAGELIST
				src.attack_hand(user)
				return null
		if(STATE_DELMESSAGE)
			if(src.aicurrmsg)
				dat += "Are you sure you want to delete this message? \[ <A HREF='?src=\ref[src];operation=ai-delmessage2'>OK</A> | <A HREF='?src=\ref[src];operation=ai-viewmessage'>Cancel</A> \]"
			else
				src.aistate = STATE_MESSAGELIST
				src.attack_hand(user)
				return

		if(STATE_STATUSDISPLAY)
			dat += "Set Status Displays<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=blank'>Clear</A> \]<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=time'>Station Time</A> \]<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=shuttle'>Shuttle ETA</A> \]<BR>"
			dat += "\[ <A HREF='?src=\ref[src];operation=setstat;statdisp=message'>Message</A> \]"
			dat += "<ul><li> Line 1: <A HREF='?src=\ref[src];operation=setmsg1'>[ stat_msg1 ? stat_msg1 : "(none)"]</A>"
			dat += "<li> Line 2: <A HREF='?src=\ref[src];operation=setmsg2'>[ stat_msg2 ? stat_msg2 : "(none)"]</A></ul><br>"
			dat += "\[ Alert: <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=default'>None</A> |"
			dat += " <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=redalert'>Red Alert</A> |"
			dat += " <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=lockdown'>Lockdown</A> |"
			dat += " <A HREF='?src=\ref[src];operation=setstat;statdisp=alert;alert=biohazard'>Biohazard</A> \]<BR><HR>"


	dat += "<BR>\[ [(src.aistate != STATE_DEFAULT) ? "<A HREF='?src=\ref[src];operation=ai-main'>Main Menu</A> | " : ""]<A HREF='?src=\ref[user];mach_close=communications'>Close</A> \]"
	return dat

/proc/enable_prison_shuttle(var/mob/user)
	for(var/obj/machinery/computer/prison_shuttle/PS in GLOB.machines)
		PS.allowedtocall = !(PS.allowedtocall)

/proc/call_shuttle_proc(var/mob/user)
	if ((!( SSticker ) || !SSemergencyshuttle.location()))
		return

	if(deathsquad.deployed)
		to_chat(user, "[(LEGACY_MAP_DATUM).boss_short] will not allow the shuttle to be called. Consider all contracts terminated.")
		return

	if(SSemergencyshuttle.deny_shuttle)
		to_chat(user, "The emergency shuttle may not be sent at this time. Please try again later.")
		return

	if(world.time < 6000) // Ten minute grace period to let the game get going without lolmetagaming. -- TLE
		to_chat(user, "The emergency shuttle is refueling. Please wait another [round((6000-world.time)/600)] minute\s before trying again.")
		return

	if(SSemergencyshuttle.going_to_centcom())
		to_chat(user, "The emergency shuttle may not be called while returning to [(LEGACY_MAP_DATUM).boss_short].")
		return

	if(SSemergencyshuttle.online())
		to_chat(user, "The emergency shuttle is already on its way.")
		return

	if(SSticker.mode.name == "blob")
		to_chat(user, "Under directive 7-10, [station_name()] is quarantined until further notice.")
		return

	SSemergencyshuttle.call_evac()
	log_game("[key_name(user)] has called the shuttle.")
	message_admins("[key_name_admin(user)] has called the shuttle.", 1)
	admin_chat_message(message = "Emergency evac beginning! Called by [key_name(user)]!", color = "#CC2222")


	return

/proc/init_shift_change(var/mob/user, var/force = 0)
	if ((!( SSticker ) || !SSemergencyshuttle.location()))
		return

	if(SSemergencyshuttle.going_to_centcom())
		to_chat(user, "The shuttle may not be called while returning to [(LEGACY_MAP_DATUM).boss_short].")
		return

	if(SSemergencyshuttle.online())
		to_chat(user, "The shuttle is already on its way.")
		return

	// if force is 0, some things may stop the shuttle call
	if(!force)
		if(SSemergencyshuttle.deny_shuttle)
			to_chat(user, "[(LEGACY_MAP_DATUM).boss_short] does not currently have a shuttle available in your sector. Please try again later.")
			return

		if(deathsquad.deployed == 1)
			to_chat(user, "[(LEGACY_MAP_DATUM).boss_short] will not allow the shuttle to be called. Consider all contracts terminated.")
			return

		if(world.time < 54000) // 30 minute grace period to let the game get going
			to_chat(user, "The shuttle is refueling. Please wait another [round((54000-world.time)/60)] minutes before trying again.")
			return

		if(SSticker.mode.auto_recall_shuttle)
			//New version pretends to call the shuttle but cause the shuttle to return after a random duration.
			SSemergencyshuttle.auto_recall = 1

		if(SSticker.mode.name == "blob" || SSticker.mode.name == "epidemic")
			to_chat(user, "Under directive 7-10, [station_name()] is quarantined until further notice.")
			return

	SSemergencyshuttle.call_transfer()

	//delay events in case of an autotransfer
	if (isnull(user))
		SSevents.delay_events(EVENT_LEVEL_MODERATE, 9000) //15 minutes
		SSevents.delay_events(EVENT_LEVEL_MAJOR, 9000)

	log_game("[user? key_name(user) : "Autotransfer"] has called the shuttle.")
	message_admins("[user? key_name_admin(user) : "Autotransfer"] has called the shuttle.", 1)
	admin_chat_message(message = "Autotransfer shuttle dispatched, shift ending soon.", color = "#2277BB")

	return

/proc/cancel_call_proc(var/mob/user)
	if (!( SSticker ) || !SSemergencyshuttle.can_recall())
		return
	if((SSticker.mode.name == "blob")||(SSticker.mode.name == "Meteor"))
		return

	if(!SSemergencyshuttle.going_to_centcom()) //check that shuttle isn't already heading to CentCom
		SSemergencyshuttle.recall()
		log_game("[key_name(user)] has recalled the shuttle.")
		message_admins("[key_name_admin(user)] has recalled the shuttle.", 1)
	return


/proc/is_relay_online()
	for(var/obj/machinery/telecomms/relay/M in world)
		if(M.machine_stat == 0)
			return TRUE
	return FALSE

/obj/machinery/computer/communications/proc/post_status(command, data1, data2)

	var/datum/radio_frequency/frequency = radio_controller.return_frequency(FREQ_STATUS_DISPLAYS)

	if(!frequency) return

	var/datum/signal/status_signal = new
	status_signal.source = src
	status_signal.transmission_method = 1
	status_signal.data["command"] = command

	switch(command)
		if("message")
			status_signal.data["msg1"] = data1
			status_signal.data["msg2"] = data2
			log_admin("STATUS: [src.fingerprintslast] set status screen message with [src]: [data1] [data2]")
			//message_admins("STATUS: [user] set status screen with [PDA]. Message: [data1] [data2]")
		if("alert")
			status_signal.data["picture_state"] = data1

	frequency.post_signal(src, status_signal)

//TODO: Convert to proper cooldowns. A bool for cooldowns is insanely dumb.
/// Override the cooldown for special actions
/// Used in places such as CentCom messaging back so that the crew can answer right away
/obj/machinery/computer/communications/proc/override_cooldown()
	// COOLDOWN_RESET(src, important_action_cooldown)
	centcom_message_cooldown = 0
	message_cooldown = 0
