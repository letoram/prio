pRio - Plan9- Rio like Window Manager for Arcan

About
=====
This project sprung into life as part of a discussion on how far you could
get in a short- time frame (two hours was the initial limit) mimicking the
window management style of a pre-existing WM (rio from plan9 was selected)
with some minimal script re-use for basic input (keymaps / mouse gestures)

It has since been cleaned up and documented somewhat, but it's in what you
might call an 'unpolished state'. For more information, you can also check
out the [blog post](https://arcan-fe.com/2017/04/17/one-night-in-rio-vacation-photos-from-plan9).

It is intended as a learning tool and an experiment platform in situations
where [durden](https://github.com/letoram/durden) would be a bit too much.

Licensing
=====
Prio is licensed in the 3-clause BSD format that can be found in the LICENSE file.

The included terminal font, Hack-Bold is (c) Chris Simpkins
and licensed under the Apache-2.0 license.

The included UI font, designosaur, is provided free (cc-by 3.0 attribution)
by Archy Studio, http://www.archystudio.com

The included fallback font, Emoji-One, is provided free (cc-by 4.0 attribution)
by http://emojione.com

Configuration
=====
Modify config.lua to change default behavior when it comes to mouse cursor
scale factor, window behavior defaults, fonts, keyboard layout file/repeat
and so on.

Modify keybindings.lua to add, change or disable keyboard shortcuts. Check
out the tests/interactive/eventtest appl in the arcan repository for a way
to quickly see what symbols etc. a press would result in on your keyboard.

Modify shaders.lua to change visual behavior for the wallpaper, the window
border and so on.

Modify uifx.lua to tune animations on certain events or just redirect the
event hook in config.lua to get rid of them entirely.

The autorun.lua script will be executed during startup. By default, it will
do nothing, but you can add scripts to create static imagery, dynamic video
playback, terminal groups or dedicated listening points that can be used by
other data sources. For instance, calling:

    prio_new_listen_window("statusbar", 0, VRESH - 32, VRESW, 32, {
        force_size = true});

Would allocate a connection point with the name statusbar, allowing another
program to set ARCAN\_CONNPATH=statusbar, connect and draw within the lower
bottom part of the display. Note that in a multi-user or hostile setup, you
face the risk of others racing and man-in-the-middle grabbing the connpath.

The last argument is a table of boolean / string toggles that control input
response, decorations and resizing behaviors. The accepted fields right now
are:

 shader          : string  (see shaders.lua for available values)
 tab\_block      : boolean (tab decorations won't be drawn)
 force\_size     : boolean (will ignore client resize requests)
 autocrop        : boolean (if force-size: true, scales texture coordinates)
 no\_decor       : boolean (don't draw borders)
 no\_mouse       : boolean (disable mouse handlers)
 select\_block   : boolean (can't be selected)
 delete\_protect : boolean (can't be deleted or hidden)
 overlay         : number  (set overlay order)
 reconnect       : boolean (re-open or re-launch connection on failure)

Startup
=====
Run arcan like normal, e.g. arcan /path/to/prio or, to try things out if
already using durden (or another instance of prio) arcan\_lwa /path/to/prio

If you havn't built/setup arcan already, it's a bit more complicated. Refer
to the corresponding README.md in the repository at:
https://github.com/letoram/arcan

Limitations
=====
Advanced Arcan features like client-side decorations, dynamic icons, global
file open/close, state transfers, sharing, streaming, recording and others,
have all been excluded. This also covers advanced clipboards, touchpads and
game devices. These features should be easy enough to lift from durden that
anyone who wants them should have little trouble doing so.

There is also no consideration for the complexity that comes with multiple
displays, though durden display.lua could be merged with some minor effort.
It will likely gain this feature in the long run, but solved in a different
way than in Durden (to avoid the rendertarget- indirection cost) but engine
API is missing a few things for that to be workable right now.

Input has also received little love, keybindings.lua can be edited in order
to bind to visible (and hidden) menu paths, but there is no support for the
more advanced input cases.

Use (default)
=====
Some features are only exposed over the keyboard, check keybindings.lua

 * Spawning Terminal Group: Right click on the background, select new, then
   click in the upper-left corner where the window should be positioned and
   move the selection region to match the desired size. Left-click confirms
   while right-click cancels.

 * Resize/Movement:
   With the mouse cursor over the border area, left-click + drag to resize.
   With the mouse cursor over a tab button, left-click + drag to move.
   Drag the window to the edge of the screen to auto-size/position to cover
   the whole of the dominant axis and half of the other. By double-clicking
   the tab button, you toggle between maximized and normal window size.

 * Destroying Windows: Bring up the background menu, pick destroy and click
   on the window that should be destroyed. If there are more windows in the
   group, only the selected one will be dropped. If that is the controlling
   terminal of the group, this will likely cascade.

 * The icon in the decoration can be left-clicked to switch between windows
   in the terminal group, and right-clicked for a context menu for controls
   like input locking and audio.

 * Drag a window to an edge of the screen to demi-maximize, doubleclick the
   tab to maximize/restore.

Hacking
======

This project is meant as a basis for playing around with your own ideas, so
don't expect much in terms of support or development outside possible fixes
every now and then. Idle / Check IRC on #arcan @ irc.freenode.net.
