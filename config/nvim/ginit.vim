
" Use a nice font
:GuiFont! Hack\ NF:h10:1

" Remove ugly tabline
GuiTabline 0

" Remove GUI popup menu (may want to double check this by testing completions)
GuiPopupmenu 0

" Enable paste using Shift-Insert (Needed by Nvim-qt)
inoremap <S-Insert>  <C-R>+

" Open window maximized, as the window usually shows up in a strange position
call GuiWindowMaximized(1)

