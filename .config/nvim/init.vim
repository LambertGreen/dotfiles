" Editor {{{
" Basic options {{{
set noshowmode " Set noshowmode since we are using lightline.vim for status
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
set wildmode=longest,list,full
set wildmenu
" More natural window opening positions
set splitbelow
set splitright
" Show trailing white-space
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/
" }}}
" Status line {{{
let g:airline_powerline_fonts = 1
let g:airline_theme = 'jellybeans'
" }}}
" }}}
" Key-bindings {{{
" Window navigation {{{
tnoremap <C-W><C-W> <C-\><C-n><C-W><C-W>
tnoremap <C-W><C-J> <C-\><C-n><C-W><C-J>
tnoremap <C-W><C-H> <C-\><C-n><C-W><C-H>
tnoremap <C-W><C-K> <C-\><C-n><C-W><C-K>
tnoremap <C-W><C-L> <C-\><C-n><C-W><C-L>
" }}}
" }}}
" Fuzzy finding {{{
" Ctrl-P {{{
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
set wildignore+=*/tmp/*,*.so,*.swp,*.zip
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
" C++ {{{
let g:clang_format#auto_format = 0
let g:clang_format#style_options = {
      \ "Standard" : "C++11",
      \ "AllowShortIfStatementsOnASingleLine" : "true",
      \ "AlwaysBreakTemplateDeclarations" : "true",
      \ "AccessModifierOffset" : -4
      \ }
autocmd FileType cpp, ClangFormatAutoEnable
" }}}
" Markdown {{{
let g:markdown_fenced_languages = ['html', 'python', 'bash=sh']
" }}}
" }}}
" Plugins {{{
call plug#begin()
    Plug 'airblade/vim-gitgutter'
	Plug 'ctrlpvim/ctrlp.vim'
    Plug 'flazz/vim-colorschemes'
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
" }}}
" Themes {{{
set background=dark
try
  colorscheme jellybeans
  catch
  try
    colorscheme slate
    catch
  endtry
endtry
" My favorite themes:
" colorscheme jellybeans
" colorscheme onedark
" colorscheme codedark
" }}}
" TODOs {{{
" TODO: YCM config
" let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
" TODO: Add this to gvim: set guifont=Source_Code_Pro_for_Powerline:h12:cANSI:qDRAFT
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
