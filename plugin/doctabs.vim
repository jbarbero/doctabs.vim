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
" -----------------------------------------------------------------------
"
" Planned:
" - TODO: Scrolling (C-f) got broken by the new views somehow
" - Persist per-section views between edit sessions via session hooks or
"   separately
" - Pin section to window so section jump involves window jump. But beware bad
"   user experience.
" - When jumping to a section, try to avoid showing the previous section(s)
"   above it, by manipulating the view
"
" - Bug: If only one named section, it is not rendered
" - Handle section changes due to lines changing, not just writes. Decide
"   which file updates will trigger this.
" - Keep old value of showtabline around, use it if no sections remain
"
" Maybe:
" - Better section patterns to cover all vim help file formats
" - Allow sections to be used as text objects. See:
"   https://github.com/b4winckler/vim-angry/blob/master/plugin/angry.vim
" - Allow sections to be moved and renumbered like screen windows
" - Handle tabline click to select section in terminal and gui vim
" - Section switching menu or window
" - Make which group to use configurable?
" - Make tabline use optional (g:doctabs_use_tabline)
" - Multi-document tabline
" - Allows operations on only a section, like search-and-replace in section
" - Deal with switching between windows, i.e. allow a section to be
"   transparently pinned to a given window
" - Add signs (visual marks) to denote sections
"
" Known:
" - Section highlights only show up in one window when splitting

" Config
let g:doctabs_default_pattern      = get(g:, 'doctabs_default_pattern',    '###\([a-zA-Z0-9_:-][a-zA-Z0-9_: -]*\)')
let g:doctabs_filetype_defaults    = {
            \'help':    '^[0-9]\+\. \(.*\)\~',
            \}
let g:doctabs_filetype_patterns    = g:doctabs_filetype_defaults
let g:doctabs_default_section      = get(g:, 'doctabs_default_section',      '~Top')
let g:doctabs_number_tabs          = get(g:, 'doctabs_number_tabs',          1)
let g:doctabs_alpha_labels         = get(g:, 'doctabs_alpha_labels',         1)
let g:doctabs_section_views        = get(g:, 'doctabs_section_views',        1)
let g:doctabs_fold_others          = get(g:, 'doctabs_fold_others',          0)
let g:doctabs_highlight_headings   = get(g:, 'doctabs_highlight_headings',   1)

" Internal flags
let g:_doctabs_save_view_on_move   = get(g:, '_doctabs_save_view_on_move',   0)
let g:_doctabs_user_prefix         = get(g:, '_doctabs_user_prefix',         '')
let g:_doctabs_section_fast_update = get(g:, '_doctabs_section_fast_update', 1)

" All numbers and letters except those used for keybindings: n, p, g, N, P, G
let g:doctabs_labels = '0123456789qwertyuioasdfhjklzxcvbmQWERTYUIOASDFHJKLZXCVBM'

" Merge user filetype patterns into default
call extend(g:doctabs_filetype_defaults,
            \ get(g:, 'doctabs_filetype_patterns', {}))

" Autocommands
augroup doctabs
au! BufEnter * call dtab#dtInit()
au! BufWinEnter * call dtab#dtInit()
au! BufWritePost * call dtab#dtInit()
au! WinEnter * call dtab#dtWindowInit()
augroup END

" We always set up default keybindings with <Leader>
call dtab#dtBindings('Leader')

" We also optionally set up keybindings with a user-supplied prefix
if g:_doctabs_user_prefix != ''
    call dtab#dtBindings(g:_doctabs_user_prefix)
end

