" -*- mode: vimrc -*-

"----------------
" Lambert's VIMRC
"----------------

" Environment specific settings {{{
if !has('nvim')
    " Check if we are running vim inside nvim
    " and warn, since this results in vim
    " using the now defined runtime of nvim
    " which causes Vim to fail.
    if $VIMRUNTIME =~? 'nvim'
        throw 'Vim is running inside of Nvim! I recommed you alias vim to nvim.'
    endif
    if filereadable($VIMRUNTIME/'defaults.vim')
        source $VIMRUNTIME/'defaults.vim'
    endif
endif

" Terminal specific settings {{{
if has('termguicolors')
    set termguicolors
endif

if has('macunix') && exists('$ITERM_PROFILE')
    if !has('nvim') && exists('$TMUX')
        " From https://github.com/square/maximum-awesome/pull/245/files
        let &t_SI = '\<Esc>Ptmux;\<Esc>\<Esc>]1337;CursorShape=1\x7\<Esc>\\'
        let &t_EI = '\<Esc>Ptmux;\<Esc>\<Esc>]1337;CursorShape=0\x7\<Esc>\\'

        let &t_8f = '\<Esc>[38:2:%lu:%lu:%lum'
        let &t_8b = '\<Esc>[48:2:%lu:%lu:%lum'
    else
        " From https://github.com/square/maximum-awesome/pull/245/files
        let &t_SI = '\<Esc>]1337;CursorShape=1\x7'
        let &t_EI = '\<Esc>]1337;CursorShape=0\x7'
    endif
endif

" Oni specific config
if exists('g:gui_oni')
    " Put any Oni specific config here
    " Note: Oni's config file is at:
    "  Posix:   ~/.config/oni/config.tsx
    "  Win:     ~\AppData\Roaming\Oni\config.tsx
endif

if !has('gui_running') && !exists('$TMUX')
    " ConEmu specific config
    " https://conemu.github.io/en/VimXterm.html
    if has('win32') && !empty($ConEmuBuild) && !has('nvim')
        set term=xterm
        set t_Co=256
        let &t_AB='\e[48;5;%dm'
        let &t_AF='\e[38;5;%dm'
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
        let &t_kD = '^[[3~'
    endif
endif
" }}}
" Vim's Inbuilt Terminal Settings {{{
" Set Powershell as default shell on Windows
" Disabling for now since it results in extra process spawns
" for git related functions i.e. vim->vimrin.exe->cmd.exe->powershell.exe
" if has('win32') || has('gui_win32')
"      if executable('PowerShell')
"         " Set PowerShell as the shell for running external ! commands
"         " http://stackoverflow.com/questions/7605917/system-with-powershell-in-vim
"         set shell=PowerShell
"         set shellcmdflag=-ExecutionPolicy\ RemoteSigned\ -Command
"         set shellquote=\"
"         " shellxquote must be a literal space character.
"         set shellxquote= " must be a literal space char
"    endif
" endif
" }}}
" Neovim-Remote {{{
if has('nvim') && executable('nvr')
    let $GIT_EDITOR = 'nvr -cc split --remote-wait'
    " Need to set the below to have a gitcommit buffer auto deleted when
    " hidden. Otherwise one will need to run ~:w|bd~.
    augroup AutoDeleteGitCommitBufferOnSave
        autocmd!
        autocmd FileType gitcommit,gitrebase,gitconfig set bufhidden=delete
    augroup END
endif
" }}}
" Fzf workaroud {{{
" Fzf issue on Windows: https://github.com/junegunn/fzf/issues/963
if has('win32') && $TERM ==? 'xterm-256color'
    let $TERM=''
endif
" }}}
" }}}
" Editor {{{
" UTF-8 is the default, but let's be expressive (actually the linter
" complained, and I obliged)
scriptencoding utf-8
set title
" Set title to the current working directory so that the vim
" instance can be found by project name in the OS window manager.
:let &titlestring=getcwd()
set number
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4 " makes the spaces feel like real tabs<Paste>
set incsearch
set hlsearch
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
" enable word completion
set complete+=kspell
" }}}
" Os Platform specifics {{{
if has('win32') && !has('nvim')
    set runtimepath=~/.vim,$VIMRUNTIME
    set viminfofile=~/.viminfo " To force win-vim to use dot viminfo
endif
if has('nvim')
    if has('win32')
        let $VIMHOME = $LOCALAPPDATA.'\nvim'
    else
        let $VIMHOME = $HOME.'/.config/nvim'
        " Note: a prerequisate is to use pyenv to setup virtual environments
        " specific to neovim. Below are the setup instructions:
        "   - install pyenv and pyenv-virtualenv e.g.:
        "       - brew install pyenv pyenv-virtualenv
        "   - install a version of python e.g.:
        "       - pyenv install 3.7.4
        "   - create a virtualenv e.g.:
        "       - pyenv virtualevn 3.7.4 neovim3
        "   - activate the venv e.g.:
        "       - pyenv activate neovim3
        "   - install neovim module:
        "       - pip install neovim
        if !empty(glob($HOME.'/.pyenv/versions/neovim2/bin/python'))
            let g:python_host_prog = $HOME.'/.pyenv/versions/neovim2/bin/python'
        endif
        if !empty(glob($HOME.'/.pyenv/versions/neovim3/bin/python'))
            let g:python3_host_prog = $HOME.'/.pyenv/versions/neovim3/bin/python'
        endif
    endif
else
    let $VIMHOME = $HOME.'/.vim'
endif
" Set swap/backup/undo to global dir rather working dir
set backup
set undofile
set swapfile
set backupdir=$VIMHOME/backup/
if !isdirectory(&backupdir)
    call mkdir(&backupdir, 'p', 0700)
endif
set directory=$VIMHOME/swap/
if !isdirectory(&directory)
    call mkdir(&directory, 'p', 0700)
endif
set undodir=$VIMHOME/undo/
if !isdirectory(&undodir)
    call mkdir(&undodir, 'p', 0700)
endif
" }}}
" Keyboard bindings/mappings {{{
" General mappings {{{
let g:mapleader = "\<Space>"
let g:maplocalleader = "\\"
" Alternative escape from insert mode
:imap kj <Esc>
" Copy/paste into system clipboard
vmap <leader>y "+y
vmap <leader>d "+d
nmap <leader>p "+p
nmap <leader>P "+P
vmap <leader>p "+p
vmap <leader>P "+P
" Quick save
:nnoremap <Leader>w :w<CR>
:nnoremap <Leader>q :q<CR>
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
" Buffer management {{{
nnoremap <Leader>bp :bprevious<CR>
nnoremap <Leader>bn :bnext<CR>
nnoremap <Leader>bs :w<CR>
" }}}
" Window management {{{
" Use the same mappings as Emacs Doom
nnoremap <leader>wh <C-w>h
nnoremap <leader>wj <C-w>j
nnoremap <leader>wk <C-w>k
nnoremap <leader>wl <C-w>l

nnoremap <leader>wq :q<CR>

" terminal mode
if v:version >= 800
    " We are making it easy to exit terminal mode. This is also the setting in
    " Doom Emacs.
    tnoremap <Esc> <C-\><C-n>
    " Now that we have used up Esc. To inovke an Esc to an application running
    " in the terminal use: CTRL-V + Esc.
    tnoremap <C-v><Esc> <Esc>
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
endif

" Jump to QuickFix window
nnoremap <leader>co :copen<CR>

" Toggle terminal window (if neoterm is installed)
nnoremap <leader>ot :Ttoggle<CR>

" }}}
" Fugitive mappings {{{
function! Lgreen_ToggleGStatus()
    if buflisted(bufname('.git/index'))
        bd .git/index
    else
        Gstatus
    endif
endfunction
command! ToggleGStatus :call Lgreen_ToggleGStatus()
" Changing mapping to match Doom Emacs i.e. SPC g g
nmap <Leader>gg :ToggleGStatus<CR>
" }}}
" Maximizer mappings {{{
" Window zoom toggles
nnoremap <silent><C-w>z :MaximizerToggle<CR>
vnoremap <silent><C-w>z :MaximizerToggle<CR>gv
inoremap <silent><C-w>z <C-o>:MaximizerToggle<CR>
" }}}
" Winteract mappings {{{
" Activate interactive window resize mode
nnoremap <leader><leader>W :InteractiveWindow<CR>
" }}}
" NERDTree mappings {{{
" Toggle: Using mapping from Doom Emacs: open project
nmap <Leader>op :NERDTreeToggle<CR>
" Open NERD with current file highlighted
nmap <Leader>N :NERDTreeFind<CR>
" Change directory
nmap <Leader>nc :NERDTreeCWD<CR>
" }}}
" Tagbar mappings {{{
" Toggle Tagbar
nmap <Leader>t :TagbarToggle<CR>
" }}}
" FZF mappings {{{
" Update: Orignally all the below FZF enabled mappings began with prefix:
" <leader>f, but they are now updated to match bindings in Emacs Doom, so that
" I can commit one set of mappings to muscle memory.
"
" Git files selection
nmap <leader>ff :GFiles<CR>
nmap <leader><leader> :GFiles<CR>
" All files selection
nmap <leader>fF :Files<CR>
nmap <leader>. :Files<CR>
" Buffers selection
nmap <leader>fb :Buffers<CR>
" History selection
nmap <leader>fh :History<CR>
" Command history selection
nmap <leader>f: :History:<CR>
" Search history selection
nmap <leader>f/ :History/<CR>
" Tags in current buffer selection
nmap <leader>ft :BTags<CR>
" Tags selection
nmap <leader>fT :Tags<CR>
" Lines in current buffer selection
nmap <leader>fl :BLines<CR>
" Lines selection
nmap <leader>fL :Lines<CR>
" Rg
nmap <leader>fg :Rg<CR>
" Rg but wait for input before, so that next step can be a filter on results
nmap <leader>fG :Rg
" Commands selection
nmap <leader>fc :Commands<CR>
" }}}
" Fugitive mappings {{{
nnoremap <leader>gs :Gstatus<CR>
nnoremap <leader>gl :Glog<CR>
nnoremap <leader>gc :Gcommit<CR>
nnoremap <leader>gd :Gdiff<CR>
nnoremap <leader>gb :Gblame<CR>
" }}}
" Make mappings {{{
nnoremap <leader>m :Make<CR>
" }}}
" ALE mappings {{{
nnoremap <leader>an :ALENext<CR>
nnoremap <leader>ap :ALEPrevious<CR>
nnoremap <leader>al :ALELint<CR>
nnoremap <leader>af :ALEFix<CR>
nnoremap <leader>ai :ALEInfo<CR>
nnoremap <leader>ad :ALEDetail<CR>
" }}}
" CurtineIncSw mappings {{{
" Switch to alternate file e.g. implementation<->header
nnoremap <leader>ca :call CurtineIncSw()<CR>
" }}}
" UndoTree mappings {{{
" Toggle undo tree
nnoremap <leader>u :UndotreeToggle<CR>
" }}}
" ClangFormat mappings {{{
nnoremap <leader>cf :ClangFormat<CR>
" }}}
" }}}
" Functions {{{
fun! Lgreen_TrimWhitespace()
    let l:save = winsaveview()
    keeppatterns %s/\s\+$//e
    call winrestview(l:save)
endfun

fun! Lgreen_FormatJson()
    :%!python -m json.tool
endfun

fun! Lgreen_FormatXml()
    :%!xmllint --format %
endfun

fun! Lgreen_BackgroundTransparent()
    hi Normal guibg=NONE ctermbg=NONE
endfun
" }}}
" Auto commands {{{
" Cusorline only in active window
augroup CursorLineOnlyInActiveWindow
    autocmd!
    autocmd VimEnter,WinEnter,BufWinEnter * setlocal cursorline
    autocmd WinLeave * setlocal nocursorline
augroup END

" On directory change update window title
if v:version >= 800
    if has('nvim')
        augroup DirectoryChange
            autocmd!
            autocmd DirChanged * let &titlestring=v:event['cwd']
        augroup END
    else
        augroup DirectoryChange
            autocmd!
            autocmd DirChanged * let &titlestring=expand("<afile>")
        augroup END
    endif
endif

" Spell checking settings
augroup Spelling
    autocmd!
    " markdown files
    autocmd BufRead,BufNewFile *.md setlocal spell"
    " git commits
    autocmd FileType gitcommit setlocal spell
augroup END

" Buf read/write commands
augroup BufReadWriteStuff
    autocmd!
    " Make VIM scream at edit time about accidental changes to buffers to readonly
    " files
    autocmd BufRead * let &l:modifiable = !&readonly

    " Remove trailing whitespace on save
    autocmd BufWritePre * call Lgreen_TrimWhitespace()
augroup END
" }}}
" Plugins {{{
" Only load plugins if we are using a modern Vim
if v:version >= 800
    " Install vim-plug if not already installed {{{
    if empty(glob($VIMHOME.'/autoload/plug.vim'))
        if has('win32')
            silent !curl -fLo %VIMHOME%\autoload\plug.vim --create-dirs
                        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        else
            silent !curl -fLo $VIMHOME/autoload/plug.vim --create-dirs
                        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        endif
        autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
    endif
    " }}}
    call plug#begin()
    " Frequently used {{{
    " Editing enhancments {{{
    Plug 'easymotion/vim-easymotion'
    Plug 'andymass/vim-matchup'
    " matchup example {{{
    " %     Press anywhere to move back and forth between open/close blocks
    " }}}
    Plug 'jiangmiao/auto-pairs'
    Plug 'tpope/vim-commentary'
    " vim-commentary examples {{{
    " gc    Toggle comment
    " }}}
    Plug 'tpope/vim-surround'
    " vim-surround examples {{{
    " cs"'  Change surrounding "" to ''
    " ysiw] Surround in-word with []
    " }}}
    Plug 'tpope/vim-unimpaired'
    " vim-unimpaired examples {{{
    " ]<Space>  Add newlines
    " ]q        :cnext
    " ]b        :bnext
    " }}}
    Plug 'tpope/vim-repeat'
    " Code completion {{{
    " Man this plugin is frustating me! Using tons of CPU
    " Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
    " YouCompleteMe settings {{{
    " Don't load YCM by default... projects should load it if needed
    " let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
    " }}}
    " }}}
    " Snippets {{{
    Plug 'SirVer/ultisnips'
    " Ultisnips settings {{{
    set runtimepath+=~/.vim/my-snippets/
    let g:UltiSnipsListSnippets='<c-l>'
    let g:UltiSnipsExpandTrigger='<c-j>'
    let g:UltiSnipsJumpForwardTrigger='<c-n>'
    let g:UltiSnipsJumpBackwardTrigger='<c-p>'
    " }}}
    Plug 'honza/vim-snippets'
    " }}}
    " }}}
    " Fuzzy file search {{{
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    " FZF settings {{{
    if executable('fd')
        let $FZF_DEFAULT_COMMAND = 'fd --type f'
    endif
    " }}}
    " }}}
    " Graphical Editor Enhancements {{{
    " Status + Tab line {{{
    Plug 'vim-airline/vim-airline'
    " Airline settings {{{
    let g:airline_powerline_fonts = 1
    let g:airline#extensions#tabline#enabled = 1
    let g:airline#extensions#ale#enabled = 1
    " }}}
    " }}}
    " Gutter {{{
    " TODO: Trying out signify instead for a trial run.
    " Plug 'airblade/vim-gitgutter'
    " Another plugin that will completely lock up Vim on a large file
    " or large repo
    " Plug 'mhinz/vim-signify'
    " Shows marks in the gutter
    " Plug 'kshenoy/vim-signature'
    " }}}
    " Cursor line {{{
    Plug 'ntpeters/vim-airline-colornum'
    " }}}
    " File explorer {{{
    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
    "NERDTree settings {{{
    let g:NERDTreeHijackNetrw = 1
    "}}}
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug 'ryanoasis/vim-devicons'
    "vim-devicons settings {{{
    let g:WebDevIconsUnicodeDecorateFolderNodes = 1
    let g:WebDevIconsNerdTreeGitPluginForceVAlign = 1
    "}}}
    " }}}
    " UndoTree {{{
    Plug 'mbbill/undotree'
    " }}}
    " Tag bar {{{
    Plug 'majutsushi/tagbar'
    " }}}
    " Window management {{{
    Plug 'romgrk/winteract.vim'
    Plug 'szw/vim-maximizer'        " enables zoom/maximize toggle of current window
    " }}}
    " Color schemes {{{
    Plug 'flazz/vim-colorschemes'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'joshdick/onedark.vim'
    Plug 'rakr/vim-one'
    Plug 'sonph/onehalf', {'rtp': 'vim/'}
    Plug 'tomasiser/vim-code-dark'
    Plug 'drewtempelmeyer/palenight.vim'
    Plug 'KeitaNakamura/neodark.vim'
    Plug 'jacoborus/tender.vim'
    Plug 'lifepillar/vim-solarized8'
    Plug 'ayu-theme/ayu-vim'
    Plug 'NLKNguyen/papercolor-theme'
    " Trying to see if I can do without the below
    " Plug 'godlygeek/csapprox'
    " }}}
    " Syntax handling {{{
    " A collection of language packs
    Plug 'sheerun/vim-polyglot'
    " }}}
    " }}}
    " Term/Tmux integration {{{
    Plug 'tmux-plugins/vim-tmux-focus-events'
    " Plug 'wincent/terminus'  " does the same as the above?
    Plug 'christoomey/vim-tmux-navigator'
    " }}}
    " Session handling {{{
    "Plug 'tpope/vim-obsession' Superceded by vim-startify which supports
    "session manangement
    Plug 'mhinz/vim-startify'
    " vim-startify settings {{{
    let g:startify_session_dir = '~/.vim/session'
    let g:startify_bookmarks = [ {'c': '~/.vimrc'}, '~/.zshrc' ]
    let g:startify_session_persistence = 1
    let g:startify_change_to_vcs_root = 1
    " }}}
    " }}}
    " Version Control {{{
    Plug 'tpope/vim-fugitive'
    " vim-fugitive examples {{{
    " :Gstatus, Gdiff, Gcommit, Gpush, Gpull
    " }}}
    Plug 'junegunn/gv.vim'
    " gv.vim examples {{{
    " :GV   open commit browser
    " }}}
    Plug 'nfvs/vim-perforce'
    " vim-perforce exmaple usage {{{
    " :P4info, P4edit, P4revert
    " }}}
    " }}}
    " Tags {{{
    Plug 'ludovicchabant/vim-gutentags'
    " Gutentags settings {{{
    let g:gutentags_project_root = ['.root', '.svn', '.git', '.hg', '.project', '.p4config']
    let g:gutentags_ctags_tagfile = '.tags'
    let g:gutentags_cache_dir = expand('~/.cache/tags')
    :set statusline+=%{gutentags#statusline()}
    " }}}
    " }}}
    " Linting {{{
    Plug 'w0rp/ale'
    " ale settings {{{
    let g:ale_sign_error = '✘'
    let g:ale_sign_warning = '⚠'
    let g:ale_fixers = {
    \   'cpp': ['remove_trailing_lines', 'trim_whitespace'],
    \   'python': ['remove_trailing_lines', 'trim_whitespace', 'isort', 'yapf']
    \}
    let g:ale_python_auto_pipenv = 1
    let g:ale_python_mypy_auto_pipenv = 1
    let g:ale_python_mypy_options = '--ignore-missing-imports'
    " TODO: Remove below options from main vimrc and have ale options for cpp
    " be defined in specific projects.
    " let g:ale_cpp_clangtidy_options = '-x c++'  " Needed to make clangtidy treat .h files as c++ rather than c files.
    " let g:ale_cpp_clangcheck_options = '-- -x c++'  " Needed to make clangtidy treat .h files as c++ rather than c files.
    " }}}
    " }}}
    " Building/Testing {{{
    Plug 'tpope/vim-dispatch'
    " vim-dispatch examples {{{
    " :Make         Run a compilation task, and errors show in QF
    " :Make!        For longer-running/background tasks
    " :compiler     Switch compiler
    " :Dispatch     Run a command (async)
    " }}}
    Plug 'janko/vim-test'
    " vim-test config {{{
    nnoremap <leader>tf :TestFile<CR>
    nnoremap <leader>ts :TestSuite<CR>
    " }}}
    " }}}
    " Python development {{{
    Plug 'tmhedberg/SimpylFold'     " python folding
    " Disabling due to huge initialization cost i.e. >500ms
    " Plug 'ambv/black'               " python auto formater
    Plug 'davidhalter/jedi-vim'
    " Jedi-vim config {{{
    let g:jedi#completions_enabled = 0  " let YCM handle completions, which also uses Jedi
    let g:jedi#goto_command = ''
    let g:jedi#goto_assignments_command = ''
    let g:jedi#goto_definitions_command = ''
    let g:jedi#documentation_command = ''
    let g:jedi#usages_command = ''
    let g:jedi#completions_command = ''
    let g:jedi#rename_command = ''
    nnoremap <localleader>r :call jedi#rename()<CR>
    nnoremap <localleader>d :call jedi#goto()<CR>
    nnoremap <localleader>g :call jedi#goto_assignments()<CR>
    nnoremap <localleader>n :call jedi#usages()<CR>
    " }}}
    " }}}
    " Cpp development {{{
    Plug 'kana/vim-operator-user'   " recommended by vim-clang-format
    Plug 'rhysd/vim-clang-format'
    " }}}
    " Powershell {{{
    Plug 'PProvost/vim-ps1'         " powershell
    " }}}
    " Gradle {{{
    Plug 'tfnico/vim-gradle'
    " }}}
    " Utilities {{{
    Plug 'will133/vim-dirdiff'
    " DirDiff examples {{{
    " :DirDiff  <dir1> <dir2>
    " }}}
    Plug 'AndrewRadev/bufferize.vim'
    " Buffersize example {{{
    " :Bufferize <ex mode command that has output>
    " }}}
    " }}}
" }}}
    " In probation {{{
    Plug 'kassio/neoterm'
    " neoterm config {{{
    let g:neoterm_default_mod = 'botright'
    " }}}
    Plug 'devjoe/vim-codequery'
    Plug 'jceb/vim-orgmode'
    Plug 'rizzatti/dash.vim'
    Plug 'yuttie/comfortable-motion.vim'
    Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
    " }}}
    " Not often used {{{
    Plug 'severin-lemaignan/vim-minimap'
    Plug 'editorconfig/editorconfig-vim'
    " }}}
    " Unused plugins {{{
    " Plug 'Raimondi/delimitMate'       " superceded by auto-pairs
    " Plug 'cohama/lexima.vim'          " had runaway insert issues!
    " Plug 'vim-syntastic/syntastic'    " superceded by ale
    " Plug 'neomake/neomake'            " superceded by ale
    " Plug 'tpope/vim-vinegar'          " this enhances netrw, but NERDTree is what we use
    " Plug 'gcmt/taboo.vim'             " don't find the need to use
    " Plug 'mileszs/ack.vim'            " using Rg command from fzf.vim
    " Plug 'Shougo/unite.vim'           " new ver is denite. Using fzf
                                        " instead.
    " Plug 'raghur/vim-ghost', {'do': ':GhostInstall'} " only needed on
    " machines with the browser extension."
    " Plug 'ngemily/vim-vp4'            " did not work when testing p4 info
    " Plug 'vimwiki/vimwiki'            " note taking is now done in Emacs Org mode
    " }}}
    call plug#end() " Initialize plugin system
endif " version >= 800
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
    set grepprg=ag\ --vimgrep
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
" ColorSchemes {{{
function! Lgreen_ColorSchemePalenight()
    colorscheme palenight
    set background=dark
    let g:palenight_terminal_italics=1
    highlight Comment cterm=italic gui=italic
    let g:airline_theme='palenight'
endfunction

function! Lgreen_ColorSchemePaperColor()
    let g:PaperColor_Theme_Options = {
                \   'theme': {
                \     'default.light': {
                \       'transparent_background': 0
                \     }
                \   },
                \   'language': {
                \     'python': {
                \       'highlight_builtins' : 1
                \     },
                \     'cpp': {
                \       'highlight_standard_library': 1
                \     },
                \     'c': {
                \       'highlight_builtins' : 1
                \     }
                \   }
                \ }
    colorscheme PaperColor
    set background=light
    let g:airline_theme='papercolor'
    highlight Comment cterm=italic gui=italic
endfunction

function! Lgreen_ColorSchemeTender()
    colorscheme tender
    set background=dark
    let g:airline_theme = 'tender'
    hi clear SignColumn
    highlight Comment cterm=italic gui=italic
endfunction

function! Lgreen_ColorSchemeOne()
    colorscheme one
    set background=dark
    let g:one_allow_italics = 1
endfunction

function! Lgreen_ColorSchemeAyu()
    colorscheme ayu
    let ayucolor='light'  "  light | mirage | dark
    highlight Comment cterm=italic gui=italic
endfunction

:call Lgreen_ColorSchemePalenight()

" Make comments show in italics, for themes that don't support it natively.
" Note: Italics may not show if the terminal's terminfo is not
" setup correctly for showing italics e.g. some extra config is
" required to show italics when running inside TMUX, and if also
" running in an SSH session, then even more setup may be required.
" highlight Comment cterm=italic gui=italic
" }}}
" Local settings {{{
" Check machine specific local config
execute 'silent! source ~/.vimrc_local'
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
" Vim paste in Terminal mode:
"   While in insert mode, press: CTRL-W" followed by register
" Nvim paste in Terminal mode:
"   While in normal mode, use: p
" Syntax Highlighting
"   Fix broken highlighting (often happens over SSH):
"       :syntax sync fromstart
" Changing visual selection in other direction
"   1. o
" End-of-line (EOL) characters: CRLF for Windows; LF for Unix
"   To force Vim reading a file as specific fileformat:
"       :e ++ff=[dos|unix]
"   To replace ^M characters:
"       :%s/^M//g
"   Note: To type ^M actualy type: [CTRL-V][CTRL-M]
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
