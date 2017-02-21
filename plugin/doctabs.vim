" DocTabs: a vim plugin for organizing a file into sections
"
" $Id$
"
" Author: Janos Barbero <jbarbero@cs.washington.edu>
"
" ###Docs
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
" - Shortcut to jump to last known buffer
" - Has functions you can map to navigate sections
" - Handle section changes due to lines changing, not just writes. Decide
"   which file updates will trigger this.
" - Write vim compatible doc
" - Allows operations on only a section, like search-and-replace in section
" - Deal with switching between windows, i.e. allow a section to be
"   transparently pinned to a given window
" - Add signs (visual marks) to denote sections
"
" Optional:
" - Make tabline use optional
"
" Known_issues:
"
" Requirements_old:
" [_] Need to switch windows focus on line range
" [_] Need to compute 'section' start/end positions on write, and on first read
" [_] In CursorMoved, need to jump to the windows corresponding to the section
" [_] Compatible with buftabline?
"
" TODO:
" Test out enabling for all files!
" Add the planned features
" Do something nicer than blanking tabline if all sections disappear
" screen-like navigation features:
"   jump to specific section with label (C-t ...)
"   next, previous sections (C-t p/h, C-t n/l), maybe even C-h/C-n?
"   alternate section (C-t C-t)
" Decide: Switch sections in insert mode or not?
"

" ###Code

" Config
" DocTabs uses the last matching group from a pattern match as the section title
let g:doctabs_sections        = get(g:, 'doctabs_sections',        '###\([a-zA-Z0-9_:-]\+\)')
let g:doctabs_default_section = get(g:, 'doctabs_default_section', '~Top')
let g:doctabs_number_tabs     = get(g:, 'doctabs_number_tabs',     1)
let g:doctabs_section_views   = get(g:, 'doctabs_section_views',   1)
let g:doctabs_fold_others     = get(g:, 'doctabs_fold_others',     0)

" Functions
function! DocTabsGetCurrentSection()
    let curline = line('.')
    " echo ["getcur", curline, b:sections]
    let ii = 0
    for [tagname, tagpos, endpos, sectionview] in b:sections
        " echo ["for", tagname, tagpos, endpos, curline]
        if curline >= tagpos && (endpos == '$' || curline <= endpos)
            " echo ["returning", tagname, tagpos, endpos]
            return [ii, tagname, tagpos, endpos, sectionview]
        endif
        let ii += 1
    endfor
    return [0, g:doctabs_default_section, 1, '$', {}]
endfunction

" Compute section start/end positions on write
function! DocTabsComputeSections()
    " Save window view and cursor position, reset at end
    let view = winsaveview()

    let b:sections_old = get(b:, 'sections', [])
    " TODO handle section renames, insertions, etc

    let b:sections = []
    let last = 0
    let endpos = line('$')

    call cursor(1, 1)

    let ii = 0
    let tagpos = search(g:doctabs_sections, 'cW', endpos)
    " On false, returns 0, which also fails the loop condition
    while tagpos > last
        let last = tagpos
        let line = getline('.')
        let matches = matchlist(line, g:doctabs_sections)
        for matchgroup in matches
            if matchgroup != ''
                let tagname = matchgroup
            endif
        endfor
        let b:sections += [[tagname, tagpos, '$', {}]]
        
        if ii > 0
            let b:sections[-2][2] = tagpos - 1
        endif
        let ii += 1

        " echo [tagname, "last", b:sections[-2]]

        " Don't accept a match at current position - must advance
        let tagpos = search(g:doctabs_sections, 'W', endpos)
    endwhile

    " echo ["len", len(b:sections)]

    " Add sentinels
    if len(b:sections) == 0
        let b:sections = [[g:doctabs_default_section, 1, '$', {}]]
    elseif b:sections[0][1] != 1
        let b:sections = [[g:doctabs_default_section, 1, b:sections[0][1]-1, {}]] + b:sections
    endif

    " echo ["len", len(b:sections)]

    " Reset window view and cursor position
    call winrestview(view)
endfunction

" Render tabline and highlight current section
function! DocTabsRenderTabline()
    set showtabline=2

    let [w:section, w:curtag, w:tagstart, w:tagend, w:sectionview] = DocTabsGetCurrentSection()

    let line = ''
    
    let curline = line('.')
    for [tagname, tagpos, endpos, sectionview] in b:sections
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

        if g:doctabs_section_views
            au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call DocTabsSectionMoved(w:newline) | else | let b:sections[w:section][3] = winsaveview() | endif | let w:curline = w:newline | endif
        else
            au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call DocTabsSectionMoved(w:newline) | endif | let w:curline = w:newline | endif
        endif
        augroup END

        call DocTabsRenderTabline()
    endif
endfunction

" Update on window enter
function! DocTabsWindowInit()
    let [w:section, w:curtag, w:tagstart, w:tagend, w:sectionview] = DocTabsGetCurrentSection()
    let w:curline = line('.')
    call DocTabsRenderTabline()
endfunction

" Update on section move
function! DocTabsSectionMoved(newline)
    let [w:newsection, w:curtag, w:tagstart, w:tagend, w:sectionview] = DocTabsGetCurrentSection()
    
    if g:doctabs_fold_others
        set fdm=manual
        let [oldtag, oldstart, oldend, oldview] = b:sections[w:section]
        execute oldstart . ',' . oldend . 'fold'
        execute w:tagstart . ',' . w:tagend . 'foldopen'
    endif

    let w:section = w:newsection

    if g:doctabs_section_views
        " Restore everything except cursor position - the user knows where
        " they're going
        let curview = winsaveview()
        let w:sectionview['lnum'] = curview['lnum']
        let w:sectionview['col'] = curview['col']
        let w:sectionview['coladd'] = curview['coladd']
        call winrestview(w:sectionview)
    endif

    call DocTabsRenderTabline()
endfunction

augroup doctabs
au! BufWinEnter * call DocTabsInit()
au! BufWritePost * call DocTabsInit()
au! WinEnter * call DocTabsWindowInit()
augroup END

