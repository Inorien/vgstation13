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

