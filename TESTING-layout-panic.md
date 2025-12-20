# Testing Layout Panic Recovery

## Test Scenarios

### 1. Invalid Channel Detection
**Setup**: Create terminals and manually invalidate a channel
**Expected**: Terminal should be removed from the list if not remote

### 2. Invalid Buffer Detection
**Setup**: Create terminals and delete a buffer
**Expected**: Layout panic should be triggered and recovery initiated

### 3. Invalid Window Detection
**Setup**: Create terminals and close a window improperly
**Expected**: Layout panic should be triggered and recovery initiated

### 4. Remote Terminal Handling
**Setup**: Create remote terminals and trigger panic
**Expected**: Remote terminals should be preserved and recreated as disconnected

### 5. Mixed Scenario
**Setup**: Mix of local and remote terminals with some invalid states
**Expected**: 
- Invalid local terminals removed
- Remote terminals preserved
- Layout panic triggered if any remaining terminal has invalid buffer/window
- Recovery restores layout structure

## Manual Testing Steps

1. Start Vesper with multiple tabs and splits:
   ```bash
   vesper -a test-panic
   ```

2. Create a complex layout:
   - Open 3-4 tabs
   - Add splits in some tabs
   - Add floating windows

3. Trigger panic (simulate by manually corrupting state in debug mode)

4. Verify recovery:
   - Layout structure is preserved
   - All terminals are functional
   - Remote terminals show disconnected state

## Automated Testing

To add automated tests, create test cases in the test suite that:
1. Mock invalid channel states
2. Mock invalid buffer/window states
3. Verify cleanup_terminals() behavior
4. Verify recover_from_panic() behavior
5. Verify event triggering

## Debug Commands

To manually trigger recovery for testing:
```lua
:lua require('events').trigger_event('LayoutPanic')
```

To check terminal states:
```lua
:lua print(vim.inspect(require('vesper').get_terminals()))
```
