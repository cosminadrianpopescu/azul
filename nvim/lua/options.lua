local M = {
    workflow = 'vesper',
    modifier = '<C-s>',
    link_floats_with_tabs = false,
    shell = nil,
    mouse = "a",
    cmdheight = 0,
    editor = nil,
    theme = 'dracula',
    termguicolors = true,
    scrollback = 2000,
    clipboard = "unnamedplus",
    encoding = "utf-8",
    hide_in_passthrough = false,
    passthrough_escape = '<C-\\><C-s>',
    modifer_timeout = 500,
    use_cheatsheet = true,
    float_pane_title = ':term_title:',
    tab_title = 'Tab :tab_n:',
    use_dressing = true,
    opacity = 0,
    use_lualine = true,
    show_welcome_message = true,
    auto_start_logging = false,
    modes_cheatsheet_position = 'bottom',
    term = 'st-256color',
    autosave = 'always',
    autosave_location = nil,
    undo_restore_cmd = 'cat',
}

M.set_option = function(key, value)
    M[key] = value
end

return M;
