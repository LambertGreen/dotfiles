
" Use a nice font
if has('win32')
    set guifont=Iosevka\ NF:h13
else
    set guifont=Iosevka\ Nerd\ Font:h13
end

" Remove ugly tabline
GuiTabline 0

" Remove GUI popup menu (may want to double check this by testing completions)
GuiPopupmenu 0

" Enable paste using Shift-Insert (Needed by Nvim-qt)
inoremap <S-Insert>  <C-R>+

" Open window maximized, as the window usually shows up in a strange position
call GuiWindowMaximized(1)
