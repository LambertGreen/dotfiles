" Gvim specific config

" Hide unwanted GUI stuff
set guioptions-=m  "menu bar
set guioptions-=T  "toolbar
set guioptions-=r  "scrollbar

" Fix resizing issue
" https://stackoverflow.com/questions/13251522/why-does-gvim-resize-and-reposition-itself-after-some-actions
set guioptions=+k

" Set a good looking NERD+Powerline enabled font
set guifont=MesloLGM_NF:h10:cANSI:qDEFAULT

if has('gui_win32') && has('directx')
    " enable dirext rendering
    set rop=type:directx
endif
