# Remotes disconnection

* open a new remote connection in a new tab
* open another connection in another tab
* enter scroll mode
* kill all ssh processes

* also test the scrolling and searching. 
* test that the socket gets deleted every time.

# Bug

* open a local tab
* open a remote tab

* close the session
* open the same session with --clean
* select the remote tab
* close again the session
* open the session without --clean flag (the user input won't enter insert mode)

# Bug

* open a tab remote
* kill the ssh process
* from the remote tab with the ssh killed, try to open another remote tab (you won't be able to insert the //)

# Create issue during session load

* in a session file, replace a tab_id with a non existing tab_id

# Layout panic and restore

* lots of tests to stress it.

# Session error loading

* create a session with an invalid shell
* create a session with an invalid syntax
* create a session with an invalid shortcut action or mode
* they should all result in a panic and vesper closing
