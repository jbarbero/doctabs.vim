" DocTabs: a vim plugin for organizing a file into sections
"
" Author: Janos Barbero <jbarbero@cs.washington.edu>
"
" Copyright:
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" Versions:
" 0.5   Highlight section headings
" 0.4   Optional folding of other sections
" 0.3   Navigation functions to switch between sections
" 0.2   Save context for each section
" 0.1   Render tabline
"
" -----------------------------------------------------------------------
"
" Planned:
" - TODO: better section patterns to cover all help file formats?
" - Handle overflow rendering
" - Handle section changes due to lines changing, not just writes. Decide
"   which file updates will trigger this.
"
" Optional:
" - Make which group to use configurable?
" - Make tabline use optional (g:doctabs_use_tabline)
" - Multi-document tabline
" - Allows operations on only a section, like search-and-replace in section
" - Deal with switching between windows, i.e. allow a section to be
"   transparently pinned to a given window
" - Add signs (visual marks) to denote sections
"
" Known_issues:
" Right now, the plugin scans the whole file on buffer switch. That seems wasteful.
" Do something nicer than blanking tabline if all sections disappear
"

" Config
let g:doctabs_default_pattern    = get(g:, 'doctabs_default_pattern',    '###\([a-zA-Z0-9_:-]\+\)')
let g:doctabs_filetype_defaults  = {
            \'help':    '^[0-9]\+\. \(.*\)\~',
            \}
let g:doctabs_filetype_patterns  = g:doctabs_filetype_defaults
let g:doctabs_default_section    = get(g:, 'doctabs_default_section',    '~Top')
let g:doctabs_number_tabs        = get(g:, 'doctabs_number_tabs',        1)
let g:doctabs_section_views      = get(g:, 'doctabs_section_views',      1)
let g:doctabs_fold_others        = get(g:, 'doctabs_fold_others',        0)
let g:doctabs_highlight_headings = get(g:, 'doctabs_highlight_headings', 1)

" Merge user filetype patterns into default
call extend(g:doctabs_filetype_defaults,
            \ get(g:, 'doctabs_filetype_patterns', {}))

" Autocommands
augroup doctabs
" au! BufWinEnter * call dtab#dtInit()
au! BufEnter * call dtab#dtInit()
au! BufWinEnter * call dtab#dtInit()
au! BufWritePost * call dtab#dtInit()
au! WinEnter * call dtab#dtWindowInit()
augroup END

" Default keybindings with <Leader>
nnoremap <silent> <Leader>g0 :call dtab#dtJump(0)<CR>
nnoremap <silent> <Leader>g1 :call dtab#dtJump(1)<CR>
nnoremap <silent> <Leader>g2 :call dtab#dtJump(2)<CR>
nnoremap <silent> <Leader>g3 :call dtab#dtJump(3)<CR>
nnoremap <silent> <Leader>g4 :call dtab#dtJump(4)<CR>
nnoremap <silent> <Leader>g5 :call dtab#dtJump(5)<CR>
nnoremap <silent> <Leader>g6 :call dtab#dtJump(6)<CR>
nnoremap <silent> <Leader>g7 :call dtab#dtJump(7)<CR>
nnoremap <silent> <Leader>g8 :call dtab#dtJump(8)<CR>
nnoremap <silent> <Leader>g9 :call dtab#dtJump(9)<CR>
nnoremap <silent> <Leader>gg :call dtab#dtJumpAlt()<CR>
nnoremap <silent> <Leader>gn :call dtab#dtJumpNext()<CR>
nnoremap <silent> <Leader>gp :call dtab#dtJumpPrev()<CR>

