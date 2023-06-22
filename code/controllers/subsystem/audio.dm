//Step 0: Go to __DEFINES/setup.dm and look at the bit with sound channels.
//  Byond can handle 1024 sound channels. When playing a sound we can do so
//  on a specific channel or delegate channel selection to Byond.
//  Playing on a specific channel requires reservation of the channel for its
//  usage duration. If the channel is used to play another sound, the first
//  sound will be cleared and the new will immediately play.
//Similar to memory allocation, reserving a sound channel will require the
//  client code to own a reference to the channel it is using (in this case,
//  just a channel number). Losing this reference is akin to losing a pointer
//  to allocated memory.
//Running out of sound channels is an exciting prospect that will lead to fun

/datum/subsystem/audio
	name = "Audio"
	//TODO: flags
	//TODO: priority
	//TODO: display_order?
	//TODO: init_order?
	//TODO: wait?


	//retarded double booking for now
	//this is where the unused channels be
	var/free_list = list()
	//this is where the in-use channels be
	var/use_list  = list()

/datum/subsystem/audio/proc/doInit()
	for (var/i in CHANNEL_LOWEST_FREE to CHANNEL_HIGHEST_FREE)
		free_list.Add(i)

/datum/subsystem/audio/Initialize()
	doInit()

//perhaps unneeded, see if its useful in debug
/datum/subsystem/audio/proc/reset()
	use_list.Remove(use_list) //????
	doInit()

/datum/subsystem/audio/proc/get()
	if (free_list.len)
		var/channel = free_list[1]
		free_list.Remove(channel)
		use_list.Add(channel)
		return channel
	//uh oh stinky - someone tried to allocate a channel but we have none left
	return //TODO: something better than this crap

/datum/subsystem/audio/proc/free(channel)
	use_list.Remove(channel)
	free_list.Add(channel)

/datum/subsystem/audio/proc/playAndFree(/*params*/) //play a sound on a channel, let it finish, then free the channel
	//figure out how long we need to wait
	//playsound(/*params*/)
	//wait
	//free the channel

//theres a sound.wait() function that returns total length of queued items
//could be good for getting update lists

//prototype functions below, no idea where the fuck to put these if they cant replace sound.dm or if they'll survive long at all

//i think channel should be a mandatory parameter for this use-case, and we just grandfather legacy behaviour in (?) though this should be backward compatible, legacy system is simple

//General case, this handles most sound needs
/proc/playaudio(var/atom/source, soundin, vol as num, vary = 0, extrarange as num, falloff, var/gas_modified = 1, var/channel = 0, var/wait = FALSE, var/frequency = 0, var/repeat = 0)
	var/turf/turf_source = get_turf(source)

	ASSERT(!isnull(turf_source))
	ASSERT(!(isnull(soundin) && channel == 0)) //Sending null to channel 0 will interrupt all channels (stupid)

	//ignore the preprocess until core function is done

	for (var/mob/player in player_list)
		if (!player || !player.client)
			continue

		if(player.is_deaf() && !(channel == CHANNEL_ADMINMUSIC || channel == CHANNEL_AMBIENCE))
			continue

		var/turf/player_turf = get_turf(player)

		//uhh how do i actually reserve the sound channel

		//assign callback to player on move that reruns play_local with update flag on
		//consider handling of update - cant touch status yet (?) pass each separate flag in or just octal and decode there?
		//fire off initial play of sound akin to original with update = 0
		player.playaudio_local(turf_source, soundin, vol, frequency, falloff, gas_modified, channel, wait, update, repeat)

//Per-channel handling of individual sound on client, mimics legacy behaviour somewhat
/proc/playaudio_local(var/turf/turf_source, soundin, vol as num, frequency, falloff, gas_modified, var/channel = 0, var/wait = FALSE, var/update = 0, var/repeat = 0)
	if(!src.client)
		return

	//fuck ear_deaf and gas_modified, i want better handling than that (eventually)
	//imagine having a ringing in your ears if you're temporarily deaf and it gradually fades into being able to hear rather than suddenly full mute to full sound
	//or a jukebox becoming gradually audible as a room repressurises
	//even the simple case we could have that sound just constantly repeat playing on the telecomms equipment like in that computer room by the unatco base in the first deus ex
	//imagine the power

	var/sound/S = sound(soundin, repeat, wait, channel, vol)

	S.status = status

	src << S
