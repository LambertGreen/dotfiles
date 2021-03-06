if has('win32') || has('win64')
	source ~/_vimrc
else
	source ~/.vimrc
endif

function! Lgreen_ColorDarkerTerminalWindow()
    " Set a slightly different background for the terminal
    " so that it is easier to see than the regular buffers.
    hi BlackBg guibg=#1e2128
    au TermOpen * :set winhighlight=Normal:BlackBg
    au BufHidden term://* :set winhighlight=Normal:Normal
endfunction

function! Lgreen_ColorTerminalTheme()
    " Set theme for terminal in window
    let g:terminal_color_0  = '#1b1d1e'
    " Color 1 is switched with Color 4
    let g:terminal_color_1  = '#f92672'
    let g:terminal_color_2  = '#82b414'
    " Color 3 is switched with Color 6
    let g:terminal_color_3  = '#fd971f'
    let g:terminal_color_4  = '#268bd2'
    let g:terminal_color_5  = '#8c54fe'
    let g:terminal_color_6  = '#56c2d6'
    let g:terminal_color_7  = '#ccccc6'
    let g:terminal_color_8  = '#505354'
    let g:terminal_color_9  = '#62ade3'
    let g:terminal_color_10 = '#b7eb46'
    let g:terminal_color_11 = '#94d8e5'
    let g:terminal_color_12 = '#ff5995'
    let g:terminal_color_13 = '#bfa0fe'
    let g:terminal_color_14 = '#feed6c'
    let g:terminal_color_15 = '#f8f8f2'
endfunction

:call Lgreen_ColorTerminalTheme()

" TODOs {{{
" TODO: YCM config
" let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
