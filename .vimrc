" An example for a vimrc file.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2017 Sep 20
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc

source $VIMRUNTIME/defaults.vim
" Get the defaults that most users want.
set runtimepath=~/.vim,$VIMRUNTIME " YESSS! here to
" http://vimdoc.sourceforge.net/htmldoc/starting.html#:rviminfo
" http://vimdoc.sourceforge.net/htmldoc/options.html#'viminfo'
set viminfofile=~/.viminfo " To force win-vim to use dot viminfo


let $VIMHOME = $HOME."/.vim"

" Basic Editor options
set number
set mouse=a
set autoindent		" always set autoindenting on

" Set swap/backup/undo to global dir rather working dir
set backupdir=$VIMHOME/backup/
set directory=$VIMHOME/swp/
set undodir=$VIMHOME/undo/


" Set VIM colors bases on base16
if filereadable(expand("~/.vimrc_background"))
  let base16colorspace=256
  source ~/.vimrc_background
endif

set guifont=Ubuntu_Mono_derivative_Powerlin:h12:cANSI:qDRAFT
colorscheme slate

" The matchit plugin makes the % command work better, but it is not backwards
" compatible.
" The ! means the package won't be loaded right away but when plugins are
" loaded during initialization.
if has('syntax') && has('eval')
  packadd! matchit
endif