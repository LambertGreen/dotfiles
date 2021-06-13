
" Use a nice font
if has('win32')
    :GuiFont! Hack\ NF:h12:1
else
" Tried to set the font for `Vimr` but it does not honor ginit.vim.
" TODO: Ditch `Vimr` and find a better GUI client that is also cross platform.
    :GuiFont! Iosevka Nerd Font:h15
end

" Remove ugly tabline
GuiTabline 0

" Remove GUI popup menu (may want to double check this by testing completions)
GuiPopupmenu 0

" Enable paste using Shift-Insert (Needed by Nvim-qt)
inoremap <S-Insert>  <C-R>+

" Open window maximized, as the window usually shows up in a strange position
call GuiWindowMaximized(1)
