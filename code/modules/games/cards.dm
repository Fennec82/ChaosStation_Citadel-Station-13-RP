/datum/playingcard
	var/name = "playing card"
	var/card_icon = "card_back"
	var/back_icon = "card_back"

/obj/item/deck
	w_class = WEIGHT_CLASS_SMALL
	icon = 'icons/obj/playing_cards.dmi'
	var/list/cards = list()
	var/cooldown = 0 // to prevent spam shuffle

/obj/item/deck/holder
	name = "card box"
	desc = "A small leather case to show how classy you are compared to everyone else."
	icon_state = "card_holder"

/obj/item/deck/cards
	name = "deck of cards"
	desc = "A simple deck of playing cards."
	icon_state = "deck"
	drop_sound = 'sound/items/drop/paper.ogg'
	pickup_sound = 'sound/items/pickup/paper.ogg'


/obj/item/deck/cards/Initialize(mapload)
	. = ..()
	var/datum/playingcard/P
	for(var/suit in list("spades","clubs","diamonds","hearts"))

		var/colour
		if(suit == "spades" || suit == "clubs")
			colour = "black_"
		else
			colour = "red_"

		for(var/number in list("ace","two","three","four","five","six","seven","eight","nine","ten"))
			P = new()
			P.name = "[number] of [suit]"
			P.card_icon = "[colour]num"
			P.back_icon = "card_back"
			cards += P

		for(var/number in list("jack","queen","king"))
			P = new()
			P.name = "[number] of [suit]"
			P.card_icon = "[colour]col"
			P.back_icon = "card_back"
			cards += P

	for(var/i = 0, i<2, i++)
		P = new()
		P.name = "joker"
		P.card_icon = "joker"
		cards += P

/obj/item/deck/attackby(obj/O as obj, mob/user as mob)
	if(istype(O,/obj/item/hand))
		var/obj/item/hand/H = O
		if(H.parentdeck == src)
			for(var/datum/playingcard/P in H.cards)
				cards += P
			qdel(H)
			to_chat(user,"<span class='notice'>You place your cards on the bottom of \the [src]</span>.")
			return
		else
			to_chat(user,"<span class='warning'>You can't mix cards from other decks!</span>")
			return
	..()

/obj/item/deck/attack_hand(mob/user, datum/event_args/actor/clickchain/e_args)
	var/mob/living/carbon/human/H = user
	if(istype(src.loc, /obj/item/storage) || src == H.r_store || src == H.l_store || src.loc == user) // so objects can be removed from storage containers or pockets. also added a catch-all, so if it's in the mob you'll pick it up.
		..()
	else // but if they're not, or are in your hands, you can still draw cards.
		draw_card()

/obj/item/deck/verb/draw_card()

	set category = VERB_CATEGORY_OBJECT
	set name = "Draw"
	set desc = "Draw a card from a deck."
	set src in view(1)

	var/mob/living/carbon/user = usr

	if(usr.stat || !Adjacent(usr)) return

	if(user.are_usable_hands_full()) // Safety check lest the card disappear into oblivion
		to_chat(user,"<span class='notice'>Your hands are full!</span>")
		return

	if(!istype(usr,/mob/living/carbon))
		return

	if(!cards.len)
		to_chat(user,"<span class='notice'>There are no cards in the deck.</span>")
		return

	var/obj/item/hand/H = user.get_held_item_of_type(/obj/item/hand)
	if(H && !(H.parentdeck == src))
		to_chat(user,"<span class='warning'>You can't mix cards from different decks!</span>")
		return

	if(!H)
		H = new(get_turf(src))
		user.put_in_hands(H)

	if(!H || !user)
		return

	var/datum/playingcard/P = cards[1]
	H.cards += P
	cards -= P
	H.parentdeck = src
	H.update_icon()
	user.visible_message("<span class='notice'>\The [user] draws a card.</span>")
	to_chat(user,"<span class='notice'>It's the [P].</span>")

/obj/item/deck/verb/deal_card()

	set category = VERB_CATEGORY_OBJECT
	set name = "Deal"
	set desc = "Deal a card from a deck."
	set src in view(1)

	if(usr.stat || !Adjacent(usr)) return

	if(!cards.len)
		to_chat(usr,"<span class='notice'>There are no cards in the deck.</span>")
		return

	var/list/players = list()
	for(var/mob/living/player in viewers(3))
		if(!player.stat)
			players += player
	//players -= usr

	var/mob/living/M = input("Who do you wish to deal a card?") as null|anything in players
	if(!usr || !src || !M) return

	deal_at(usr, M, 1)

/obj/item/deck/verb/deal_card_multi()

	set category = VERB_CATEGORY_OBJECT
	set name = "Deal Multiple Cards"
	set desc = "Deal multiple cards from a deck."
	set src in view(1)

	if(usr.stat || !Adjacent(usr)) return

	if(!cards.len)
		to_chat(usr,"<span class='notice'>There are no cards in the deck.</span>")
		return

	var/list/players = list()
	for(var/mob/living/player in viewers(3))
		if(!player.stat)
			players += player
	//players -= usr
	var/maxcards = max(min(cards.len,10),1)
	var/dcard = input("How many card(s) do you wish to deal? You may deal up to [maxcards] cards.") as num
	if(dcard > maxcards)
		return
	var/mob/living/M = input("Who do you wish to deal [dcard] card(s)?") as null|anything in players
	if(!usr || !src || !M) return

	deal_at(usr, M, dcard)

/obj/item/deck/proc/deal_at(mob/user, mob/target, dcard) // Take in the no. of card to be dealt
	var/obj/item/hand/H = new(get_step(user, user.dir))
	var/i
	for(i = 0, i < dcard, i++)
		H.cards += cards[1]
		cards -= cards[1]
		H.parentdeck = src
		H.concealed = 1
		H.update_icon()
	if(user==target)
		var/datum/gender/TU = GLOB.gender_datums[user.get_visible_gender()]
		user.visible_message("<span class = 'notice'>\The [user] deals [dcard] card(s) to [TU.himself].</span>")
	else
		user.visible_message("<span class = 'notice'>\The [user] deals [dcard] card(s) to \the [target].</span>")
	H.throw_at_old(get_step(target,target.dir),10,1,H)


/obj/item/hand/attackby(obj/O as obj, mob/user as mob)
	if(cards.len == 1 && istype(O, /obj/item/pen))
		var/datum/playingcard/P = cards[1]
		if(P.name != "Blank Card")
			to_chat(user,"<span class = 'notice'>You cannot write on that card.</span>")
			return
		var/cardtext = sanitize(input(user, "What do you wish to write on the card?", "Card Editing") as text|null, MAX_PAPER_MESSAGE_LEN)
		if(!cardtext)
			return
		P.name = cardtext
		// SNOWFLAKE FOR CAG, REMOVE IF OTHER CARDS ARE ADDED THAT USE THIS.
		P.card_icon = "cag_white_card"
		update_icon()
	else if(istype(O,/obj/item/hand))
		var/obj/item/hand/H = O
		if(H.parentdeck == src.parentdeck) // Prevent cardmixing
			for(var/datum/playingcard/P in cards)
				H.cards += P
			H.concealed = src.concealed
			qdel(src)
			H.update_icon()
			return
		else
			to_chat(user,"<span class = 'notice'>You cannot mix cards from other decks!</span>")
			return

	..()

/obj/item/deck/attack_self(mob/user, datum/event_args/actor/actor)
	. = ..()
	if(.)
		return
	shuffle()


/obj/item/deck/verb/verb_shuffle()
	set category = VERB_CATEGORY_OBJECT
	set name = "Shuffle"
	set desc = "Shuffle the cards in the deck."
	set src in view(1)
	shuffle()

/obj/item/deck/proc/shuffle()
	var/mob/living/user = usr
	if (cooldown < world.time - 10) // 15 ticks cooldown
		var/list/newcards = list()
		while(cards.len)
			var/datum/playingcard/P = pick(cards)
			newcards += P
			cards -= P
		cards = newcards
		user.visible_message("<span class = 'notice'>\The [user] shuffles [src].</span>")
		playsound(user, 'sound/items/cardshuffle.ogg', 50, 1)
		cooldown = world.time
	else
		return

/obj/item/deck/OnMouseDropLegacy(mob/user as mob) // Code from Paper bin, so you can still pick up the deck
	if((user == usr && (!( usr.restrained() ) && (!( usr.stat ) && (usr.contents.Find(src) || in_range(src, usr))))))
		if(!istype(usr, /mob/living/simple_mob))
			if( !usr.get_active_held_item() )		//if active hand is empty
				if(!user.standard_hand_usability_check(src, user.active_hand, HAND_MANIPULATION_GENERAL))
					return

				to_chat(user,"<span class='notice'>You pick up [src].</span>")
				user.put_in_hands(src)

/obj/item/deck/verb_pickup(mob/user as mob) // Snowflaked so pick up verb work as intended
	if((user == usr && (!( usr.restrained() ) && (!( usr.stat ) && (usr.contents.Find(src) || in_range(src, usr))))))
		if(!istype(usr, /mob/living/simple_mob))
			if( !usr.get_active_held_item() )		//if active hand is empty
				if(!user.standard_hand_usability_check(src, user.active_hand, HAND_MANIPULATION_GENERAL))
					return

				to_chat(user,"<span class='notice'>You pick up [src].</span>")
				user.put_in_hands(src)
	return

/obj/item/pack/
	name = "Card Pack"
	desc = "For those with disposible income."

	icon_state = "card_pack"
	icon = 'icons/obj/playing_cards.dmi'
	w_class = WEIGHT_CLASS_TINY
	var/list/cards = list()
	var/parentdeck = null // This variable is added here so that card pack dependent card can be mixed together by defining a "parentdeck" for them
	drop_sound = 'sound/items/drop/paper.ogg'
	pickup_sound = 'sound/items/pickup/paper.ogg'


/obj/item/pack/attack_self(mob/user, datum/event_args/actor/actor)
	. = ..()
	if(.)
		return
	user.visible_message("<span class ='danger'>[user] rips open \the [src]!</span>")
	var/obj/item/hand/H = new()

	H.cards += cards
	H.parentdeck = src.parentdeck
	cards.Cut()
	qdel(src)
	H.update_icon()
	user.put_in_active_hand(H)

/obj/item/hand
	name = "hand of cards"
	desc = "Some playing cards."
	icon = 'icons/obj/playing_cards.dmi'
	icon_state = "empty"
	drop_sound = 'sound/items/drop/paper.ogg'
	pickup_sound = 'sound/items/pickup/paper.ogg'
	w_class = WEIGHT_CLASS_TINY

	var/concealed = 0
	var/list/cards = list()
	var/parentdeck = null

/obj/item/hand/verb/discard()

	set category = VERB_CATEGORY_OBJECT
	set name = "Discard"
	set desc = "Place (a) card(s) from your hand in front of you."

	var/i
	var/maxcards = min(cards.len,5) // Maximum of 5 cards at once
	var/discards = input("How many cards do you want to discard? You may discard up to [maxcards] card(s)") as num
	if(discards > maxcards)
		return
	for	(i = 0;i < discards;i++)
		var/list/to_discard = list()
		for(var/datum/playingcard/P in cards)
			to_discard[P.name] = P
		var/discarding = input("Which card do you wish to put down?") as null|anything in to_discard

		if(!discarding || !to_discard[discarding] || !usr || !src) return

		var/datum/playingcard/card = to_discard[discarding]
		to_discard.Cut()

		var/obj/item/hand/H = new(src.loc)
		H.cards += card
		cards -= card
		H.concealed = 0
		H.parentdeck = src.parentdeck
		H.update_icon()
		src.update_icon()
		usr.visible_message("<span class = 'notice'>\The [usr] plays \the [discarding].</span>")
		H.loc = get_step(usr,usr.dir)

	if(!cards.len)
		qdel(src)

/obj/item/hand/attack_self(mob/user, datum/event_args/actor/actor)
	. = ..()
	if(.)
		return
	concealed = !concealed
	update_icon()
	user.visible_message("<span class = 'notice'>\The [user] [concealed ? "conceals" : "reveals"] their hand.</span>")

/obj/item/hand/examine(mob/user, dist)
	. = ..()
	if((!concealed) && cards.len)
		. += "It contains: "
		for(var/datum/playingcard/P in cards)
			. += "\The [P.name]."

/obj/item/hand/verb/Removecard()

	set category = VERB_CATEGORY_OBJECT
	set name = "Remove card"
	set desc = "Remove a card from the hand."
	set src in view(1)

	var/mob/living/carbon/user = usr

	if(user.stat || !Adjacent(user)) return

	if(user.are_usable_hands_full()) // Safety check lest the card disappear into oblivion
		to_chat(usr,"<span class='danger'>Your hands are full!</span>")
		return

	var/pickablecards = list()
	for(var/datum/playingcard/P in cards)
		pickablecards[P.name] += P
	var/pickedcard = input("Which card do you want to remove from the hand?")	as null|anything in pickablecards

	if(!pickedcard || !pickablecards[pickedcard] || !usr || !src) return

	var/datum/playingcard/card = pickablecards[pickedcard]

	var/obj/item/hand/H = new(get_turf(src))
	user.put_in_hands(H)
	H.cards += card
	cards -= card
	H.parentdeck = src.parentdeck
	H.concealed = src.concealed
	H.update_icon()
	src.update_icon()

	if(!cards.len)
		qdel(src)
	return

/obj/item/hand/update_icon(direction = 0)
	if(!cards.len)
		return		// about to be deleted
	if(cards.len > 1)
		name = "hand of cards"
		desc = "Some playing cards."
	else
		name = "a playing card"
		desc = "A playing card."

	cut_overlays()


	if(cards.len == 1)
		var/datum/playingcard/P = cards[1]
		var/image/I = new(src.icon, (concealed ? "[P.back_icon]" : "[P.card_icon]") )
		I.pixel_x += (-5+rand(10))
		I.pixel_y += (-5+rand(10))
		add_overlay(I)
		return

	var/offset = FLOOR(20/cards.len, 1)

	var/matrix/M = matrix()
	if(direction)
		switch(direction)
			if(NORTH)
				M.Translate( 0,  0)
			if(SOUTH)
				M.Translate( 0,  4)
			if(WEST)
				M.Turn(90)
				M.Translate( 3,  0)
			if(EAST)
				M.Turn(90)
				M.Translate(-2,  0)
	var/i = 0
	for(var/datum/playingcard/P in cards)
		var/image/I = new(src.icon, (concealed ? "[P.back_icon]" : "[P.card_icon]") )
		//I.pixel_x = origin+(offset*i)
		switch(direction)
			if(SOUTH)
				I.pixel_x = 8-(offset*i)
			if(WEST)
				I.pixel_y = -6+(offset*i)
			if(EAST)
				I.pixel_y = 8-(offset*i)
			else
				I.pixel_x = -7+(offset*i)
		I.transform = M
		add_overlay(I)
		i++

/obj/item/hand/dropped(mob/user, flags, atom/newLoc)
	. = ..()
	if(locate(/obj/structure/table, loc))
		update_icon(user.dir)
	else
		update_icon()

/obj/item/hand/pickup(mob/user, flags, atom/oldLoc)
	. = ..()
	update_icon()
