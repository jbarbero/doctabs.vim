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
" 0.7   Allow alphanumeric tab labels for easier switching
" 0.6   Handle tabline overflow rendering
" 0.5   Highlight section headings, only update views when using jumps
" 0.4   Optional folding of other sections
" 0.3   Navigation functions to switch between sections
" 0.2   Save context for each section
" 0.1   Render tabline
"
" -----------------------------------------------------------------------
"
" Planned:
" - Handle click to select section in terminal and gui vim
" - Alphanumeric labels to allow easy switching to more than 10 sections
" - Better section patterns to cover all vim help file formats
" - Handle section changes due to lines changing, not just writes. Decide
"   which file updates will trigger this.
" - Keep old value of showtabline around, use it if no sections remain
"
" Optional:
" - Section switching menu or window
" - Make which group to use configurable?
" - Make tabline use optional (g:doctabs_use_tabline)
" - Multi-document tabline
" - Allows operations on only a section, like search-and-replace in section
" - Deal with switching between windows, i.e. allow a section to be
"   transparently pinned to a given window
" - Add signs (visual marks) to denote sections
"

" Config
let g:doctabs_default_pattern    = get(g:, 'doctabs_default_pattern',    '###\([a-zA-Z0-9_:-]\+\)')
let g:doctabs_filetype_defaults  = {
            \'help':    '^[0-9]\+\. \(.*\)\~',
            \}
let g:doctabs_filetype_patterns  = g:doctabs_filetype_defaults
let g:doctabs_default_section    = get(g:, 'doctabs_default_section',    '~Top')
let g:doctabs_number_tabs        = get(g:, 'doctabs_number_tabs',        1)
let g:doctabs_alpha_labels       = get(g:, 'doctabs_alpha_labels',       1)
let g:doctabs_section_views      = get(g:, 'doctabs_section_views',      1)
let g:doctabs_fold_others        = get(g:, 'doctabs_fold_others',        0)
let g:doctabs_highlight_headings = get(g:, 'doctabs_highlight_headings', 1)

" Internal flags
let g:_doctabs_save_view_on_move = get(g:, '_doctabs_save_view_on_move', 0)
let g:_doctabs_user_bindings     = get(g:, '_doctabs_user_bindings',     'leader')

" All numbers and letters except those used for keybindings: n, p, g, N, P, G
let g:doctabs_labels = '0123456789qwertyuioasdfhjklzxcvbmQWERTYUIOASDFHJKLZXCVBM'

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
call dtab#dtBindings('leader')
if g:_doctabs_user_bindings != 'leader'
    call dtab#dtBindings(g:_doctabs_user_bindings)
end

