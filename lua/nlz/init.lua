local M = {}

local uv = vim.loop

local server = vim.fn.serverlist()[1]
local nvimcmd = '<ESC>:e %{input}<CR><ESC>%{line}G'
local synctex_editor = 'nvim --server '..server
synctex_editor = synctex_editor.." --remote-send '"..nvimcmd.."'";

local viewer = [[start zathura -x "nvim --server  ]]..server
viewer = viewer..[[ --remote-send \\"]]..nvimcmd..[[\\" "  %O %S]];
local pdflatex = 'pdflatex -file-line-error -synctex=1 -interaction=nonstopmode -shell-escape'

local previewers = {
    ["zathura"] = 'start zathura -x "'..synctex_editor..'" %O %S'
}

-- TODO add a 'builders' table to choose the building program instead of the
-- default pdflatex.

function M.setup(config)
    M.msg = {}
    M.running = false
    M.opts = {}
    M.opts.previewer = config.previewer or 'zathura'
    M.opts.viewer = previewers[M.opts.previewer]
    -- set M.latexmk_cfg as the value of the -e option to latexmk.
    M.latexmk_cfg = '$pdf_previewer = qq['..M.opts.viewer..'];'
    M.latexmk_cfg = M.latexmk_cfg..'$pdflatex = qq['..pdflatex..'];'
    M.latexmk_cfg = M.latexmk_cfg..'$pdf_mode=1; $pdf_update_method=1;'
    return M
end

-- Safely close a handle.
local function safe_close(handle)
    if not handle:is_closing() then
        handle:close()
    end
end

-- Fill the quickfix list with the output of latexmk
-- TODO: add some sort of filtering to only include errors and relevant info.
local function set_qf()
    vim.fn.setqflist({}, 'r', {title = 'Build Errors', lines = M.msg})
end

local function onread(err, data)
    if err then
        print('ERROR: ', err)
        -- TODO handle err
    end
    if data then
        local vals = vim.split(data, "\n")
        for _, d in pairs(vals) do
            if d == "" then goto continue end
            table.insert(M.msg, d)
            --print(d)
            ::continue::
        end
        vim.schedule(set_qf)
    end
end


-- Compile the current TeX file using latexmk and automatically open the
-- previewer.
function M.compile()
    M.texfile = vim.fn.expand('%:p')
    M.stdout = uv.new_pipe(false)
    M.stderr = uv.new_pipe(false)
    local args = {'-e', M.latexmk_cfg, '-pdf', '-pvc', M.texfile}
    if M.opts.ignore_rc then table.insert(args, 1, '-norc') end
    print(M.latexmk_cfg)
    M.handle, M.pid = uv.spawn('latexmk', {
        args = args,
        stdio = {nil,M.stdout,M.stderr},
    },
        function ()
            M.stdout:read_stop()
            M.stderr:read_stop()
            safe_close(M.stdout)
            safe_close(M.stderr)
            safe_close(M.handle)
        end
    )

    uv.read_start(M.stderr, onread)
    uv.read_start(M.stdout, onread)
    M.running = true
end

-- Shutdown the "Build System"
-- Get the children of the latexmk process (the previewer)
-- Kill the previewers, then kill the latexmk process
function M.shutdown()
    M.zid = vim.api.nvim_get_proc_children(M.pid)
    for _, v in ipairs(M.zid) do
        uv.kill(v, 'sigint')
    end
    uv.kill(M.pid, 'sigint')
    M.running = false
end

-- Toggle between compiling and shutting down
function M.toggle_compile()
    if (M.running) then
        M.shutdown()
    else
        M.compile()
    end
end

-- SyncTeX forward search.
-- Get the current line, col, and file, then open the previewer to that
-- position.
function M.synctex()
    vim.cmd('normal! \\<LeftMouse>')
    local p = vim.api.nvim_win_get_cursor(0)
    local thisfile = vim.fn.expand('%:p')
    local pos = p[1]..':'..p[2]..':'..thisfile
    local pdffile = M.texfile:gsub('.tex', '.pdf')
    M.zhandle = uv.spawn('zathura',{
        args= {'--synctex-forward', pos, pdffile},
        stdio = nil
    },
        nil
    )
    vim.cmd('redraw')
end


-- User Commands
vim.api.nvim_create_user_command(
    'BuildPdf', M.compile,
    {bang = true, desc = 'Build a PDF from the LaTeX file.'}
)

vim.api.nvim_create_user_command(
    'SyncTex', M.synctex,
    {bang = true, desc = 'Highligh current line in the PDF.'}
)

return M
