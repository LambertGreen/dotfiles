" Lambert's VIMRC

if !has('nvim')
    " Get the defaults that most users want.
    source $VIMRUNTIME/defaults.vim
endif

" ConEmu specific config {{{
" https://conemu.github.io/en/VimXterm.html
if has('win32') && !has("gui_running") && !empty($ConEmuBuild)
    if has('nvim')
        " Enable 256 colors
        set termguicolors
    else
        set term=xterm
        set t_Co=256
        let &t_AB="\e[48;5;%dm"
        let &t_AF="\e[38;5;%dm"
        " Fix BS key
        inoremap <Char-0x07F> <BS>
        nnoremap <Char-0x07F> <BS>
        cnoremap <Char-0x07F> <BS>
        " Enable arrow keys in insert mode
        " Keycode is discoverable by typing in Vim:-
        "   CTRL-V and press arrow key
        set t_ku=[A
        set t_kd=[B
        set t_kl=[D
        set t_kr=[C
        " Alternative method that I was trying:
        " let &t_kb = nr2char(127)
        " let &t_kD = "^[[3~"
    endif
endif
" }}}
" Editor {{{
set number
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4 " makes the spaces feel like real tabs<Paste>
set autoread
set backspace=indent,eol,start
set nocursorline
set hidden " allows switching from a buffer that has unwritten changes
set mouse=a " enable mouse suppport in all modes
set listchars=tab:>-,trail:~,extends:>,precedes:<
set list
set wildmenu
set wildmode=longest,list,full
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
" More natural window opening positions
set splitbelow
set splitright
" Show trailing white-space
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
" }}}
" Os Platform specifics {{{
if has('win32') && !has('nvim')
    set runtimepath=~/.vim,$VIMRUNTIME
    set viminfofile=~/.viminfo " To force win-vim to use dot viminfo
endif
let $VIMHOME = $HOME."/.vim"
" Set swap/backup/undo to global dir rather working dir
set backup
set undofile
set swapfile
set backupdir=$VIMHOME/backup/
if !isdirectory(&backupdir)
    call mkdir(&backupdir, "p", 0700)
endif
set directory=$VIMHOME/swap/
if !isdirectory(&directory)
    call mkdir(&directory, "p", 0700)
endif
set undodir=$VIMHOME/undo/
if !isdirectory(&undodir)
    call mkdir(&undodir, "p", 0700)
endif
" }}}
" Keyboard bindings/mappings {{{
if !exists("vimpager")
  let g:mapleader="\<Space>"
endif
" FZF mappings {{{
" Git files selection
nmap <leader>f :GFiles<CR>
" All files selection
nmap <leader>F :Files<CR>
" Buffers selection
nmap <leader>b :Buffers<CR>
" History selection
nmap <leader>h :History<CR>
" Command history selection
nmap <leader>: :History:<CR>
" Search history selection
nmap <leader>/ :History/<CR>
" Tags in current buffer selection
nmap <leader>t :BTags<CR>
" Tags selection
nmap <leader>T :Tags<CR>
" Lines in current buffer selection
nmap <leader>l :BLines<CR>
" Lines selection
nmap <leader>L :Lines<CR>
" Rg
nmap <leader>g :Rg<CR>
" Commands selection
nmap <leader>c :Commands<CR>
" }}}
" Edit .vimrc
nmap <leader>v :e $MYVIMRC<CR>
" Replace word under cursor
:nnoremap <Leader>s :%s/\<<C-r><C-w>\>//g<Left><Left>
" Toggle highlighting
:nnoremap <silent><expr> <Leader><Leader>h (&hls && v:hlsearch ? ':nohls' : ':set hls')."\n"
" Swtich to implementation/header
map <F5> :call CurtineIncSw()<CR>
" Go-to-tag by default show list if there are more than one matches
nnoremap <C-]> g<C-]>
" Open NERD with F3
map <F2> :NERDTreeToggle<CR>
" Open NERD with current file highlighted, with F4
map <F3> :NERDTreeFind<CR>
" Yank file path to clipboard
 nnor <leader>yf :let @"=expand("%:p")<CR>    " Mnemonic: Yank File path
" }}}
" Functions {{{
fun! TrimWhitespace()
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:save)
endfun
" }}}
" Plugins {{{
" Native plugins {{{
if !has('nvim')
    " The matchit plugin makes the % command work better, but it is not backwards
    " compatible.
    " The ! means the package won't be loaded right away but when plugins are
    " loaded during initialization.
    if has('syntax') && has('eval')
      packadd! matchit
    endif
endif
" }}}
" Vim-Plug {{{
call plug#begin()
    " Frequently used
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'

    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }

    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'airblade/vim-gitgutter'

    Plug 'flazz/vim-colorschemes'
    Plug 'joshdick/onedark.vim'
    Plug 'tomasiser/vim-code-dark'

    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-fugitive'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-obsession'
    Plug 'tpope/vim-vinegar'

    Plug 'sheerun/vim-polyglot'
    Plug 'rhysd/vim-clang-format'
    Plug 'ludovicchabant/vim-gutentags'

    Plug 'romgrk/winteract.vim'
    Plug 'sjl/gundo.vim'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'nfvs/vim-perforce'
    Plug 'w0rp/ale'
    Plug 'neomake/neomake'
    Plug 'will133/vim-dirdiff'
    Plug 'majutsushi/tagbar'
    Plug 'easymotion/vim-easymotion'
    Plug 'wincent/terminus'
    Plug 'tfnico/vim-gradle'

    " Not often used
    Plug 'severin-lemaignan/vim-minimap'

    " Subject to removal
    Plug 'editorconfig/editorconfig-vim'
    Plug 'mileszs/ack.vim'
" Unused plugins {{{
"   Plug 'honza/vim-snippets'
"   Plug 'SirVer/ultisnips'
"   Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
"   Plug 'vim-syntastic/syntastic'
"   Plug 'Xuyuanp/nerdtree-git-plugin'
" }}}
call plug#end() " Initialize plugin system
" }}}
" }}}
" Plugins Config {{{
" Airline {{{
set noshowmode " Set noshowmode since we are using airline for status
set encoding=utf-8 " Needed to show patched powerline fonts correctly.
" NB: On Windows in a terminal the code page also has to be set using:
" $>chcp 65001
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
" }}}
" Ack/Ag/Grep {{{
if executable('ag')
    " Use ag over grep
    set grepprg=ag\ --nogroup\ --nocolor
    let g:ackprg = 'ag --vimgrep'
endif
cnoreabbrev ag Ack
cnoreabbrev aG Ack
cnoreabbrev Ag Ack
cnoreabbrev AG Ack
" }}}
" ALE {{{
let g:airline#extensions#ale#enabled = 1
" }}}
" FZF {{{
let $FZF_DEFAULT_COMMAND = 'fd --type f'
" }}}
" }}}
" Programming Lanuages {{{
" Markdown {{{
let g:markdown_fenced_languages = ['html', 'python', 'bash=sh']
" }}}
" }}}
" Theme {{{
set background=dark
colorscheme onedark
let g:airline_theme = 'onedark'
" }}}
" Check machine specific local config
execute "silent! source ~/.vimrc_local"

" Tips & Tricks {{{
" Sort includes/imports:
"   1. visual select
"   2. :%!sort -k2
" Command auto completion:
"   1. <C-d> to select option
" Copy from command results window
"   1. :refir @* | <command> | redir END
" Command buffer
"   1. <C-f> to access buffer: you can copy/paste/insert and use.
" List variables:
"   1. :let
" Change tabs to spaces
"   1. :retab
" Get previous highlight selection
"   1. gv
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
