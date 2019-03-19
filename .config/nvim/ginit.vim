
" Use a nice font
:Guifont! MesloLGM\ NF

" Remove ugly tabline
GuiTabline 0

" Enable paste using Shift-Insert (Needed by Nvim-qt)
map! <S-Insert>  <C-R>+

" Open window maximized, as the window usually shows up in a strange position
call GuiWindowMaximized(1)

