# Layout Panic Recovery Implementation

## Overview
Implemented a layout panic recovery system that detects and recovers from invalid terminal states in Vesper.

## Changes Made

### 1. core.lua - cleanup_terminals()
**Location**: Line ~330

**Implementation**:
- Filters out terminals without valid channels (unless they are remote)
- Checks remaining terminals for invalid buffers or windows
- Triggers `LayoutPanic` event when issues are detected

**Logic**:
```lua
-- Step 1: Remove terminals without valid channels that are not remote
terminals = vim.tbl_filter(function(t)
    local has_valid_channel = t.term_id ~= nil and vim.api.nvim_get_chan_info(t.term_id).id ~= nil
    local is_remote = t.remote_info ~= nil
    return has_valid_channel or is_remote
end, terminals)

-- Step 2: Check if any remaining terminals have invalid buffers or windows
local layout_panic = false
for _, t in pairs(terminals) do
    local buf = funcs.get_real_buffer(t)
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(t.win_id) then
        layout_panic = true
        break
    end
end

if layout_panic then
    EV.trigger_event('LayoutPanic')
end
```

### 2. session.lua - recover_from_panic()
**Location**: Before `return M` statement

**Implementation**:
- Saves current layout to temporary file
- Closes all terminals and buffers
- Restores layout from saved state
- Cleans up temporary file

**Process**:
1. Save layout to temp file using `M.save_layout()`
2. Suspend Vesper operations with `core.suspend()`
3. Stop all terminal jobs and delete buffers
4. Close all windows except one
5. Restore layout from temp file with `M.restore_layout()`
6. Resume Vesper operations with `core.resume()`
7. Clean up temp file

**Event Handler**:
```lua
EV.persistent_on({'LayoutPanic'}, function()
    M.recover_from_panic()
end)
```

## How It Works

1. **Detection**: `cleanup_terminals()` is called periodically and checks:
   - If terminals have valid channels (for non-remote terminals)
   - If all terminals have valid buffers and windows

2. **Trigger**: When invalid state is detected, `LayoutPanic` event is triggered

3. **Recovery**: The event handler calls `recover_from_panic()` which:
   - Saves the current layout structure
   - Cleans up all invalid state
   - Recreates the layout with fresh terminals

4. **Remote Handling**: Remote terminals are preserved in the filtered list and recreated as disconnected terminals during restore

## Notes

- Neovim doesn't support reattaching buffers to existing channels, so recovery creates new terminals
- Remote terminals are handled specially - they're recreated as disconnected and can be reconnected manually
- The recovery is automatic and transparent to the user
- Original terminal content is lost, but layout structure is preserved
