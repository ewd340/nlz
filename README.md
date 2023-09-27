# NLZ (Neovim + Latexmk + Zathura)

This is a simple neovim lua plugin with a simple goal: compile `.tex` files to
generate `.pdf` documents easily. All while supporting `SyncTeX`

## Install

Using [vim-plug](https://github.com/junegunn/vim-plug) for example:

```
Plug 'ewd340/nlz'
```

(TODO: add other common ways to install, such as _dein_, _packer_, _lazy.nvim_,
etc)

## Usage

Just add this to you neovim configuration:

```
local nlz = require('nlz').setup{}
local nlz_keymap_opts = {silent = true, remap = false}
vim.keymap.set('n', '<F9>', nlz.toggle_compile, nlz_keymap_opts)
vim.keymap.set('n', '<F7>', nlz.synctex, nlz_keymap_opts)
vim.keymap.set('n', '<C-LeftMouse>', nlz.synctex, nlz_keymap_opts)
```

(TODO: More details about the configuration and the keymaps.)
