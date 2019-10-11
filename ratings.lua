--[[
MIT License

Copyright (c) 2019 Pragmatic Software

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

function descriptor()
	return {
		title = "Ratings",
		version = "1.0",
		license = "MIT",
		shortdesc = "Ratings",
		description = "Rates items and shuffles playlists with a bias towards higher ratings.",
		author = "pragma, based on history-shuffle by Stefan Steininger",
		capabilities = {"playing-listener", "input-listener"}
	}
end

local playlist = {}          -- holds all music items form the current playlist
local store = {}             -- holds all music items from the database
local dialog                 -- main GUI interface
local prefix = "[ratings] "  -- prefix to log messages
local data_file = ""         -- path to data file

function activate()
	vlc.msg.info(prefix .. "starting")

	math.randomseed(os.time())

	data_file = vlc.config.userdatadir() .. "/ratings.csv"
	vlc.msg.info(prefix ..  "using data file " .. data_file)

	load_data_file()
	scan_playlist()
	show_gui()
end

function deactivate()
	vlc.msg.info(prefix ..  "deactivating.. Bye!")
	if dialog ~= nil then
		dialog:delete()
	end
end

function show_gui()
	dialog = vlc.dialog("Ratings")
	label_path = dialog:add_label("Path", 1, 1, 3)
	input_rating = dialog:add_text_input("5", 4, 1)
	checkbox_locked = dialog:add_check_box("Rating Locked", false, 5, 1)

	local onclick_rateN = function(rating)
		return function()
			input_rating:set_text(rating)
			checkbox_locked:set_checked(true)
		end
	end

	dialog:add_button("1",  onclick_rateN("1"),  1, 3)
	dialog:add_button("2",  onclick_rateN("2"),  2, 3)
	dialog:add_button("3",  onclick_rateN("3"),  3, 3)
	dialog:add_button("4",  onclick_rateN("4"),  4, 3)
	dialog:add_button("5",  onclick_rateN("5"),  5, 3)

	dialog:add_button("6",  onclick_rateN("6"),  1, 4)
	dialog:add_button("7",  onclick_rateN("7"),  2, 4)
	dialog:add_button("8",  onclick_rateN("8"),  3, 4)
	dialog:add_button("9",  onclick_rateN("9"),  4, 4)
	dialog:add_button("10", onclick_rateN("10"), 5, 4)

	dialog:add_button("Rate!", onclick_rate, 1, 5, 5)

	dialog:add_label("Shuffle Min Rating:", 1, 6)
	input_min_rating = dialog:add_text_input("1", 2, 6)
	dialog:add_label("Shuffle Max Rating:", 3, 6)
	input_max_rating = dialog:add_text_input("10", 4, 6)
	button_shuffle = dialog:add_button("Shuffle Playlist", onclick_shuffle, 5, 6)

	dialog:add_button("Refresh Playlist", onclick_refresh, 1, 7)
	dialog:add_button("Reset Unlocked Ratings", onclick_reset_ratings, 2, 7)

	update_gui()
	dialog:show()
end

function onclick_rate()
	local path = label_path:get_text()
	local rating = tonumber(input_rating:get_text())
	local locked = checkbox_locked:get_checked()

	if rating < 1 then
		rating = 1
		input_rating:set_text(rating)
	elseif rating > 10 then
		rating = 10
		input_rating:set_text(rating)
	end

	store[path].rating = rating
	store[path].locked = locked

	local fullpath = store[path].fullpath
	playlist[fullpath] = store[path].rating

	save_data_file()
end

function onclick_shuffle()
	local min = tonumber(input_min_rating:get_text())
	local max = tonumber(input_max_rating:get_text())

	-- sanity checks
	local update_gui = false
	if min < 1 then
		min = 1
		update_gui = true
	end

	if max > 10 then
		max = 10
		update_gui = true
	end

	if min > max then
		min = max
		update_gui = true
	end

	if max < min then
		max = min
		update_gui = true
	end

	if update_gui then
		input_min_rating:set_text(min)
		input_max_rating:set_text(max)
	end

	randomize_playlist(min, max)
end

function onclick_refresh()
	update_playlist()
end

function onclick_reset_ratings()
	for fullpath,item in pairs(playlist) do
		local path = basename(fullpath)
		if store[path].locked == false then
			store[path].rating = 5
		end
	end
	save_data_file()
	update_playlist()
end

function close()
	vlc.deactivate()
end

function update_gui()
	local item = vlc.input.item()
	if item == nil then
		vlc.msg.warn(prefix .. "input item is nil, skipping update_gui")
		return
	end
	local path = basename(vlc.strings.decode_uri(item:uri()))
	label_path:set_text(path)
	input_rating:set_text(store[path].rating)
	checkbox_locked:set_checked(store[path].locked)
end

function basename(path)
	i = path:find("/[^/]*$")
	if i == nil then
		return path
	else
		return path:sub(i + 1)
	end
end

-- scans current playlist
function scan_playlist()
	vlc.msg.info(prefix .. "scanning playlist")
	local current_playlist = vlc.playlist.get("playlist").children
	for i, entry in ipairs(current_playlist) do
		-- decode path and remove escaping
		local path = entry.item:uri()
		path = vlc.strings.decode_uri(path)
		local fullpath = path
		path = basename(path)

		-- check if we have the song in the database
		-- and copy the rating else create a new entry
		if store[path] then
			playlist[fullpath] = store[path].rating
			store[path].fullpath = fullpath
		else
			playlist[fullpath] = 5
			store[path] = {rating = 5, locked = false, fullpath = fullpath}
			changed = true
		end
	end

	-- save changes
	if changed then
		save_data_file()
	end

	update_playlist()
end

-- updates ratings column for all items in playlist
function update_playlist()
	vlc.msg.info(prefix .. "updating playlist")
	local new_playlist = {}
	local current_playlist = vlc.playlist.get("playlist").children
	for i, entry in ipairs(current_playlist) do
		-- decode path and remove escaping
		local path = entry.item:uri()
		path = vlc.strings.decode_uri(path)
		local fullpath = path
		path = basename(path)

		if store[path] then
			local newentry = {["path"] = fullpath, ["rating"] = store[path].rating}
			table.insert(new_playlist, newentry)
		end
	end

	vlc.playlist.clear()
	vlc.playlist.enqueue(new_playlist)
end

-- randomizes the playlist based on the ratings
-- higher ratings will be higher up in the playlist
function randomize_playlist(min, max)
	vlc.msg.info(prefix .. "randomizing playlist")
	vlc.playlist.stop() -- stop the current song, takes some time

	-- create a table with the index being the rating
	local bins = {}
	for i=min,max do
		bins[i] = Queue.new()
	end

	-- add song to appropriate bin
	for path,rating in pairs(playlist) do
		if rating >= min and rating <= max then
			Queue.enqueue(bins[rating], path)
		end
	end

	-- shuffle non-empty bins
	for i=min,max do
		if Queue.size(bins[i]) > 0 then
			Queue.shuffle(bins[i])
		end
	end

	local new_playlist = {}
	for i=max,min,-1 do
		local continue = true
		while true do
			local fullpath = Queue.dequeue(bins[i])
			if fullpath == nil then
				break
			end
			local path = basename(fullpath)
			local rating = store[path].rating
			item = {["path"] = fullpath, ["rating"] = rating}
			table.insert(new_playlist, item)
		end
	end

	vlc.playlist.clear()
	vlc.playlist.enqueue(new_playlist)
	vlc.playlist.random("off")
	vlc.playlist.play()
end

-- -- IO operations -- --

function toboolean(value)
	value = tonumber(value)
	if value == nil then
		return false
	elseif value == 0 then
		return false
	else
		return true
	end
end

function load_data_file()
	-- open file
	vlc.msg.info(prefix .. "Loading data from " .. data_file)
	local file,err = io.open(data_file, "r")
	store = {}
	if err then
		vlc.msg.warn(prefix .. "data file does not exist, creating...")
		file,err = io.open(data_file, "w");
		if err then
			vlc.msg.err(prefix .. "unable to open data file: " .. err)
			vlc.deactivate()
			return
		end
	else
		-- file successfully opened
		for line in file:lines() do
			-- csv layout is tab-separated: path, rating, locked
			local fields = {}
			for field in line:gmatch("[^\t]+") do
			  table.insert(fields, field)
			end

			local path = fields[1]
			local rating = tonumber(fields[2])
			local locked = toboolean(fields[3])

			store[path] = {rating=rating, locked=locked}
		end
	end
	io.close(file)
end

function save_data_file()
	vlc.msg.info(prefix .. "Saving data to " .. data_file)
	local bool_to_number = { [true] = 1, [false] = 0 }
	local file,err = io.open(data_file, "w")
	if err then
		vlc.msg.err(prefix .. "unable to open data file.. exiting")
		vlc.deactivate()
		return
	else
		for path,item in pairs(store) do
			file:write(path .. "\t")
			file:write(item.rating .. "\t")
			file:write(bool_to_number[item.locked] .. "\n")
		end
	end
	io.close(file)
end

-- -- Listeners -- --

function update_current_playing(fullpath)
	local path = basename(fullpath)
	vlc.msg.info(prefix .. "updating playing: " .. path)

	-- decrement rating, if not locked, to prevent viewed items
	-- from repeating until all higher rated items have been viewed
	if store[path].locked == false then
		if store[path].rating > 1 then
			store[path].rating = store[path].rating - 1
			playlist[fullpath] = store[path].rating
			save_data_file()
		end
	end

	update_gui()
end

function input_changed()
	vlc.msg.info(prefix .. "input_changed!")
	local item = vlc.input.item()
	if item == nil then
		-- user clicked 'Stop'
		return
	end
	local fullpath = vlc.strings.decode_uri(item:uri())
	update_current_playing(fullpath)
end

function playing_changed()
	vlc.msg.info(prefix .. "playing_changed! status: " .. vlc.playlist.status())
end

function meta_changed() end

-- -- Queue implementation -- --
-- Idea from https://www.lua.org/pil/11.4.html

Queue = {}
function Queue.new ()
	return {first = 0, last = -1}
end

function Queue.enqueue (q, value)
	q.last = q.last + 1
	q[q.last] = value
end

function Queue.dequeue (q)
	if q.first > q.last then return nil end
	local value = q[q.first]
	q[q.first] = nil
	q.first = q.first + 1
	return value
end

function Queue.size(q)
	return q.last - q.first + 1
end

-- implements the fisher yates shuffle on the queue
-- based on the wikipedia page
function Queue.shuffle(q)
	local first = q.first
	local last = q.last
	if first > last then return end
	if first == last then return end
	for i=first,last-1 do
		local r = math.random(i,last-1)
		local temporary = q[i]
		q[i] = q[r]
		q[r] = temporary
	end
end
