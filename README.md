# vlc-ratings
Ratings extension for VLC media player

# About
The vlc-ratings extension can rate VLC playlist entries on a scale from 1 to 5, or from 1 to 10 (see Settings).

!(screenshot)[screenshots/rate5.png]

!(screenshot)[screenshots/rate10.png]

It can also shuffle your playlist, grouping entries of the same rating, with higher rated entries appearing
first. In other words, all entries rated 5 will be shuffled and then added to the playlist. Then
all entries rated 4 will be shuffled and added, and so on.

The rating data can be stored in a tab-delimited text file in your VLC user data directory or in the "Ratings"
metadata field for each item (if it's possible; see "Caveat regarding using metadata").

On Windows, this is typically `C:/Users/youruser/AppData/Roaming/vlc/ratings.csv`. You may optionally view
or edit this file outside of VLC with a spreadsheet program or text editor.

This extension has been extensively tested with VLC 3.0.8 on Windows 10. It is currently untested on Linux and MacOS;
as far as I know it should behave as expected. Please report any issues you encounter.

# Showing the "Ratings" column in the playlist
The vlc-ratings extension can populate the "Ratings" column of the VLC playlist view. You may sort and shuffle
your playlist by this column!

To show VLC's playlist, go to VLC's _View_ menu and click _Playlist_ (or press `CTRL` + `L`).
To ensure the "Ratings" column is visible, right-click the "Title" column header and ensure "Rating" is
checked. You may drag-and-drop the column headers to rearrange them. You may click the headers to sort the
playlist by that column's data.

!(screenshot)[screenshots/playlist.png]

# Rating an item
The vlc-ratings extension rates the currently playing item. To rate your items, first add them
to VLC's playlist. Then click 'Play'. The vlc-ratings dialog will update as each item starts
playing. Click a rating button from 1 through 10 to set a rating.  Click the same rating button again to toggle back to unrated.

Due to a limitation with VLC's extension interface, it is currently not possible to immediately
update the "Ratings" column in VLC's playlist view. But do not worry, the ratings are saved when you
toggle the rating buttons. You may click the "Refresh playlist" button in the vlc-ratings dialog to
update the playlist columns at any time. It is not necessary to do this after each rating; do this when you need to
sort the playlist, for example.

# Shuffling the playlist using the ratings
You may shuffle your playlist using your ratings! The vlc-ratings dialog has a "Shuffle Playlist" button
and a mininum and maximum rating value. You may adjust the minimum and maximum rating values to filter
out undesirable ratings. For instance, to play only your favorite items, set the minimum value to 5 and
the maximum value to 5 (assuming your maximum rating is set to 5), then click the "Shuffle playlist" button.

# Caveat regarding using metadata
The VLC functions to update metadata fields for certain file types may not be implemented in your version of VLC.
This extension will attempt to update the rating metadata field when possible. Since it may not always be possible,
this extension will also write the rating information to a central datafile. This behavior may be controlled in the Settings.

