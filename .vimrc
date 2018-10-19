" Lambert's VIMRC

if !has('nvim')
    " Get the defaults that most users want.
    source $VIMRUNTIME/defaults.vim
endif

" ConEmu specific config
" https://conemu.github.io/en/VimXterm.html
if has('win32') && !has("gui_running")
    " Enable 256 colors
    set term=xterm
    set t_Co=256
    let &t_AB="\e[48;5;%dm"
    let &t_AF="\e[38;5;%dm"
    " Enable mouse support
    set mouse=a
    " Fix BS key
    inoremap <Char-0x07F> <BS>
    nnoremap <Char-0x07F> <BS>
    tnoremap <Char-0x07F> <BS>
    cnoremap <Char-0x07F> <BS>
endif

" Editor {{{
set number
set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4 " makes the spaces feel like real tabs<Paste>
set autoread
set nocursorline
set hidden " allows switching from a buffer that has unwritten changes
set mouse=a " enable mouse suppport in all modes
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<
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
set backupdir=$VIMHOME/backup/
set directory=$VIMHOME/swap/
set undodir=$VIMHOME/undo/
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
    Plug 'airblade/vim-gitgutter'
    Plug 'ctrlpvim/ctrlp.vim'
    Plug 'flazz/vim-colorschemes'
"   Plug 'honza/vim-snippets'
    Plug 'joshdick/onedark.vim'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'mileszs/ack.vim'
    Plug 'rhysd/vim-clang-format'
    Plug 'romgrk/winteract.vim'
    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
"   Plug 'SirVer/ultisnips'
    Plug 'sjl/gundo.vim'
    Plug 'sheerun/vim-polyglot'
    Plug 'tmux-plugins/vim-tmux-focus-events'
    Plug 'tomasiser/vim-code-dark'
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-fugitive'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-obsession'
"   Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
    Plug 'vim-airline/vim-airline'
    Plug 'vim-airline/vim-airline-themes'
    Plug 'vim-syntastic/syntastic'
    Plug 'Xuyuanp/nerdtree-git-plugin'
call plug#end() " Initialize plugin system
" }}}
" }}}
" Plugins Config {{{
" Airline {{{
set noshowmode " Set noshowmode since we are using airline for status
let g:airline_powerline_fonts = 1
let g:airline_theme = 'jellybeans'
" }}}
" Ack/Ag/Grep {{{
if executable('ag')
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
" Folding {{{
" vim:fdm=marker
" }}}

" Check machine specific local config
execute "silent! source ~/.vimrc_local"
