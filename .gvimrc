" Gvim specific config

" Hide stuff
set guioptions-=m  "menu bar
set guioptions-=T  "toolbar
set guioptions-=r  "scrollbar

if has('gui_macvim')
    set guifont=HackNerdFontComplete-Regular:h12
else
    set guifont=FuraCode_NF:h11:cANSI:qDEFAULT
endif

" enable dirext rendering
set rop=type:directx
