" Set noshowmode since we are using lightline.vim for status
set noshowmode
set number
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4 " makes the spaces feel like real tabs<Paste>
set autoread
set cursorline

" Set CtrlP config
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
set wildignore+=*/tmp/*,*.so,*.swp,*.zip

" YCM config
" let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'

" Markdown config
let g:markdown_fenced_languages = ['html', 'python', 'bash=sh']

" NERDTree config
map <silent> <C-n> :NERDTreeFocus<CR>
let g:NERDTreeIndicatorMapCustom = {
    \ "Modified"  : "✹",
    \ "Staged"    : "✚",
    \ "Untracked" : "✭",
    \ "Renamed"   : "➜",
    \ "Unmerged"  : "",
    \ "Deleted"   : "✖",
    \ "Dirty"     : "✗",
    \ "Clean"     : "✔︎",
    \ 'Ignored'   : '☒',
    \ "Unknown"   : "?"
    \ }

" Clang format config
let g:clang_format#auto_format = 0
let g:clang_format#style_options = {
      \ "Standard" : "C++11",
      \ "AllowShortIfStatementsOnASingleLine" : "true",
      \ "AlwaysBreakTemplateDeclarations" : "true",
      \ "AccessModifierOffset" : -4
      \ }
autocmd FileType cpp, ClangFormatAutoEnable

" Set airline fonts
let g:airline_powerline_fonts = 1
" let g:airline_theme = 'onedark'
let g:airline_theme = 'codedark'
let g:airline#extensions#tabline#enabled = 1

" Ack/Ag config
if executable('ag')
  let g:ackprg = 'ag --vimgrep'
endif
cnoreabbrev ag Ack                                                                           
cnoreabbrev aG Ack                                                                           
cnoreabbrev Ag Ack                                                                           
cnoreabbrev AG Ack  

"setup vim-plug {{{

  "Note: install vim-plug if not present
  if empty(glob('~/.config/nvim/autoload/plug.vim'))
    silent !curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall
  endif

  "Note: Skip initialization for vim-tiny or vim-small.
  if !1 | finish | endif
  if has('vim_starting')
    set nocompatible               " Be iMproved
    " Required:
    call plug#begin()
  endif

"}}}

call plug#begin()
    Plug 'airblade/vim-gitgutter'
	Plug 'ctrlpvim/ctrlp.vim'
"	Plug 'honza/vim-snippets'
	Plug 'joshdick/onedark.vim'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'mileszs/ack.vim'
    Plug 'rhysd/vim-clang-format'
    Plug 'romgrk/winteract.vim'
	Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
"	Plug 'SirVer/ultisnips'
    Plug 'sjl/gundo.vim'
    Plug 'sheerun/vim-polyglot'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'tomasiser/vim-code-dark'
	Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-fugitive'
	Plug 'tpope/vim-surround'
    Plug 'tpope/vim-obsession'
"    Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
	Plug 'vim-airline/vim-airline'
	Plug 'vim-airline/vim-airline-themes'
    Plug 'vim-syntastic/syntastic'
    Plug 'Xuyuanp/nerdtree-git-plugin'
call plug#end() " Initialize plugin system 

"colorscheme onedark
"colorscheme codedark
