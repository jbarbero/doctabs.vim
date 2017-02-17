" DocTabs: a vim plugin for organizing a file into sections
"
" $Id$
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
" 0.1    Render tabline
"
" -----------------------------------------------------------------------
"
" Planned:
" - Saves state on a move between sections, e.g. by a search or move
" - Has functions you can map to navigate sections
" - Enforces that only one section can be shown at a time, except
" if sections are shorter than a page
" - Allows operations on only a section, like search-and-replace in section
" - Shortcut to jump to last known buffer
" - Can we hack the vim display to hide the other sections entirely?
"
" Optional:
" - Make tabline use optional
"
" Known_issues:
" - Switching back to a buffer if it had been closed confuses the script
" - Switching between windows doesn't restore the tab line (only on write)
" - Can't make sections in source code files, regex isn't aware enough
"
" Requirements_old:
" [_] Need to create windows on open
" [_] Need to switch windows focus on line range
" [_] Need to compute 'section' start/end positions on write, and on first read
" [_] In CursorMoved, need to jump to the windows corresponding to the section
" [_] Compatible with buftabline?
"
" TODO:
" Test out enabling for all files!
" Add the planned features
" Download the GPL
" Move to separate file, make sure pathogen compatible
" Disable in insert mode, it may be causing slowness
"

" #Code#

function! DocTabsGetCurrentSection()
    let curline = line('.')
    " echo ["getcur", curline, b:sections]
    for [tagname, tagpos, endpos] in b:sections
        " echo ["for", tagname, tagpos, endpos, curline]
        if curline >= tagpos && (endpos == '$' || curline <= endpos)
            " echo ["returning", tagname, tagpos, endpos]
            return [tagname, tagpos, endpos]
        endif
    endfor
    return ['DEFAULT', 1, '$']
endfunction

let g:doctabs_section_pattern = '^#[a-zA-Z0-9_:-]\+$'
" let g:doctabs_section_pattern = '#[a-zA-Z0-9_:-]\+#'

" Compute section start/end positions on write
function! DocTabsComputeSections()
    " Save window view and cursor position, reset at end
    let view = winsaveview()

    let b:sections = []
    let last = 0
    let endpos = line('$')

    call cursor(1, 1)

    let ii = 0
    let tagpos = search(g:doctabs_section_pattern, 'cW', endpos)
    " On false, returns 0, which also fails the loop condition
    while tagpos > last
        let last = tagpos
        let tagname = getline('.') " TODO: tagname should be last match, not full line
        let b:sections += [[tagname, tagpos, '$']]
        
        if ii > 0
            let b:sections[-2][2] = tagpos - 1
        endif
        let ii += 1

        " echo [tagname, "last", b:sections[-2]]

        " Don't accept a match at current position - must advance
        let tagpos = search(g:doctabs_section_pattern, 'W', endpos)
    endwhile

    " echo ["len", len(b:sections)]

    " Add sentinels
    if len(b:sections) == 0
        let b:sections = [["DEFAULT", 1, '$']]
    elseif b:sections[0][1] != 1
        let b:sections = [["DEFAULT", 1, b:sections[0][1]-1]] + b:sections
    endif

    " echo ["len", len(b:sections)]

    " Reset window view and cursor position
    call winrestview(view)
endfunction

" Render tabline and highlight current section
function! DocTabsRenderTabline()
    set showtabline=2

    let [w:curtag, w:tagstart, w:tagend] = DocTabsGetCurrentSection()

    let line = ''
    
    let curline = line('.')
    for [tagname, tagpos, endpos] in b:sections
        if curline >= tagpos && (endpos == '$' || curline <= endpos)
            let line .= '%#TabLineSel#'
        else
            let line .= '%#TabLine#'
        endif
        let line .= ' ' . tagname . ' '
    endfor

    " debugging
    " let line .= ' ' . strftime("%c")

    let line .= '%#TabLineFill#'

    let &l:tabline = line
endfunction

" Set up plugin state
function! DocTabsInit()
    call DocTabsComputeSections()

    if len(b:sections) == 1
        " If there is only one section, disable both rendering and move detection
        augroup doctabs
        au! CursorMoved *
        augroup END

        " TODO: this just blanks tabline, it would be nicer to revert to previous cleanly
        let showtabline = 1
        let &l:tabline = ''
    else
        " Set current line and current section
        call DocTabsWindowInit()
        
        " Set autocommand on cursor move. Should be:
        "   Cheap if moving left/right
        "   Cheap if staying in section
        "   Only render if section changes

        augroup doctabs
        " au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call DocTabsSectionMoved(w:newline) | endif | echo [w:curline, w:newline, w:tagstart, w:tagend, 
        "             \"full", w:curline != w:newline && (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)),
        "             \"line", w:curline != w:newline,
        "             \"start", w:newline < w:tagstart,
        "             \"end", w:tagend != '$' && w:newline > w:tagend,
        "             \] | let w:curline = w:newline | endif
        au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call DocTabsSectionMoved(w:newline) | endif | let w:curline = w:newline | endif
        augroup END

        call DocTabsRenderTabline()
    endif
endfunction

" Update on window enter
function! DocTabsWindowInit()
    let [w:curtag, w:tagstart, w:tagend] = DocTabsGetCurrentSection()
    let w:curline = line('.')
    call DocTabsRenderTabline()
endfunction

" Update on section move
function! DocTabsSectionMoved(newline)
    let [w:curtag, w:tagstart, w:tagend] = DocTabsGetCurrentSection()
    call DocTabsRenderTabline()
endfunction

augroup doctabs
au! BufWinEnter * call DocTabsInit()
au! BufWritePost * call DocTabsInit()
au! WinEnter * call DocTabsWindowInit()
augroup END

