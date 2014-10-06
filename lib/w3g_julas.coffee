fs = require 'fs'
php = require 'phpjs'

convert = require './w3g_julas_convert'
actions = require './w3g_action'
speed = require './w3g_speed'
visibility = require './w3g_visibility'
colors = require './w3g_color'
observers = require './w3g_observer'

unpack = require '../utils/unpack'
inflate = require '../utils/inflate'

# to know when there is a need to load next block
MAX_DATABLOCK = 1500
# for preventing duplicated actions
ACTION_DELAY = 1000
# to know how long it may take after buying a Tome of Retraining to retrain a hero
RETRAINING_TIME = 15000

exit = (msg) ->
	throw msg

module.exports = class Replay
	max_datablock: +MAX_DATABLOCK
	fbytesread: 0
	data: ''
	
	constructor: (filename, parse_actions, parse_chat) ->
		@parse_actions = parse_actions || true
		@parse_chat = parse_chat || true
		@filename = filename
		@game =
			player_count: 0
		@players = {}
		@teams = []
		@time = 0
		@chat = []
		@leaves = 0
		
		if !@fp = fs.openSync filename, 'r'
			return exit @filename + ': Can\'t read replay file'
		
		@parseheader()
		@parsedata()
		@cleanup()
		
		fs.closeSync @fp
		
		delete @fp
		delete @data
		delete @max_datablock
		delete @ability_delay
		delete @leave_unknown
		delete @continue_game
		delete @fbytesread
		delete @header.blocks
		delete @header.flags
		delete @header.header_size
		delete @header.header_v
		delete @header.u_size
		delete @parse_actions
		delete @parse_chat
		delete @time
		delete @leaves
		delete @players
	
	fread: (length) ->
		buffer = new Buffer length
		fs.readSync @fp, buffer, 0, length, @fbytesread
		@fbytesread += length
		data = buffer.toString 'binary'
	
	# 2.0 [Header]
	parseheader: () ->
		data = @fread 48
		
		@header = unpack('a28intro/Vheader_size/Vc_size/Vheader_v/Vu_size/Vblocks', data)
		
		if @header.intro != "Warcraft III recorded game\x1A"
			return exit 'Not a replay file'
		
		if @header.header_v == 0
			data = @fread 16
			
			@header = php.array_merge(@header, unpack('vminor_v/vmajor_v/vbuild_v/vflags/Vlength/Vchecksum', data))
			@header.ident = 'WAR3'
		else if @header.header_v == 1
			data = @fread 20
			
			@header = php.array_merge(@header, unpack('a4ident/Vmajor_v/vbuild_v/vflags/Vlength/Vchecksum', data))
			
			@header.minor_v = 0
			@header.ident = php.strrev @header.ident
	
	parsedata: () ->
		@fbytesread = @header.header_size
		blocks_count = @header.blocks
		
		i = 0
		while i < blocks_count
			# 3.0 [Data block header]
			block_header = unpack('vc_size/vu_size/Vchecksum', @fread 8)
			
			temp = @fread block_header.c_size
			temp = php.substr temp, 2, -4
			
			# the first bit must be always set, but already set in replays with modified chatlog (why?)
			temp[0] = php.chr(php.ord(temp[0]) | 1)
			
			if temp = inflate(temp)
				@data += temp
			else
				return exit @filename + ': Incomplete replay file'
			
			# 4.0 [Decompressed data]
			if i == 0
				@data = php.substr @data, 4
				@loadplayer()
				@loadgame()
			else if blocks_count - i < 2
				@max_datablock = 0
			
			if @parse_chat || @parse_actions
				@parseblocks()
			else
				break
			
			i++
	
	# 4.1 [PlayerRecord]
	loadplayer: () ->
		temp = unpack('Crecord_id/Cplayer_id', @data)
		
		@data = php.substr @data, 2
		player_id = temp.player_id
		
		@players[player_id] =
			player_id: player_id
			initiator: convert.bool !temp.record_id
			name: ''
			actions_details: {}
			hotkeys: {}
			units:
				order: {}
			heroes:
				order: {}
			buildings:
				order: {}
			items:
				order: {}
			upgrades:
				order: {}
		
		for key, action of actions
			@players[player_id].actions_details[action] = 0
		
		i = 0
		while @data[i] != "\x00"
			@players[player_id].name += @data[i]
			i++
		
		# if it's FFA we need to give players some names
		if @players[player_id].name == ''
			@players[player_id].name = 'Player ' + player_id
		
		@data = php.substr @data, i + 1
		
		if(php.ord(@data[0]) == 1) # custom game
			@data = php.substr @data, 2
		else if(php.ord(@data[0]) == 8) # ladder game
			@data = php.substr @data, 1
			temp = unpack('Vruntime/Vrace', @data)
			@data = php.substr @data, 8
			@players[player_id].exe_runtime = temp.runtime
			@players[player_id].race = convert.race temp.race
		
		if @parse_actions
			@players[player_id].actions = 0
		
		if !@header.build_v # calculating team for tournament replays from battle.net website
			@players[player_id].team = (player_id - 1) % 2
		
		@game.player_count++
	
	loadgame: () ->
		# 4.2 [GameName]
		@game.name = ''
		
		i = 0
		while @data[i] != php.chr(0)
			@game.name += @data[i]
			i++
		
		@data = php.substr @data, i + 2 # 0-byte ending the string + 1 unknown byte
		
		# 4.3 [Encoded String]
		temp = ''
		
		i = 0
		while @data[i] != php.chr(0)
			if i % 8 == 0
				mask = php.ord @data[i]
			else
				temp += php.chr(php.ord(@data[i]) - !(mask & (1 << i % 8)))
			
			i++
		
		@data = php.substr @data, i+1
		
		# 4.4 [GameSettings]
		@game.speed = speed[php.ord(temp[0])]
		
		if(php.ord(temp[1]) & 1)
			@game.visibility = visibility[0]
		else if(php.ord(temp[1]) & 2)
			@game.visibility = visibility[1]
		else if(php.ord(temp[1]) & 4)
			@game.visibility = visibility[2]
		else if(php.ord(temp[1]) & 8)
			@game.visibility = visibility[3]
		
		@game.observers = observers[((php.ord(temp[1]) & 16) == true) + 2*((php.ord(temp[1]) & 32) == true)]
		@game.teams_together = convert.bool(php.ord(temp[1]) & 64)
		
		@game.lock_teams = convert.bool(php.ord(temp[2]))
		
		@game.full_shared_unit_control = convert.bool(php.ord(temp[3]) & 1)
		@game.random_hero = convert.bool(php.ord(temp[3]) & 2)
		@game.random_races = convert.bool(php.ord(temp[3]) & 4)
		
		if php.ord(temp[3]) & 64
			@game.observers = observers[4]
		
		temp = php.substr temp, 13 # 5 unknown bytes + checksum
		
		# 4.5 [Map&CreatorName]
		temp = php.explode(php.chr(0), temp)
		@game.creator = temp[1]
		@game.map = temp[0]
		
		# 4.6 [PlayerCount]
		temp = unpack('Vslots', @data)
		@data = php.substr @data, 4
		@game.slots = temp.slots
		
		# 4.7 [GameType]
		@game.type = convert.game_type(php.ord(@data[0]))
		@game.private = convert.bool(php.ord(@data[1]))
		
		@data = php.substr @data, 8 # 2 bytes are unknown and 4.8 [LanguageID] is useless
		
		# 4.9 [PlayerList]
		while(php.ord(@data[0]) == 0x16)
			@loadplayer()
			@data = php.substr(@data, 4)
		
		# 4.10 [GameStartRecord]
		temp = unpack('Crecord_id/vrecord_length/Cslot_records', @data)
		@data = php.substr @data, 4
		@game = php.array_merge @game, temp
		ords = temp.slot_records
		
		# 4.11 [SlotRecord]
		i = 0
		while i < ords
			if @header.major_v >= 7
				temp = unpack('Cplayer_id/x1/Cslot_status/Ccomputer/Cteam/Ccolor/Crace/Cai_strength/Chandicap', @data)
				@data = php.substr @data, 9
			else if @header.major_v >= 3
				temp = unpack('Cplayer_id/x1/Cslot_status/Ccomputer/Cteam/Ccolor/Crace/Cai_strength', @data)
				@data = php.substr @data, 8
			else
				temp = unpack('Cplayer_id/x1/Cslot_status/Ccomputer/Cteam/Ccolor/Crace', @data)
				@data = php.substr @data, 7
			
			if temp.slot_status == 2 # do not add empty slots
				temp.color = colors[temp.color]
				temp.race = convert.race temp.race
				temp.ai_strength = convert.ai temp.ai_strength
				
				# player ID is always 0 for computer players
				if temp.computer == 1
					@players.push temp
				else
					@players[temp.player_id] = php.array_merge(@players[temp.player_id], temp)
				
				# Tome of Retraining
				@players[temp.player_id].retraining_time = 0
			
			i++
		
		# 4.12 [RandomSeed]
		temp = unpack('Vrandom_seed/Cselect_mode/Cstart_spots', @data)
		@data = php.substr @data, 6
		@game.random_seed = temp.random_seed
		@game.select_mode = convert.select_mode temp.select_mode
		if temp.start_spots != 0xCC # tournament replays from battle.net website don't have this info
			@game.start_spots = temp.start_spots
	
	# 5.0 [ReplayData]
	parseblocks: () ->
		data_left = php.strlen @data
		block_id = 0
		while data_left > @max_datablock
			prev = block_id
			block_id = php.ord @data[0]
			
			switch block_id
				# TimeSlot block
				when 0x1E, 0x1F
					temp = unpack('x1/vlength/vtime_inc', @data)
					if !@pause
						@time += temp.time_inc
					
					if temp.length > 2 && @parse_actions
						@parseactions(php.substr(@data, 5, temp.length-2), temp.length - 2)
					
					@data = php.substr(@data, temp.length + 3)
					data_left -= temp.length + 3
				# Player chat message (patch version >= 1.07)
				when 0x20
					# before 1.03 0x20 was used instead 0x22
					if @header.major_v > 2
						temp = unpack('x1/Cplayer_id/vlength/Cflags/vmode', @data)
						if temp.flags == 0x20
							temp.mode = convert.chat_mode temp.mode
							temp.text = php.substr(@data, 9, temp.length - 6)
						else if temp.flags == 0x10
							# those are strange messages, they aren't visible when
							# watching the replay but they are present they have no mode
							temp.text = php.substr(@data, 7, temp.length - 3)
							delete temp.mode
						
						@data = php.substr(@data, temp.length + 4)
						data_left -= temp.length + 4
						temp.time = +@time
						temp.player_name = @players[temp.player_id].name
						@chat.push temp
				
				# unknown (Random number/seed for next frame)
				when 0x22
					temp = php.ord @data[1]
					@data = php.substr(@data, temp + 2)
					data_left -= temp + 2
				# unknown (startblocks)
				when 0x1A, 0x1B, 0x1C
					@data = php.substr @data, 5
					data_left -= 5
				# unknown (very rare, appears in front of a 'LeaveGame' action)
				when 0x23
					@data = php.substr @data, 11
					data_left -= 11
				# Forced game end countdown (map is revealed)
				when 0x2F
					@data = php.substr @data, 9
					data_left -= 9
				# LeaveGame
				when 0x17, 0x54
					@leaves++
					
					temp = unpack('x1/Vreason/Cplayer_id/Vresult/Vunknown', @data)
					@players[temp.player_id].time = +@time
					@players[temp.player_id].leave_reason = temp.reason
					@players[temp.player_id].leave_result = temp.result
					@data = php.substr @data, 14
					data_left -= 14
					if @leave_unknown
						@leave_unknown = temp.unknown - @leave_unknown
					
					if @leaves == @game.player_count
						@game.saver_id = temp.player_id
						@game.saver_name = @players[temp.player_id].name
					
					if temp.reason == 0x01
						switch temp.result
							when 0x08 then @game.loser_team = @players[temp.player_id].team
							when 0x09 then @game.winner_team = @players[temp.player_id].team
							when 0x0A
								@game.loser_team = 'tie'
								@game.winner_team = 'tie'
					else if(temp.reason == 0x0C && @game.saver_id)
						switch temp.result
							when 0x07
								if(@leave_unknown > 0 && @continue_game)
									@game.winner_team = @players[@game.saver_id].team
								else
									@game.loser_team = @players[@game.saver_id].team
							
							when 0x08 then @game.loser_team = @players[@game.saver_id].team
							when 0x09 then @game.winner_team = @players[@game.saver_id].team
							when 0x0B # this isn't correct according to w3g_format but generally works...
								if @leave_unknown > 0
									@game.winner_team = @players[@game.saver_id].team
					
					else if temp.reason == 0x0C
						switch temp.result
							when 0x07 then @game.loser_team = 99 # saver
							when 0x08 then @game.winner_team = @players[temp.player_id].team
							when 0x09 then @game.winner_team = 99 # saver
							when 0x0A
								@game.loser_team = 'tie'
								@game.winner_team = 'tie'
					
					@leave_unknown = temp.unknown
				when 0
					data_left = 0
				else
					return exit('Unhandled replay command block at '+convert.time(@time)+': 0x'+sprintf('%02X', block_id)+' (prev: 0x'+sprintf('%02X', prev)+', time: '+@time+') in '+@filename)
	
	# ACTIONS, the best part...
	parseactions: (actionblock, data_length) ->
		block_length = 0
		action = 0
		
		while data_length
			if block_length
				actionblock = php.substr actionblock, block_length
			
			temp = unpack('Cplayer_id/vlength', actionblock)
			player_id = temp.player_id
			block_length = temp.length + 3
			data_length -= block_length
			
			was_deselect = false
			was_subupdate = false
			was_subgroup = false
			
			n = 3
			while n < block_length
				prev = action
				action = php.ord actionblock[n]
				
				switch action
					# Unit/building ability (no additional parameters)
					# here we detect the races, heroes, units, items, buildings,
					# upgrades
					when 0x10
						@players[player_id].actions++
						if @header.major_v >= 13
							n++ # ability flag is one byte longer
						
						itemid = php.strrev(php.substr(actionblock, n + 2, 4))
						value = convert.itemid itemid
						
						if !value
							@players[player_id].actions_details[actions.ability]++
							
							# handling Destroyers
							if(php.ord(actionblock[n + 2]) == 0x33 && php.ord(actionblock[n + 3]) == 0x02)
								name = php.substr(convert.itemid('ubsp'), 2)
								@players[player_id].units.order[@time] = @players[player_id].units_multiplier + ' ' + name
								if !@players[player_id].units[name]
									@players[player_id].units[name] = 0
								
								@players[player_id].units[name]++
								
								name = php.substr(convert.itemid('uobs'), 2)
								if !@players[player_id].units[name]
									@players[player_id].units[name] = 0
								@players[player_id].units[name]--
						
						else
							@players[player_id].actions_details[actions.buildtrain]++
							
							if !@players[player_id].race_detected
								if race_detected = convert.race itemid
									@players[player_id].race_detected = race_detected
							
							name = php.substr value, 2
							
							switch value[0]
								when 'u'
									# preventing duplicated units
									# at the beginning of the game workers are queued very fast, so
									# it's better to omit action delay protection
									if((@time - @players[player_id].units_time > ACTION_DELAY || itemid != @players[player_id].last_itemid) || ((itemid == 'hpea' || itemid == 'ewsp' || itemid == 'opeo' || itemid == 'uaco') && @time - @players[player_id].units_time > 0))
										@players[player_id].units_time = +@time
										
										@players[player_id].units.order[@time] = @players[player_id].units_multiplier+' '+name
										
										@players[player_id].units[name] = @players[player_id].units[name] || 0
										
										@players[player_id].units[name] += @players[player_id].units_multiplier
									
								when 'b'
									@players[player_id].buildings.order[@time] = name
									
									if !@players[player_id].buildings[name]
										@players[player_id].buildings[name] = 0
									
									@players[player_id].buildings[name]++
									
								when 'h'
									@players[player_id].heroes.order[@time] = name
									
									@players[player_id].heroes[name] = @players[player_id].heroes[name] || {}
									@players[player_id].heroes[name].revivals = @players[player_id].heroes[name].revivals || 0
									
									@players[player_id].heroes[name].revivals++
									
								when 'a'
									[hero, ability] = php.explode ':', name
									
									@players[player_id].heroes[hero] = @players[player_id].heroes[hero] || {}
									
									retraining_time = @players[player_id].retraining_time
									
									if !@players[player_id].heroes[hero].retraining_time
										@players[player_id].heroes[hero].retraining_time = 0
									
									if !@players[player_id].heroes[hero].abilities
										@players[player_id].heroes[hero].abilities =
											order: {}
									
									@players[player_id].heroes[hero].abilities[retraining_time] = @players[player_id].heroes[hero].abilities[retraining_time] || {}
									
									@players[player_id].heroes[hero].abilities[retraining_time][ability] = @players[player_id].heroes[hero].abilities[retraining_time][ability] || 0
									
									# preventing too high levels (avoiding duplicated actions)
									# the second condition is mainly for games with random heroes
									# the third is for handling Tome of Retraining usage
									if((@time - @players[player_id].heroes[hero].ability_time > ACTION_DELAY || !@players[player_id].heroes[hero].ability_time || @time - retraining_time < RETRAINING_TIME) && @players[player_id].heroes[hero].abilities[retraining_time][ability] < 3)
										if @time - retraining_time > RETRAINING_TIME
											@players[player_id].heroes[hero].ability_time = +@time
											
											if !@players[player_id].heroes[hero].level
												@players[player_id].heroes[hero].level = 0
											
											@players[player_id].heroes[hero].level++
											
											if !@players[player_id].heroes[hero].abilities[@players[player_id].heroes[hero].retraining_time][ability]
												@players[player_id].heroes[hero].abilities[@players[player_id].heroes[hero].retraining_time][ability] = 0
											@players[player_id].heroes[hero].abilities[@players[player_id].heroes[hero].retraining_time][ability]++
										else
											@players[player_id].heroes[hero].retraining_time = retraining_time
											@players[player_id].heroes[hero].abilities.order[retraining_time] = 'Retraining'
											
											if !@players[player_id].heroes[hero].abilities[retraining_time][ability]
												@players[player_id].heroes[hero].abilities[retraining_time][ability] = 0
											
											@players[player_id].heroes[hero].abilities[retraining_time][ability]++
										
										@players[player_id].heroes[hero].abilities.order[@time] = ability
									
								when 'i'
									@players[player_id].items.order[@time] = name
									if !@players[player_id].items[name]
										@players[player_id].items[name] = 0
									
									@players[player_id].items[name]++
									
									if itemid == 'tret'
										@players[player_id].retraining_time = +@time
								
								when 'p'
									# preventing duplicated upgrades
									if(@time - @players[player_id].upgrades_time > ACTION_DELAY || itemid != @players[player_id].last_itemid)
										@players[player_id].upgrades_time = +@time
										@players[player_id].upgrades.order[@time] = name
										if !@players[player_id].upgrades[name]
											@players[player_id].upgrades[name] = 0
										
										@players[player_id].upgrades[name]++
									
								else
									@errors[@time] = 'Unknown ItemID at '+convert.time(@time)+': '+value
							
							@players[player_id].last_itemid = itemid
						
						if @header.major_v >= 7
							n += 14
						else
							n += 6
					
					# Unit/building ability (with target position)
					when 0x11
						@players[player_id].actions++
						if @header.major_v >= 13
							n++ # ability flag
						
						if(php.ord(actionblock[n + 2]) <= 0x19 && php.ord(actionblock[n + 3]) == 0x00) # basic commands
							@players[player_id].actions_details[actions.basic]++
						else
							@players[player_id].actions_details[actions.ability]++
						
						value = php.strrev(php.substr(actionblock, n + 2, 4))
						if value = convert.buildingid value
							@players[player_id].buildings.order[@time] = value
							
							if !@players[player_id].buildings[value]
								@players[player_id].buildings[value] = 0
							
							@players[player_id].buildings[value]++
						
						if @header.major_v >= 7
							n += 22
						else
							n += 14
					
					# Unit/building ability (with target position and target object ID)
					when 0x12
						@players[player_id].actions++
						if @header.major_v >= 13
							n++ # ability flag
						
						if(php.ord(actionblock[n + 2]) == 0x03 && php.ord(actionblock[n + 3]) == 0x00) # rightclick
							@players[player_id].actions_details[actions.rightclick]++
						else if(php.ord(actionblock[n + 2]) <= 0x19 && php.ord(actionblock[n + 3]) == 0x00) # basic commands
							@players[player_id].actions_details[actions.basic]++
						else
							@players[player_id].actions_details[actions.ability]++
						
						if @header.major_v >= 7
							n += 30
						else
							n += 22
					
					# Give item to Unit / Drop item on ground
					when 0x13
						@players[player_id].actions++
						if @header.major_v >= 13
							n++ # ability flag
						
						@players[player_id].actions_details[actions.item]++
						if @header.major_v >= 7
							n += 38
						else
							n += 30
					
					# Unit/building ability (with two target positions and two item IDs)
					when 0x14
						@players[player_id].actions++
						if @header.major_v >= 13
							n++ # ability flag
						
						if(php.ord(actionblock[n + 2]) == 0x03 && php.ord(actionblock[n + 3]) == 0x00) # rightclick
							@players[player_id].actions_details[actions.rightclick]++
						else if(php.ord(actionblock[n + 2]) <= 0x19 && php.ord(actionblock[n + 3]) == 0x00) # basic commands
							@players[player_id].actions_details[actions.basic]++
						else
							@players[player_id].actions_details[actions.ability]++
						
						if @header.major_v >= 7
							n += 43
						else
							n += 35
					
					# Change Selection (Unit, Building, Area)
					when 0x16
						temp = unpack('Cmode/vnum', php.substr(actionblock, n + 1, 3))
						if temp.mode == 0x02 || !was_deselect
							@players[player_id].actions++
							@players[player_id].actions_details[actions.select]++
						
						was_deselect = temp.mode == 0x02
						
						@players[player_id].units_multiplier = temp.num
						n += 4 + (temp.num * 8)
					
					# Assign Group Hotkey
					when 0x17
						@players[player_id].actions++
						@players[player_id].actions_details[actions.assignhotkey]++
						temp = unpack('Cgroup/vnum', php.substr(actionblock, n + 1, 3))
						
						@players[player_id].hotkeys[temp.group] = @players[player_id].hotkeys[temp.group] || {}
						@players[player_id].hotkeys[temp.group].assigned = @players[player_id].hotkeys[temp.group].assigned || 0
						
						@players[player_id].hotkeys[temp.group].assigned++
						@players[player_id].hotkeys[temp.group].last_totalitems = temp.num
						
						n += 4 + (temp.num * 8)
					
					# Select Group Hotkey
					when 0x18
						@players[player_id].actions++
						@players[player_id].actions_details[actions.selecthotkey]++
						
						@players[player_id].hotkeys[php.ord(actionblock[n + 1])].used = @players[player_id].hotkeys[php.ord(actionblock[n + 1])].used || 0
						
						@players[player_id].hotkeys[php.ord(actionblock[n + 1])].used++
						
						@players[player_id].units_multiplier = @players[player_id].hotkeys[php.ord(actionblock[n + 1])].last_totalitems
						n += 3
					
					# Select Subgroup
					when 0x19
						# OR is for torunament reps which don't have build_v
						if(@header.build_v >= 6040 || @header.major_v > 14)
							if was_subgroup # can't think of anything better (check action 0x1A)
								@players[player_id].actions++
								@players[player_id].actions_details[actions.subgroup]++
								
								# I don't have any better idea what to do when somebody binds buildings
								# of more than one type to a single key and uses them to train units
								# TODO: this is rarely executed, maybe it should go after if(was_subgroup) {}?
								@players[player_id].units_multiplier = 1
							
							n += 13
						else
							if(php.ord(actionblock[n+1]) != 0 && php.ord(actionblock[n+1]) != 0xFF && !was_subupdate)
								@players[player_id].actions++
								@players[player_id].actions_details[actions.subgroup]++
							
							was_subupdate = (php.ord(actionblock[n+1]) == 0xFF)
							n += 2
	
					# some subaction holder?
					# version < 14b: Only in scenarios, maybe a trigger-related command
					when 0x1A
						# OR is for torunament reps which don't have build_v
						if(@header.build_v >= 6040 || @header.major_v > 14)
							n += 1
							was_subgroup = (prev == 0x19 || prev == 0) #0 is for new blocks which start with 0x19
						else
							n += 10
	
					# Only in scenarios, maybe a trigger-related command
					# version < 14b: Select Ground Item
					when 0x1B
						# OR is for torunament reps which don't have build_v
						if(@header.build_v >= 6040 || @header.major_v > 14)
							n += 10
						else
							@players[player_id].actions++
							n += 10
						
					# Select Ground Item
					# version < 14b: Cancel hero revival (new in 1.13)
					when 0x1C
						# OR is for torunament reps which don't have build_v
						if(@header.build_v >= 6040 || @header.major_v > 14)
							@players[player_id].actions++
							n += 10
						else
							@players[player_id].actions++
							n += 9
						
					# Cancel hero revival
					# Remove unit from building queue
					when 0x1D, 0x1E
						# OR is for torunament reps which don't have build_v
						if((@header.build_v >= 6040 || @header.major_v > 14) && action != 0x1E)
							@players[player_id].actions++
							n += 9
						else
							@players[player_id].actions++
							@players[player_id].actions_details[actions.removeunit]++
							value = convert.itemid(php.strrev(php.substr(actionblock, n+2, 4)))
							name = php.substr(value, 2)
							switch value[0]
								when 'u'
									# preventing duplicated units cancellations
									if(@time - @players[player_id].runits_time > ACTION_DELAY || value != @players[player_id].runits_value)
										@players[player_id].runits_time = +@time
										@players[player_id].runits_value = value
										@players[player_id].units.order[@time] = '-1 ' + name
										if !@players[player_id].units[name]
											@players[player_id].units[name] = 0
										
										@players[player_id].units[name]--
									
								when 'b'
									if !@players[player_id].buildings[name]
										@players[player_id].buildings[name] = 0
									
									@players[player_id].buildings[name]--
									
								when 'h'
									if !@players[player_id].heroes[name]
										@players[player_id].heroes[name] = 0
										
									if !@players[player_id].heroes[name].revivals
										@players[player_id].heroes[name].revivals = 0
									
									@players[player_id].heroes[name].revivals--
									
								when 'p'
									# preventing duplicated upgrades cancellations
									if(@time - @players[player_id].rupgrades_time > ACTION_DELAY || value != @players[player_id].rupgrades_value)
										@players[player_id].rupgrades_time = +@time
										@players[player_id].rupgrades_value = value
										
										if !@players[player_id].upgrades[name]
											@players[player_id].upgrades[name] = 0
										
										@players[player_id].upgrades[name]--

							n += 6
	
					# Found in replays with patch version 1.04 and 1.05.
					when 0x21
						n += 9
	
					# Change ally options
					when 0x50
						n += 6
	
					# Transfer resources
					when 0x51
						n += 10
	
					# Map trigger chat command (?)
					when 0x60
						n += 9
						while (actionblock[n] != "\x00")
							n++
						
						++n
	
					# ESC pressed
					when 0x61						
						@players[player_id].actions++
						
						@players[player_id].actions_details[actions.esc]++
						++n
	
					# Scenario Trigger
					when 0x62
						if @header.major_v >= 7
							n += 13
						else
							n += 9
	
					# Enter select hero skill submenu for WarCraft III patch version <= 1.06
					when 0x65
						@players[player_id].actions++
						
						@players[player_id].actions_details[actions.heromenu]++
						++n
	
					# Enter select hero skill submenu
					# Enter select building submenu for WarCraft III patch version <= 1.06
					when 0x66
						@players[player_id].actions++
						if @header.major_v >= 7
							@players[player_id].actions_details[actions.heromenu]++
						else
							@players[player_id].actions_details[actions.buildmenu]++
						
						n += 1
	
					# Enter select building submenu
					# Minimap signal (ping) for WarCraft III patch version <= 1.06
					when 0x67
						if @header.major_v >= 7
							@players[player_id].actions++
							@players[player_id].actions_details[actions.buildmenu]++
							n += 1
						else
							n += 13
	
					# Minimap signal (ping)
					# Continue Game (BlockB) for WarCraft III patch version <= 1.06
					when 0x68
						if @header.major_v >= 7
							n += 13
						else
							n += 17
	
					# Continue Game (BlockB)
					# Continue Game (BlockA) for WarCraft III patch version <= 1.06
					when 0x69, 0x6A
						@continue_game = 1
						n += 17
	
					# Pause game
					when 0x01
						@pause = true
						temp = ''
						temp.time = +@time
						temp.text = convert.chat_mode(0xFE, @players[player_id].name)
						@chat.push temp
						n += 1
	
					# Resume game
					when 0x02
						temp = ''
						@pause = false
						temp.time = +@time
						temp.text = convert.chat_mode(0xFF, @players[player_id].name)
						@chat.push temp
						n += 1
	
					# Increase game speed in single player game (Num+)
					when 0x04, 0x05
						n += 1
	
					# Set game speed in single player game (options menu)
					when 0x03
						n += 2
	
					# Save game
					when 0x06
						i = 1
						while (actionblock[n] != "\x00")
							n++
						
						n += 1
	
					# Save game finished
					when 0x07
						n += 5
	
					# Only in scenarios, maybe a trigger-related command
					when 0x75
						n += 2
	
					else
						temp = ''
						
						i = 0
						while i < n
							temp += sprintf('%02X', php.ord(actionblock[i]))+' '
							i++
						
						temp += '['+sprintf('%02X', php.ord(actionblock[n]))+'] '
						
						i = 0
						while n + i < php.strlen(actionblock)
							temp += sprintf('%02X', php.ord(actionblock[n+i]))+' '
							i++
						
						@errors.push 'Unknown action at '+convert.time(@time)+': 0x'+sprintf('%02X', action)+', prev: 0x'+sprintf('%02X', prev)+', dump: '+temp
						
						# skip to the next CommandBlock
						# continue 3, not 2 because of http:#php.net/manual/en/control-structures.continue.php#68193
						# ('Current functionality treats switch structures as looping in regards to continue+')
						continue3
			
			was_deselect = (action == 0x16)
			was_subupdate = (action == 0x19)
	
	cleanup: () ->
		# players time cleanup
		
		for player_id, player of @players
			if !player.time
				@players[player.player_id].time = @header.length
			
			# counting apm
			if @parse_actions
				if(@players[player_id].team != 12 && @players[player_id].computer == 0)
					@players[player_id].apm = @players[player_id].actions / @players[player_id].time * 60000
			
			# splitting teams
			if typeof player.team != 'undefined' # to eliminate zombie-observers caused by Waaagh!TV
				if !@teams[player.team]
					@teams[player.team] = {}
				
				@teams[player.team][player_id] = player
			
			delete player.last_itemid
		
		@players[@game.saver_id] = @players[@game.saver_id] || {}
		
		# winner/loser cleanup
		if @game.winner_team == 99 # saver
			@game.winner_team = @players[@game.saver_id].team || 0
		else if @game.loser_team == 99
			@game.loser_team = @players[@game.saver_id].team || 0
		
		winner = typeof @game.winner_team != 'undefined' ? true : false
		loser = typeof @game.loser_team != 'undefined' ? true : false
		
		if(!winner && loser)
			team_id = @teams.length
			while team_id--
				team = @teams[team_id]
				if(team_id != @game.loser_team && team_id != 12)
					@game.winner_team = team_id
					break
		else if(!loser && winner)
			team_id = @teams.length
			while team_id--
				team = @teams[team_id]
				if(team_id != @game.winner_team && team_id != 12)
					@game.loser_team = team_id
					break