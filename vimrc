" Lambert's VIMRC

" Environment specific settings {{{
if !has('nvim')
    if filereadable($VIMRUNTIME/"defaults.vim")
        source $VIMRUNTIME/"defaults.vim""
    endif
endif

" Terminal specific settings {{{
set termguicolors

if exists('$ITERM_PROFILE')
    if !has('nvim') && exists('$TMUX')
        " From https://github.com/square/maximum-awesome/pull/245/files
        let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]1337;CursorShape=1\x7\<Esc>\\"
        let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]1337;CursorShape=0\x7\<Esc>\\"

        let &t_8f = "\<Esc>[38:2:%lu:%lu:%lum"
        let &t_8b = "\<Esc>[48:2:%lu:%lu:%lum"
    else
        " From https://github.com/square/maximum-awesome/pull/245/files
        let &t_SI = "\<Esc>]1337;CursorShape=1\x7"
        let &t_EI = "\<Esc>]1337;CursorShape=0\x7"
    endif
end

if !has("gui_running") && !exists('$TMUX')
    " ConEmu specific config
    " https://conemu.github.io/en/VimXterm.html
    if !empty($ConEmuBuild) && !has('nvim')
        set term=xterm
        set t_Co=256
        let &t_AB="\e[48;5;%dm"
        let &t_AF="\e[38;5;%dm"
        " Enable arrow keys in insert mode
        " Keycode is discoverable by typing in Vim:-
        "   CTRL-V and press arrow key
        set t_ku=[A
        set t_kd=[B
        set t_kl=[D
        set t_kr=[C
        " Fix BS (Backspace) key
        " https://github.com/Maximus5/ConEmu/issues/641
        let &t_kb = nr2char(127)
        let &t_kD = "^[[3~"
    endif
endif
" }}}
" Vim's Inbuilt Terminal Settings {{{
" Set Powershell as default shell on Windows
" Disabling for now since it results in extra process spawns
" for git related functions i.e. vim->vimrin.exe->cmd.exe->powershell.exe
" if has("win32") || has("gui_win32")
"      if executable("PowerShell")
"         " Set PowerShell as the shell for running external ! commands
"         " http://stackoverflow.com/questions/7605917/system-with-powershell-in-vim
"         set shell=PowerShell
"         set shellcmdflag=-ExecutionPolicy\ RemoteSigned\ -Command
"         set shellquote=\"
"         " shellxquote must be a literal space character.
"         set shellxquote= " must be a literal space char
"    endif
" endif
"" }}}
" Fzf workaroud {{{
" Fzf issue on Windows: https://github.com/junegunn/fzf/issues/963
if has('win32') && $TERM == "xterm-256color"
    let $TERM=""
endif
" }}}
" }}}
" Editor {{{
set title
" Set title to the current working directory so that the vim
" instance can be found by project name in the OS window manager.
:let &titlestring=getcwd()
set number
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4 " makes the spaces feel like real tabs<Paste>
set autoread
set backspace=indent,eol,start
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
" Cusorline only in active window
augroup CursorLineOnlyInActiveWindow
  autocmd!
  autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
  autocmd WinLeave * setlocal nocursorline
augroup END
" Make VIM scream at edit time about accidental changes to buffers to readonly
" files
autocmd BufRead * let &l:modifiable = !&readonly
" Spell checking settings {{{
" markdown files
autocmd BufRead,BufNewFile *.md setlocal spell"
" git commits
autocmd FileType gitcommit setlocal spell
" enable word completion
set complete+=kspell
"
"" }}}
"" }}}
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
" Quick save
:nnoremap <Leader>s :update<CR>
" insert mode Emacs start/end of line style mapping
inoremap <C-a> <C-o>0
inoremap <C-e> <C-o>$
" Quick semi-colon at end of line
inoremap <C-;> <C-o>$;
" Toggle highlighting
:nnoremap <silent><expr> <Leader><Leader>h (&hls && v:hlsearch ? ':nohls' : ':set hls')."\n"
" Go-to-tag by default show list if there are more than one matches
nnoremap <C-]> g<C-]>
" Yank buffer absolute path into clipboard (/something/src/foo.txt)
nnoremap <leader>yf :let @+=expand("%:p")<CR>
" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! w !sudo tee > /dev/null %
" }}}
" Window management {{{
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
" terminal mode
tnoremap <C-w>n <C-\><C-n>
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l
" Quick open a terminal
if has('nvim')
    :nnoremap <leader>; :vs\|:term<CR>
else
    :nnoremap <leader>; :term<CR>
endif
" Jump to QuickFix window
nnoremap <leader>co :copen<CR>
" }}}
" Buffer management {{{
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>
nnoremap <leader>x :bdelete!<CR>
" }}}
" Maximizer mappings {{{
" Window zoom toggles
nnoremap <silent><C-w>z :MaximizerToggle<CR>
vnoremap <silent><C-w>z :MaximizerToggle<CR>gv
inoremap <silent><C-w>z <C-o>:MaximizerToggle<CR>
" }}}
" Winteract mappings {{{
" Activate interactive window resize mode
nnoremap <leader>w :InteractiveWindow<CR>
" }}}
" GitGutter mappings {{{
" Quick jumping to next/prev hunk
nnoremap <silent> <cr> :GitGutterNextHunk<cr>
nnoremap <silent> <backspace> :GitGutterPrevHunk<cr>
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
" Switch to alternate file e.g. implementation<->header
nnoremap <leader>a :call CurtineIncSw()<CR>
" }}}
" UndoTree mappings {{{
" Toggle undo tree
nnoremap <leader>u :UndotreeToggle<CR>
" }}}
" ClangFormat mappings {{{
nnoremap <leader><leader>f :ClangFormat<CR>
" }}}
" }}}
" Functions {{{
fun! TrimWhitespace()
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:save)
endfun
fun! FormatJson()
    :%!python -m json.tool
endfun
" }}}
" Auto commands {{{
" Remove trailing whitespace on save
autocmd BufWritePre * call TrimWhitespace()
" }}}
" Plugins {{{
" Install vim-plug if not already installed
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
call plug#begin()
" Frequently used {{{
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-fugitive'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-repeat'
    "Plug 'tpope/vim-obsession' Superceded by vim-startify which supports
    "session manangement
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
    Plug 'ryanoasis/vim-devicons'
"vim-devicons settings {{{
    let g:WebDevIconsUnicodeDecorateFolderNodes = 1
"}}}
    Plug 'Xuyuanp/nerdtree-git-plugin'

    Plug 'vim-airline/vim-airline'
    " Airline settings {{{
    let g:airline_powerline_fonts = 1
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#ale#enabled = 1
    " }}}
    Plug 'vim-airline/vim-airline-themes'
    Plug 'airblade/vim-gitgutter'

    " Color schemes
    Plug 'flazz/vim-colorschemes'
    Plug 'joshdick/onedark.vim'
    Plug 'tomasiser/vim-code-dark'
    Plug 'drewtempelmeyer/palenight.vim'
    Plug 'rakr/vim-one'
    Plug 'ayu-theme/ayu-vim'
    " ayu-vim settings {{{
    let ayucolor="light"  " for light version of theme
    "let ayucolor="mirage" " for mirage version of theme
    "let ayucolor="dark"   " for dark version of theme
    "" }}}
    Plug 'ntpeters/vim-airline-colornum'
    Plug 'kshenoy/vim-signature'
    Plug 'godlygeek/csapprox'

    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'wincent/terminus'
    Plug 'romgrk/winteract.vim'
    Plug 'mbbill/undotree'

    Plug 'ericcurtin/CurtineIncSw.vim'

    Plug 'mhinz/vim-startify'
    " vim-startify settings {{{
    let g:startify_session_dir = '~/.vim/session'
    let g:startify_bookmarks = [ {'c': '~/.vimrc'}, '~/.zshrc' ]
    let g:startify_session_persistence = 1
    let g:startify_change_to_vcs_root = 1
    " }}}

    Plug 'sheerun/vim-polyglot'
    Plug 'andymass/vim-matchup'
    Plug 'jiangmiao/auto-pairs'

    Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
    " YouCompleteMe settings {{{
    " let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
    " }}}
    Plug 'ludovicchabant/vim-gutentags'
    " Gutentags settings {{{
    let g:gutentags_project_root = ['.root', '.svn', '.git', '.hg', '.project']
    let g:gutentags_ctags_tagfile = '.tags'
    let g:gutentags_cache_dir = expand('~/.cache/tags')
    " }}}
    Plug 'SirVer/ultisnips'
    " Ultisnips settings {{{
    set runtimepath+=~/.vim/my-snippets/
    let g:UltiSnipsListSnippets='<c-l>'
    let g:UltiSnipsExpandTrigger='<c-j>'
    let g:UltiSnipsJumpForwardTrigger='<c-n>'
    let g:UltiSnipsJumpBackwardTrigger='<c-p>'
    " }}}

    Plug 'honza/vim-snippets'
    Plug 'w0rp/ale'
    " ale settings {{{
    let g:ale_sign_error = '✘'
    let g:ale_sign_warning = '⚠'
    " }}}
" }}}
" In probation {{{
    Plug 'kana/vim-operator-user'   " recommended by vim-clang-format
    Plug 'rhysd/vim-clang-format'

    Plug 'Shougo/unite.vim'
    Plug 'devjoe/vim-codequery'

    Plug 'szw/vim-maximizer'		" enables zoom/maximize toggle of current window
    Plug 'PProvost/vim-ps1'

    Plug 'rizzatti/dash.vim'

    Plug 'nfvs/vim-perforce'
    Plug 'will133/vim-dirdiff'
    Plug 'majutsushi/tagbar'
    Plug 'tfnico/vim-gradle'
" }}}
" Not often used {{{
    Plug 'severin-lemaignan/vim-minimap'
    Plug 'editorconfig/editorconfig-vim'
    Plug 'mileszs/ack.vim'
" }}}
" Unused plugins {{{
    " Plug 'Raimondi/delimitMate'               " superceded by auto-pairs
    " Plug 'cohama/lexima.vim'                  " had runaway insert issues!
    " Plug 'vim-syntastic/syntastic'            " superceded by ale
    " Plug 'neomake/neomake'                    " superceded by ale
    " Plug 'easymotion/vim-easymotion'          " introduces bad habits?

    " works really well, but going
    " to focus on using Terminal in Vim and rely on Vim only for window
    " management.
    " Plug 'christoomey/vim-tmux-navigator'
    " }}}
call plug#end() " Initialize plugin system
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
colorscheme one
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
"   set includeexpr=substitute(v:fname,'\\.','/','g')
" Using Fonts in GVim
"   Note: Windows will block fonts downloaded from the internet:
"   before they can be used first unblock them.
" Getting correct colors in Vim Terminal
"   There are a few things that one needs to set, but its easy
"   to look these up on the internet.  The main thing that I
"   struggled with was that my terminal was not set to support
"   bold fonts.
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
