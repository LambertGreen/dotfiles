" Lambert's VIMRC

" Environment specific settings {{{
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
" }}}
" Editor {{{
set exrc " allows sourcing of cwd .vimrc
set secure " adds some security restrictions for using excr option
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
set updatetime=500 " short time recommended by author of vim-gutter as this setting affects its update time
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
" General mappings {{{
if !exists("vimpager")
  let g:mapleader="\<Space>"
endif
" Copy/paste into system clipboard
vmap <leader>y "+y
vmap <leader>d "+d
nmap <leader>p "+p
nmap <leader>P "+P
vmap <leader>p "+p
vmap <leader>P "+P
" Replace word under cursor
:nnoremap <Leader>s :%s/\<<C-r><C-w>\>//g<Left><Left>
" Toggle highlighting
:nnoremap <silent><expr> <Leader><Leader>h (&hls && v:hlsearch ? ':nohls' : ':set hls')."\n"
" Go-to-tag by default show list if there are more than one matches
nnoremap <C-]> g<C-]>
" Yank buffer absolute path into clipboard (/something/src/foo.txt)
nnoremap <leader>yf :let @+=expand("%:p")<CR>
" }}}
" Window management {{{
" Window selection
:noremap <C-j> <C-w>j
:noremap <C-k> <C-w>k
:noremap <C-h> <C-w>h
:noremap <C-l> <C-w>l
" Jump to QuickFix window
nnoremap <leader>co :copen<CR>
" }}}
" NERDTree mappings {{{
" Open NERD
nmap <Leader>n :NERDTreeToggle<CR>
" Open NERD with current file highlighted
nmap <Leader>N :NERDTreeFind<CR>
" }}}
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
" Rg but wait for input before, so that next step can be a filter on results
nmap <leader>G :Rg
" Commands selection
nmap <leader>c :Commands<CR>
" }}}
" Make mappings {{{
nnoremap <leader>m :Make<CR>
" }}}
" ALE mappings {{{
nnoremap <leader>aj :ALENext<CR>
nnoremap <leader>ak :ALEPrevious<CR>
" }}}
" CurtineIncSw mappings {{{
" Swtich to implementation/header
nnoremap <leader>a :call CurtineIncSw()<CR>
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
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-fugitive'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-repeat'
    Plug 'tpope/vim-obsession'
    Plug 'tpope/vim-vinegar'
    Plug 'tpope/vim-dispatch'
    Plug 'tpope/vim-unimpaired'

    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    " FZF settings {{{
    if executable('fd')
        let $FZF_DEFAULT_COMMAND = 'fd --type f'
    endif
    " }}}

    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
    Plug 'Xuyuanp/nerdtree-git-plugin'

    Plug 'vim-airline/vim-airline'
    " Airline settings {{{
    let g:airline_powerline_fonts = 1
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#ale#enabled = 1
    " }}}
    Plug 'vim-airline/vim-airline-themes'
    Plug 'airblade/vim-gitgutter'
    Plug 'flazz/vim-colorschemes'
    Plug 'joshdick/onedark.vim'
    Plug 'tomasiser/vim-code-dark'

    Plug 'sheerun/vim-polyglot'
    Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
    Plug 'Raimondi/delimitMate'
    Plug 'ludovicchabant/vim-gutentags'
    " Gutentags settings {{{
    let g:gutentags_project_root = ['.root', '.svn', '.git', '.hg', '.project']
    let g:gutentags_ctags_tagfile = '.tags'
    let g:gutentags_cache_dir = expand('~/.cache/tags')
    " }}}
    Plug 'SirVer/ultisnips'
    " Ultisnips settings {{{
    let g:UltiSnipsExpandTrigger="<c-j>"
    " }}}
    Plug 'honza/vim-snippets'
    Plug 'w0rp/ale'
    " ale settings {{{
    let g:ale_sign_error = '✘'
    let g:ale_sign_warning = '⚠'
    " }}}

    " In probation
    Plug 'ericcurtin/CurtineIncSw.vim'
    Plug 'andymass/vim-matchup'
    Plug 'rhysd/vim-clang-format'

    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'nfvs/vim-perforce'
    Plug 'neomake/neomake'
    Plug 'will133/vim-dirdiff'
    Plug 'majutsushi/tagbar'
    Plug 'easymotion/vim-easymotion'
    Plug 'wincent/terminus'
    Plug 'tfnico/vim-gradle'

    Plug 'romgrk/winteract.vim'
    Plug 'sjl/gundo.vim'

    " Not often used
    Plug 'severin-lemaignan/vim-minimap'

    " Subject to removal
    Plug 'editorconfig/editorconfig-vim'
    Plug 'mileszs/ack.vim'

" Unused plugins {{{
"   Plug 'cohama/lexima.vim'            " had runaway insert issues!
"   Plug 'vim-syntastic/syntastic'      " superceded by ale?
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
" Local settings {{{
" Check machine specific local config
execute "silent! source ~/.vimrc_local"
" }}}
" Tips & Tricks {{{
" Sort includes/imports:
"   1. visual select
"   2. :%!sort -k2
" Command auto completion:
"   1. <C-d> to select option
" Copy from command results window
"   1. :redir @* | <command> | redir END
" Command buffer
"   1. <C-f> to access buffer: you can copy/paste/insert and use.
" List variables:
"   1. :let
" Change tabs to spaces
"   1. :retab
" Get previous highlight selection
"   1. gv
" Java: set include expression so that gf works for imports
" set includeexpr=substitute(v:fname,'\\.','/','g')
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
