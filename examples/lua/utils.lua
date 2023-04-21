local function paste_from_clipboard()
    local f = io.open("/tmp/clipboard", "r")
    if f == nil then
        return
    end
    require('azul').send_to_current(f:read("*all"))
    f:close()
end

local function paste()
    require('azul').send_to_current(vim.fn.getreg(0))
end

return {
    paste_from_clipboard = paste_from_clipboard,
    paste = paste,
}
