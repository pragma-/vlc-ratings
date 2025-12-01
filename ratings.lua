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
		version = "1.0.1",
		license = "MIT",
		shortdesc = "Ratings",
		description = "Rates items and shuffles playlists with a bias towards higher ratings.",
		author = "pragma",
		capabilities = {"playing-listener", "input-listener"}
	}
end

local help_html = [[
<h1 id="top">Welcome to the vlc-ratings extension!</h1>

<ol>
	<li><a href="#about">About</a>
	<li><a href="#playlist">Showing the "Ratings" column in the playlist</a>
	<li><a href="#rating">Rating an item</a>
	<li><a href="#shuffling">Shuffling the playlist using the ratings</a>
	<li><a href="#metadata">Caveat regarding using metadata</a>
	<li><a href="#issues">Reporting issues/bugs/feedback</a>
</ol>

<h3 id="about">About</h3>
The vlc-ratings extension can rate VLC playlist entries on a scale from 1 to 5, or from 1 to 10 (see Settings).
<p>
It can also shuffle your playlist, grouping entries of the same rating, with higher rated entries appearing
first. In other words, all entries rated 5 will be shuffled and then added to the playlist. Then
all entries rated 4 will be shuffled and added, and so on.
<p>
The rating data can be stored in a tab-delimited text file in your VLC user data directory or in the "Ratings"
metadata field for each item (if it's possible; see "Caveat regarding using metadata").

<p>On Windows, this is typically <b>C:/Users/youruser/AppData/Roaming/vlc/ratings.csv</b>. You may optionally view
or edit this file outside of VLC with a spreadsheet program or text editor.
<p>
This extension has been extensively tested with VLC 3.0.8 on Windows 10. It is currently untested on Linux and MacOS;
as far as I know it should behave as expected. Please report any issues you encounter.
<p>
<a href="#top">Back</a>
<h3 id="playlist">Showing the "Ratings" column in the playlist</h3>
The vlc-ratings extension can populate the "Ratings" column of the VLC playlist view. You may sort and shuffle
your playlist by this column!
<p>
To show VLC's playlist, go to VLC's <b>View</b> menu and click <b>Playlist</b> (or press <b>CTRL + L</b>).
To ensure the "Ratings" column is visible, right-click the "Title" column header and ensure "Rating" is
checked. You may drag-and-drop the column headers to rearrange them. You may click the headers to sort the
playlist by that column's data.
<p>
<a href="#top">Back</a>
<h3 id="rating">Rating an item</h3>
The vlc-ratings extension rates the currently playing item. To rate your items, first add them
to VLC's playlist. Then click 'Play'. The vlc-ratings dialog will update as each item starts
playing. Click a rating button from 1 through 10 to set a rating.  Click the same rating button again to toggle back to unrated.
<p>
Due to a limitation with VLC's extension interface, it is currently not possible to immediately
update the "Ratings" column in VLC's playlist view. But do not worry, the ratings are saved when you
toggle the rating buttons. You may click the "Refresh playlist" button in the vlc-ratings dialog to
update the playlist columns at any time. It is not necessary to do this after each rating; do this when you need to
sort the playlist, for example.
<p>
<a href="#top">Back</a>
<h3 id="shuffling">Shuffling the playlist using the ratings</h3>
You may shuffle your playlist using your ratings! The vlc-ratings dialog has a "Shuffle Playlist" button
and a mininum and maximum rating value. You may adjust the minimum and maximum rating values to filter
out undesirable ratings. For instance, to play only your favorite items, set the minimum value to 5 and
the maximum value to 5 (assuming your maximum rating is set to 5), then click the "Shuffle playlist" button.
<p>
<a href="#top">Back</a>
<h3 id="metadata">Caveat regarding using metadata</h3>
The VLC functions to update metadata fields for certain file types may not be implemented in your version of VLC.
This extension will attempt to update the rating metadata field when possible. Since it may not always be possible,
this extension will also write the rating information to a central datafile. This behavior may be controlled in the Settings.
I recommend leaving both methods enabled.
<p>
<a href="#top">Back</a>
<h3 id="issues">Reporting issues/bugs/feedback</h3>
If you find any issues or want to share feedback, please feel free to do so at
<a href="https://github.com/pragma-/vlc-ratings/issues">https://github.com/pragma-/vlc-ratings/issues</a>!
<p>
<a href="#top">Back</a>

]]

-- holds vlc-rating extension configuration variables
-- set default configuration
local config = {
	max_rating = 5,
	default_rating = 0,
	write_metadata = true,
	write_datafile = true,
	shuffle_min_rating = 0,
	shuffle_max_rating = 10,
	show_locked = false,
	show_reset_ratings = false,
	show_settings_default_rating = false
}

local playlist = {}          -- holds all music items form the current playlist
local store = {}             -- holds all music items from the database
local dialog                 -- main GUI interface
local prefix = "[ratings] "  -- prefix to log messages
local data_file = ""         -- path to data file

function activate()
	vlc.msg.info(prefix .. "Hello!")

	math.randomseed(os.time())

	data_file = vlc.config.userdatadir() .. "/ratings.csv"
	config_file = vlc.config.configdir() .. "/ratings.cfg"
	vlc.msg.info(prefix .. "using data file " .. data_file)
	vlc.msg.info(prefix .. "using config file " .. config_file)

	load_config_file()
	load_data_file()
	scan_playlist()
	update_playlist()
	show_gui()
end

function deactivate()
	vlc.msg.info(prefix ..  "Bye!")
	if dialog ~= nil then
		dialog:delete()
	end
end

function show_gui()
	dialog = vlc.dialog("Ratings")

	if config.show_locked then
		label_path = dialog:add_label("Press 'Play'!", 1, 1, 9)
		checkbox_locked = dialog:add_check_box("Rating Locked", false, 10, 1)
	else
		label_path = dialog:add_label("Press 'Play'!", 1, 1, 11)
	end

	local onclick_rateN = function(rating)
		return function()
			if config.show_locked then
				checkbox_locked:set_checked(true)
			end
			rate_current_item(rating)
		end
	end

	local indicator = 0
	local row = 3
	local col = 1
	label_indicator = {}

	for i=1,5 do
		label_indicator[indicator] = dialog:add_label("<b>&nbsp;&nbsp;</b>", col, row)
		indicator = indicator + 1
		col = col + 1
		dialog:add_button(i, onclick_rateN(i), col, row)
		col = col + 1
	end

	label_indicator[indicator] = dialog:add_label("<b>&nbsp;&nbsp;</b>", col, row)
	indicator = indicator + 1
	row = row + 1
	col = 1

	if config.max_rating == 10 then
		for i=1,5 do
			label_indicator[indicator] = dialog:add_label("<b>&nbsp;&nbsp;</b>", col, row)
			indicator = indicator + 1
			col = col + 1
			dialog:add_button(i+5, onclick_rateN(i+5), col, row)
			col = col + 1
		end
		label_indicator[indicator] = dialog:add_label("<b>&nbsp;&nbsp;</b>", col, row)
		indicator = indicator + 1
		row = row + 1
	end

	vlc.msg.info("added " .. indicator .. " indicators")
	dialog:add_label("<hr>", 1, row, 11, 1)
	row = row + 1

	dialog:add_label("Shuffle Min Rating:", 2, row)
	dropdown_min_rating = dialog:add_dropdown(4, row)
	dialog:add_label("Shuffle Max Rating:", 6, row)
	dropdown_max_rating = dialog:add_dropdown(8, row)
	dialog:add_button("Shuffle Playlist", onclick_shuffle_playlist, 10, row)
	row = row + 1

	dialog:add_label("<hr>", 1, row, 11, 1)
	row = row + 1

	dialog:add_button("Refresh Playlist", onclick_refresh_playlist, 2, row)

	if config.show_reset_ratings then
		dialog:add_button("Reset Unlocked Ratings", onclick_reset_unlocked_ratings, 4, row)
	end

	dialog:add_button("Settings", onclick_settings, 8, row)
	dialog:add_button("Help", onclick_help, 10, row)

	update_min_max_dropdowns()
	update_gui()
	dialog:show()
end

function update_min_max_dropdowns()
	local rating_values = {[0] = "Unrated"}
	for i=1,config.max_rating do
		rating_values[i] = i
	end

	if config.shuffle_max_rating > config.max_rating then
		config.shuffle_max_rating = config.max_rating
	end

	dropdown_min_rating:clear()
	-- add selected item as first item in dropdown
	dropdown_min_rating:add_value(rating_values[config.shuffle_min_rating], config.shuffle_min_rating)
	-- add rest of items
	for i=0,#rating_values do
		if i ~= config.shuffle_min_rating then
			dropdown_min_rating:add_value(rating_values[i], i)
		end
	end

	dropdown_max_rating:clear()
	-- add selected item as first item in dropdown
	dropdown_max_rating:add_value(rating_values[config.shuffle_max_rating], config.shuffle_max_rating)
	-- add rest of items
	for i=#rating_values,0,-1 do
		if i ~= config.shuffle_max_rating then
			dropdown_max_rating:add_value(rating_values[i], i)
		end
	end
end

function reset_rating_indicators()
	if config.max_rating <= 10 then
		for i = 0,5 do
			label_indicator[i]:set_text("<b>&nbsp;&nbsp;</b>")
		end
	end

	if config.max_rating == 10 then
		for i = 6,11 do
			label_indicator[i]:set_text("<b>&nbsp;&nbsp;</b>")
		end
	end
end

function update_rating_indicators(rating)
	if rating <= 5 then
		label_indicator[rating - 1]:set_text("<b><font color='green'>&lt;&lt;</font></b>")
		label_indicator[rating]:set_text("<b><font color='green'>&gt;&gt;</font></b>")
	else
		label_indicator[rating]:set_text("<b><font color='green'>&lt;&lt;</font></b>")
		label_indicator[rating + 1]:set_text("<b><font color='green'>&gt;&gt;</font></b>")
	end
end

function update_gui()
	local item = vlc.input.item()
	if item == nil then
		label_path:set_text("Press 'Play'!")
		return
	end

	local path = basename(vlc.strings.decode_uri(item:uri()))
	label_path:set_text(path)

	local rating = store[path].rating
	local meta_rating = read_meta()

	if meta_rating > 0 then
		vlc.msg.info(prefix .. path .. ": overriding cached rating " .. rating .. " with metadata rating " .. meta_rating)
		rating = meta_rating
		store[path].rating = meta_rating
		save_data_file()
	else
		vlc.msg.info(prefix .. path .. ": using cached rating " .. rating)
	end

	reset_rating_indicators()
	if rating > 0 then
		update_rating_indicators(rating)
	end

	if config.show_locked then
		checkbox_locked:set_checked(store[path].locked)
	end
end

function onclick_help()
	dialog:delete()
	dialog = vlc.dialog("Ratings Help")
	dialog:add_html(help_html, 1, 1, 9, 1)
	dialog:add_label(string.rep("&nbsp;", 200), 1, 2, 9, 1)
	dialog:add_button("OK", onclick_help_ok, 5, 3)
	dialog:show()
end

function onclick_help_ok()
	dialog:delete()
	dialog = nil
	show_gui()
end

function onclick_settings()
	dialog:delete()
	dialog = vlc.dialog("Ratings Settings")
	local row = 1
	dialog:add_label("Maximum rating", 3, row)
	settings_dropdown_maxrating = dialog:add_dropdown(4, row)
	row = row + 1

	if config.show_settings_default_rating then
		dialog:add_label("Default rating", 3, row)
		settings_dropdown_defrating = dialog:add_dropdown(4, row)
		row = row + 1
	end

	settings_checkbox_write_meta = dialog:add_check_box("Use metadata", false, 3, row)
	settings_checkbox_write_data = dialog:add_check_box("Use data file", false, 4, row)
	row = row + 1
	dialog:add_label(string.rep("&nbsp;", 80), 1, row, 6)
	row = row + 1
	dialog:add_button("Cancel", onclick_settings_cancel, 3, row)
	dialog:add_button("Save", onclick_settings_save, 4, row)
	update_settings_dialog()
	dialog:show()
end

function update_settings_dialog()
	settings_dropdown_maxrating:clear()
	if config.max_rating == 5 then
		settings_dropdown_maxrating:add_value(5, 5)
		settings_dropdown_maxrating:add_value(10, 10)
	else
		settings_dropdown_maxrating:add_value(10, 10)
		settings_dropdown_maxrating:add_value(5, 5)
	end

	local rating_values = {[0] = "Unrated"}
	for i=1,config.max_rating do
		rating_values[i] = i
	end

	if config.show_settings_default_rating then
		settings_dropdown_defrating:clear()
		settings_dropdown_defrating:add_value(rating_values[config.default_rating], config.default_rating)
		for i=0,#rating_values do
			if i ~= config.default_rating then
				settings_dropdown_defrating:add_value(rating_values[i], i)
			end
		end
	end

	settings_checkbox_write_meta:set_checked(config.write_metadata)
	settings_checkbox_write_data:set_checked(config.write_datafile)
end

function onclick_settings_save()
	config.max_rating = settings_dropdown_maxrating:get_value()

	if config.show_settings_default_rating then
		config.default_rating = settings_dropdown_defrating:get_value()
	end

	config.write_metadata = settings_checkbox_write_meta:get_checked()
	config.write_datafile = settings_checkbox_write_data:get_checked()
	save_config_file()
	dialog:delete()
	dialog = nil
	show_gui()
end

function onclick_settings_cancel()
	dialog:delete()
	dialog = nil
	show_gui()
end

function onclick_shuffle_playlist()
	local min = dropdown_min_rating:get_value()
	local max = dropdown_max_rating:get_value()

	-- sanity checks
	if min > max then
		min = max
	elseif max < min then
		max = min
	end

	local changed = false
	if config.shuffle_min_rating ~= min or config.shuffle_max_rating ~= max then
		changed = true
	end

	config.shuffle_min_rating = min
	config.shuffle_max_rating = max

	if changed then
		save_config_file()
		update_min_max_dropdowns()
	end

	randomize_playlist(min, max)
end

function onclick_refresh_playlist()
	scan_playlist()
	update_playlist()
end

function onclick_reset_unlocked_ratings()
	for fullpath,item in pairs(playlist) do
		local path = basename(fullpath)
		if store[path].locked == false then
			store[path].rating = config.default_rating
		end
	end
	save_data_file()
	update_playlist()
end

function close()
	vlc.deactivate()
end

function rate_current_item(rating)
	local path = label_path:get_text()
	local locked
	if config.show_locked then
		locked = checkbox_locked:get_checked()
	else
		locked = true
	end

	reset_rating_indicators()
	if store[path].rating == rating then
		vlc.msg.info(prefix .. "canceling rating")
		-- clicked same rating button, set to unrated
		store[path].rating = 0
	else
		vlc.msg.info(prefix .. "clicked rating " .. rating)
		-- set new rating
		update_rating_indicators(rating)
		store[path].rating = rating
		store[path].locked = locked
	end

	local fullpath = store[path].fullpath
	playlist[fullpath] = store[path].rating
	save_data_file()
	update_meta(rating)
end

function read_meta()
	if not config.write_metadata then
		return 0
	end

	if not vlc.item then
		vlc.msg.dbg(prefix .. "No item playing; skipping metadata read")
		return 0
	end

	local metas = vlc.item:metas()
	local rating = metas["rating"]
	if not rating then
		rating = 0
	end
	return rating
end

function update_meta(rating)
	if config.write_metadata then
		local item = vlc.input.item()
		if item == nil then
			vlc.msg.info(prefix .. "cannot set rating metadata when nothing is playing")
			return
		end
		vlc.msg.info(prefix .. "setting metadata 'Rating' to " .. rating)
		item:set_meta("rating", rating)
	end
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
	playlist = {}
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
			playlist[fullpath] = config.default_rating
			store[path] = {rating=config.default_rating, locked=false, fullpath=fullpath}
			changed = true
		end
	end

	-- save changes
	if changed then
		save_data_file()
	end
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
	vlc.playlist.stop()

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
	if value == nil or value == 0 then
		return false
	else
		return true
	end
end

function load_data_file()
	if not config.write_datafile then
		return
	end
	-- open file
	vlc.msg.info(prefix .. "Loading data from " .. data_file)
	local file,err = io.open(data_file, "r")
	store = {}
	if err then
		vlc.msg.warn(prefix .. "data file does not exist, creating...")
		file,err = io.open(data_file, "w")
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
	if not config.write_datafile then
		return
	end
	vlc.msg.info(prefix .. "Saving data to " .. data_file)
	local bool_to_number = { [true] = 1, [false] = 0 }
	local file,err = io.open(data_file, "w")
	if err then
		vlc.msg.err(prefix .. "unable to open data file.. exiting")
		vlc.deactivate()
		return
	else
		for path,item in pairs(store) do
			if item.rating > 0 then
				file:write(path .. "\t")
				file:write(item.rating .. "\t")
				file:write(bool_to_number[item.locked] .. "\n")
			end
		end
	end
	io.close(file)
end

function load_config_file()
	local saved_config
	-- open file
	vlc.msg.info(prefix .. "Loading config from " .. config_file)
	local file,err = io.open(config_file, "r")
	if err then
		vlc.msg.warn(prefix .. "config file does not exist, creating...")
		file,err = io.open(config_file, "w")
		if err then
			vlc.msg.err(prefix .. "unable to open config file: " .. err)
			vlc.deactivate()
			return
		end
	else
		-- file successfully opened
		local contents = file:read("*all")
		saved_config = parse_xml(contents)
	end
	io.close(file)

	-- override default config with saved config values
	if saved_config ~= nil then
		for key,value in pairs(saved_config) do
			if value == "true" then
				config[key] = true
			elseif value == "false" then
				config[key] = false
			elseif value:match("^%d+$") then
				config[key] = tonumber(value)
			else
				config[key] = value
			end
		end
	end
end

function save_config_file()
	vlc.msg.info(prefix .. "Saving config to " .. config_file)
	local file,err = io.open(config_file, "w")
	if err then
		vlc.msg.err(prefix .. "unable to open config file.. exiting")
		vlc.deactivate()
		return
	else
		local xml = dump_xml(config)
		file:write(xml,"\n")
	end
	io.close(file)
end

-- -- Listeners and helpers -- --

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

-- -- XML utilities -- --

function parse_xml(data)
  local tree = {}
  local stack = {}
  local tmp = {}
  local level = 0
  local op, tag, p, empty, val
  table.insert(stack, tree)
  local resolve_xml =  vlc.strings.resolve_xml_special_chars

  for op, tag, p, empty, val in string.gmatch(
	data,
	"[%s\r\n\t]*<(%/?)([%w:_]+)(.-)(%/?)>"..
	"[%s\r\n\t]*([^<]*)[%s\r\n\t]*"
  ) do
	if op=="/" then
	  if level>0 then
		level = level - 1
		table.remove(stack)
	  end
	else
	  level = level + 1
	  if val == "" then
		if type(stack[level][tag]) == "nil" then
		  stack[level][tag] = {}
		  table.insert(stack, stack[level][tag])
		else
		  if type(stack[level][tag][1]) == "nil" then
			tmp = nil
			tmp = stack[level][tag]
			stack[level][tag] = nil
			stack[level][tag] = {}
			table.insert(stack[level][tag], tmp)
		  end
		  tmp = nil
		  tmp = {}
		  table.insert(stack[level][tag], tmp)
		  table.insert(stack, tmp)
		end
	  else
		if type(stack[level][tag]) == "nil" then
		  stack[level][tag] = {}
		end
		stack[level][tag] = resolve_xml(val)
		table.insert(stack,  {})
	  end
	  if empty ~= "" then
		stack[level][tag] = ""
		level = level - 1
		table.remove(stack)
	  end
	end
  end
  return tree
end

function dump_xml(data)
  local level = 0
  local stack = {}
  local dump = ""
  local convert_xml = vlc.strings.convert_xml_special_chars

  local function parse(data, stack)
	local data_index = {}
	local k
	local v
	local i
	local tb

	for k,v in pairs(data) do
	  table.insert(data_index, {k, v})
	  table.sort(data_index, function(a, b)
		return a[1] < b[1]
	  end)
	end

	for i,tb in pairs(data_index) do
	  k = tb[1]
	  v = tb[2]
	  if type(k)=="string" then
		dump = dump.."\n"..string.rep(" ", level).."<"..k..">"
		table.insert(stack, k)
		level = level + 1
	  elseif type(k)=="number" and k ~= 1 then
		dump = dump.."\n"..string.rep(" ", level-1).."<"..stack[level]..">"
	  end

	  if type(v)=="table" then
		parse(v, stack)
	  elseif type(v)=="string" then
		dump = dump..(convert_xml(v) or v)
	  elseif type(v)=="number" then
		dump = dump..v
	  else
		dump = dump..tostring(v)
	  end

	  if type(k)=="string" then
		if type(v)=="table" then
		  dump = dump.."\n"..string.rep(" ",level-1).."</"..k..">"
		else
		  dump = dump.."</"..k..">"
		end
		table.remove(stack)
		level = level - 1

	  elseif type(k)=="number" and k ~= #data then
		if type(v)=="table" then
		  dump = dump.."\n"..string.rep(" ",level-1).."</"..stack[level]..">"
		else
		  dump = dump.."</"..stack[level]..">"
		end
	  end
	end
  end
  parse(data, stack)
  return dump
end

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
