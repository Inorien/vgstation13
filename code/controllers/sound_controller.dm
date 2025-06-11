/*
	This system is comprised of two parts.

	1. THE SOUND CONTROLLER
		This global object is responsible for keeping track of reservable sound channels, as well as
		handling reservations and frees.
		It is used by SOUND EMITTERs that are playing a repeating sound (i.e. a sound that was created
		with `repeat = 1`).

		It is not necessary to interact with this object from atom code. It is only referenced from
		SOUND EMITTERs internally.

		The SOUND CONTROLLER has the additional responsibility of flushing the channels of any player
		who has been deafened.


	2. THE SOUND EMITTER
	    This datum is responsible for keeping a collection of sounds that a given atom may emit.
		It is also responsible for sending those sounds to clients, which is triggered by the atom.

		For example, for a SMES that hums when its online, configure the sound in initialize():
			if(sound_emitter)
				var/sound/smes_hum = sound()
				smes_hum.file = 'sound/machines/smes_hum.ogg'
				smes_hum.repeat = 1
				smes_hum.volume = 50
				smes_hum.atom = src
				sound_emitter.add(smes_hum, "smes_hum")

		When the SMES is online, call sound_emitter.play("smes_hum"). When the SMES is no longer online,
		call sound_emitter.stop() to halt the sound.
		In this case, as `smes_hum.repeat = 1`, the sound_emitter internally reserves a sound channel from
		the SOUND CONTROLLER for the duration until stop() is called, at which point the channel is freed.

		For one-off, `repeat = 0` sounds - such as an airlock opening - behaviour mimics the legacy playsound(...) behaviour.
		These sounds do not require channel reservation, so there is no need to call stop().

*/

var/global/datum/controller/sounds/sound_controller = new

/datum/controller/sounds
	name = "Sound Controller"
	var/list/reserved_channels = new
	var/list/free_channels = new

    // Sound emitters that currently have a channel reserved
	// This is used to send sounds to clients when they enter or exit sound range,
	//  as well as to update clients that connect after a play() has already been called.
	// It is also used to flush channels for a player when deafened.
	var/list/datum/sound_emitter/sound_emitters_by_channel = new

/datum/controller/sounds/New()
	..()
	reserved_channels = list()
	free_channels = list()
	sound_emitters_by_channel = list()
	for (var/i = CHANNEL_RESERVABLE_MIN, i <= CHANNEL_RESERVABLE_MAX, i++)
		free_channels += i
	world.log << "SoundController initialised with [length(free_channels)] free channels, reservable from [CHANNEL_RESERVABLE_MIN] to [CHANNEL_RESERVABLE_MAX].</span>"

/datum/controller/sounds/proc/reserve_channel(src)
	if (!length(free_channels))
		return -1
	var/channel = free_channels[1]
	free_channels -= channel
	reserved_channels += channel
	world.log << "SoundController reserved channel [channel]. [length(free_channels)] channels remaining.</span>"
	sound_emitters_by_channel += src
	return channel

/datum/controller/sounds/proc/free_channel(var/channel)
	if (!channel || !isnum(channel) || channel < CHANNEL_RESERVABLE_MIN || channel > CHANNEL_RESERVABLE_MAX)
		return
	if (!(channel in reserved_channels))
		return
	reserved_channels -= channel
	free_channels += channel
	sound_emitters_by_channel -= src
	world.log << "SoundController freed channel [channel]. [length(free_channels)] channels remaining.</span>"
	//free_channels.Sort()

/datum/controller/sounds/proc/register_listener(var/mob/player)
	player.register_event(/event/moved, src, nameof(src::on_mob_move()))
	world.log << "SoundEmittersByChannel : [length(sound_emitters_by_channel)]</span>"

/datum/controller/sounds/proc/on_mob_move(mob/mover)
	update(mover)

/datum/controller/sounds/proc/update(var/mob/player)
	// This is called when a player spawns in or enters sound range of a sound emitter.
	// It sends all currently active repeating sounds to that client
	if (!player || !player.client)
		return

	for (var/i=1,i<=sound_emitters_by_channel.len,i++)
		var/datum/sound_emitter/emitter = sound_emitters_by_channel[i]
		if (!emitter || !emitter.current_repeating_sound)
			world.log << "SoundController skipping sound emitter [emitter] for player [player] at index [i] because it has no current repeating sound.</span>"
			continue
		var/a = emitter.current_repeating_sound.atom
		if (!a || !(player in viewers(a)))
			emitter.stop_for_player(player)
			world.log << "SoundController stopping sound for player [player] for emitter [emitter] ([emitter.current_repeating_sound.atom]) at index [i].</span>"
			continue
		world.log << "SoundController sending current repeating sound to player [player] for emitter [emitter] ([emitter.current_repeating_sound.atom]) at index [i].</span>"
		emitter.play_current(player)

////////////////////////////////////////////////////////////////////////////////

/datum/sound_emitter
	var/list/sound/sounds = list()
	var/channel = null
	var/sound/current_repeating_sound = null
	var/datum/controller/sounds/controller

/datum/sound_emitter/New()
	. = ..()
	if (!sounds)
		sounds = list()
	controller = sound_controller

/datum/sound_emitter/Destroy()
	if (sounds)
		sounds.Cut()
		sounds = null
	if (channel && channel != null)
		stop()
		sound_controller.free_channel(channel)
	. = ..()

/datum/sound_emitter/proc/add(var/sound/s, var/key)
	if (!s || !istype(s, /sound))
		return
	if (s in sounds)
		return
	s.transform = matrix(1, 0, 0, 0, 1, 0) // dont think this ever needs to be anything else
	s.environment = -1 // dont use this ever. byond will permanently set the channel environment to it. lmao
						// though maybe we can use it for looping sounds. idk
	sounds[key] = s

// sound.atom is used to emit sound from an atom *that is visible on a turf*.
//  for example, if you have a boombox on the floor, you call set_atom(src).
//  if however you pick up the boombox, you must call set_atom(mob/user) to emit sound from the mob.
//  this is because when held the boombox isn't visible on a turf (its in inventory land) so no sound will be heard
/datum/sound_emitter/proc/set_atom(var/atom/A)
	if (!A || !ispath(A, /atom))
		return
	for (var/key in sounds)
		sounds[key].atom = A

/datum/sound_emitter/proc/play(var/key)
	world.log << "sound_emitter.PLAY [key]</span>"
	var/sound/S = sounds[key]
	if (!S)
		return

	var/sound/s = sound(S.file)
	s.repeat = S.repeat
	s.volume = S.volume
	s.atom = S.atom
	s.wait = S.wait
	s.priority = S.priority
	s.transform = S.transform
	if (S.repeat == 1)
		channel = sound_controller.reserve_channel()
		if (channel == -1)
			world.log << "SoundEmitter failed to reserve a channel.</span>" // TODO log warning elsewhere
			channel = null
		else
			world.log << "SoundEmitter reserved channel [channel].</span>"
		s.channel = channel
		current_repeating_sound = s

	// flush channel
	var/sound/nullsound = null
	if (s.channel)
		nullsound = new
		nullsound.channel = s.channel
		nullsound.file = null

	for (var/mob/player in player_list)
		send_sound(player, s, nullsound)

/datum/sound_emitter/proc/play_current(var/mob/player)
    send_sound(player, current_repeating_sound)

/datum/sound_emitter/proc/send_sound(var/mob/player, var/sound/s, var/sound/nullsound = null)
	if(!player || !player.client)
		return

	if(player.is_deaf())
		// TODO - when a player is deafened, play null sound on all their sound channels to flush anything still looping
		// ask the SOUND CONTROLLER to do this?
		return

	if (nullsound)
		world.log << "sound_emitter.PLAY sending null sound to player [player]</span>"
		player << nullsound
	world.log << "sound_emitter.PLAY sending [s] to player [player]</span>"
	player << s

/datum/sound_emitter/proc/stop()
	world.log << "sound_emitter.STOP</span>"
	if (!channel)
		return

	current_repeating_sound = null
	// flush channel
	var/sound/nullsound = sound()
	nullsound.channel = channel
	nullsound.file = null
	play(nullsound)

	release_channel()

/datum/sound_emitter/proc/stop_for_player(var/mob/player)
	if (!player || !player.client)
		return

	if (!channel)
		return

	var/sound/nullsound = sound()
	nullsound.channel = channel
	nullsound.file = null
	player << nullsound
	world.log << "sound_emitter.STOP_FOR_PLAYER sent null sound to player [player]</span>"

/datum/sound_emitter/proc/release_channel()
	if (channel && channel != null)
		sound_controller.free_channel(channel)
		channel = null
		world.log << "sound_emitter.RELEASE_CHANNEL freed channel [channel].</span>"
	//for (var/key in sounds)
	//	var/sound/S = sounds[key]
	//		S.channel = null   // probably not necessary