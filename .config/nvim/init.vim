if has('win32') || has('win64')
	source ~/_vimrc
else
	source ~/.vimrc
endif

" Key-bindings {{{
" Window navigation {{{
tnoremap <C-W><C-W> <C-\><C-n><C-W><C-W>
tnoremap <C-W><C-J> <C-\><C-n><C-W><C-J>
tnoremap <C-W><C-H> <C-\><C-n><C-W><C-H>
tnoremap <C-W><C-K> <C-\><C-n><C-W><C-K>
tnoremap <C-W><C-L> <C-\><C-n><C-W><C-L>
" }}}
" }}}
" TODOs {{{
" TODO: YCM config
" let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
" }}}
" Folding {{{
" vim:fdm=marker
" }}}
