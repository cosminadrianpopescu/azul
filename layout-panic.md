* check all the terminals. the ones that don't have a valid chanel and that are not remote (remote_info == nil) should be removed from the terminals list
* check again the remaining terminals. 
* if all the terminals are with valid buffers and valid windows, then nothing should happen. 

* however, if any of them is not, we should try a recovery, as follows:
    - save the current history in a temporary location
    - close all windows and buffers, without killing the channels (keep the channels opened)
    - starting from the previously saved session, recreate each buffer, window, split or floating window and then instead of opening a new pane there, just open the buffer with the corresponding channel
    - if the terminal is remote, then as in restore_session, just create the disconnected buffer.
