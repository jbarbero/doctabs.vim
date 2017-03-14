" DocTabs autoload functions
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


" ###SectionFuncs

" Find current section and return its entry
function! dtab#dtGetCurrentSection()
    let curline = line('.')
    let ii = 0
    for [tagname, tagpos, endpos, sectionview] in b:sections
        if curline >= tagpos && (endpos == '$' || curline <= endpos)
            return [ii, tagname, tagpos, endpos, sectionview]
        endif
        let ii += 1
    endfor
    return [0, g:doctabs_default_section, 1, '$', {}]
endfunction


" Compute section start/end positions on write
function! dtab#dtComputeSections()
    " Save window view and cursor position, reset at end
    let view = winsaveview()

    " Pick which pattern to use based on filetype
    let pattern = g:doctabs_default_pattern
    if has_key(g:doctabs_filetype_patterns, &filetype)
        let pattern = g:doctabs_filetype_patterns[&filetype]
    endif
    
    " Highlight section titles

    " First clear any matches
    let match_old = get(w:, 'dtmatch', -1)
    " Ignore -1 or reserved matches 1-3
    if match_old > 3
        silent call matchdelete(match_old)
    endif

    " Then add a match if highlighting is on
    if g:doctabs_highlight_headings == 1
        let w:dtmatch = matchadd("Title", pattern)
    endif

    let views_old = {}
    for [tagname, tagpos, tagend, tagview] in get(b:, 'sections', [])
        let views_old[tagname] = tagview
    endfor

    " TODO handle section renames, insertions, etc

    let b:sections = []
    let last = 0
    let endpos = line('$')

    call cursor(1, 1)

    let ii = 0
    let tagpos = search(pattern, 'cW', endpos)
    " On false, returns 0, which also fails the loop condition
    while tagpos > last
        let last = tagpos
        let line = getline('.')
        let matches = matchlist(line, pattern)
        for matchgroup in matches
            if matchgroup != ''
                let tagname = matchgroup
            endif
        endfor
        let oldview = get(views_old, tagname, {})
        let b:sections += [[tagname, tagpos, '$', oldview]]
        
        if ii > 0
            let b:sections[-2][2] = tagpos - 1
        endif
        let ii += 1

        " Don't accept a match at current position - must advance
        let tagpos = search(pattern, 'W', endpos)
    endwhile

    " Add sentinels
    if len(b:sections) == 0
        let b:sections = [[g:doctabs_default_section, 1, '$', {}]]
    elseif b:sections[0][1] != 1
        let b:sections = [[g:doctabs_default_section, 1, b:sections[0][1]-1, {}]] + b:sections
    endif

    " Reset window view and cursor position
    call winrestview(view)

    if g:doctabs_fold_others
        set fdm=manual
        " Set up folds
        let curline = line('.')
        for [tagname, tagpos, endpos, sectionview] in b:sections
            if curline >= tagpos && (endpos == '$' || curline <= endpos)
                execute tagpos . ',' . endpos . 'fold'
                execute tagpos . ',' . endpos . 'foldopen'
            else
                execute tagpos . ',' . endpos . 'fold'
            endif
        endfor
    endif
endfunction


" Render tabline and highlight current section
function! dtab#dtRenderTabline()
    set showtabline=2

    let line = ''
    
    let curline = line('.')
    let ii = 0
    for [tagname, tagpos, endpos, sectionview] in b:sections
        if curline >= tagpos && (endpos == '$' || curline <= endpos)
            let line .= '%#TabLineSel#'
        else
            let line .= '%#TabLine#'
        endif

        let name = tagname
        if g:doctabs_number_tabs
            let name = ii . ':' . name
        endif

        let line .= ' ' . name . ' '

        let ii += 1
    endfor

    " debugging
    " let line .= ' ' . strftime("%c")

    let line .= '%#TabLineFill#'

    let &l:tabline = line
endfunction


" Set up plugin state
function! dtab#dtInit()
    call dtab#dtComputeSections()

    if len(b:sections) == 1
        " If there is only one section, disable both rendering and move detection
        augroup doctabs
        au! CursorMoved *
        augroup END

        let showtabline = 1
        let &l:tabline = ''
    else
        " Set current line and current section
        call dtab#dtWindowInit()
        
        " Set autocommand on cursor move. Should be:
        "   Cheap if moving left/right
        "   Cheap if staying in section
        "   Only render if section changes

        augroup doctabs
        if g:doctabs_section_views
            if g:_doctabs_save_view_on_move
                au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call dtab#dtSectionMoved(1) | else | if g:doctabs_section_views | let b:sections[w:section][3] = winsaveview() | endif | endif | let w:curline = w:newline | endif
            else
                au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call dtab#dtSectionMoved(0) | endif | let w:curline = w:newline | endif
            endif
        else
            au! CursorMoved * let w:newline = line('.') | if w:curline != w:newline | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) | call dtab#dtSectionMoved(1) | endif | let w:curline = w:newline | endif
        endif
        augroup END

        call dtab#dtRenderTabline()
    endif
endfunction


" Update on window enter
function! dtab#dtWindowInit()
    let [w:section, w:curtag, w:tagstart, w:tagend, w:sectionview] = dtab#dtGetCurrentSection()
    let w:lastsection = get(w:, 'lastsection', -1)
    let w:curline = line('.')
    call dtab#dtRenderTabline()
endfunction


" Update on section move
function! dtab#dtSectionMoved(restore)
    let [w:newsection, w:curtag, w:tagstart, w:tagend, w:sectionview] = dtab#dtGetCurrentSection()
    
    if g:doctabs_fold_others
        set fdm=manual
        let [oldtag, oldstart, oldend, oldview] = b:sections[w:section]
        execute oldstart . ',' . oldend . 'foldclose'
        execute w:tagstart . ',' . w:tagend . 'foldopen'
        execute w:tagstart . ',' . w:tagend . 'foldopen'
    endif

    let w:lastsection = w:section
    let w:section = w:newsection

    if a:restore && g:doctabs_section_views
        " Restore everything except cursor position - the user knows where
        " they're going
        let curview = winsaveview()
        let w:sectionview['lnum'] = curview['lnum']
        let w:sectionview['col'] = curview['col']
        let w:sectionview['coladd'] = curview['coladd']
        call winrestview(w:sectionview)
    endif

    call dtab#dtRenderTabline()
endfunction

" ###JumpFuncs

" Jump to given section
function! dtab#dtJump(newsection)
    if type(a:newsection) != type(0)
        echoerr 'Invalid section "' . a:newsection . '": number required'
        return
    elseif a:newsection < 0
        echoerr 'Invalid section "' . a:newsection . '": less than 0 given'
        return
    elseif a:newsection >= len(b:sections)
        echoerr 'Invalid section "' . a:newsection . '": no such section'
        return
    end

    if g:doctabs_section_views
        " Save old view
        let b:sections[w:section][3] = winsaveview() 
        " with lnum relative to tagstart
        " let b:sections[w:section][3]['lnum'] -= b:sections[w:section][1]

        let [name, tagstart, tagend, tagview] = b:sections[a:newsection]

        let restore = {
                    \ 'lnum':      get(tagview,  'lnum',      0),
                    \ 'col':       get(tagview,  'col',       1),
                    \ 'topline':   get(tagview,  'topline',   tagstart),
                    \ 'topfill':   get(tagview,  'topfill',   0),
                    \ 'leftcol':   get(tagview,  'leftcol',   1),
                    \ }
                    " \ 'coladd':    get(tagview,  'coladd',    -1),
                    " \ 'curswant':  get(tagview,  'curswant',  -1),
                    " \ 'skipcol':   get(tagview,  'skipcol',   -1),

        " Sanity check that lnum is between tagstart and tagend
        if restore['lnum'] < tagstart || (tagend != '$' && restore['lnum'] > tagend)
            let restore['lnum'] = tagstart
        endif
        
        " Sanity check that topline is between tagstart and tagend
        if restore['topline'] < tagstart || (tagend != '$' && restore['topline'] > tagend)
            let restore['topline'] = tagstart
        endif

        call winrestview(restore)
    endif

    call dtab#dtSectionMoved(0)
endfunction


" Jump to alternate section
function! dtab#dtJumpAlt()
    if w:lastsection == -1
        echoerr 'No alternate section yet (did you just open this window?)'
        return
    endif

    call dtab#dtJump(w:lastsection)
endfunction


" Jump to next section
function! dtab#dtJumpNext()
    call dtab#dtJump((w:section + 1) % len(b:sections))
endfunction


" Jump to previous section
function! dtab#dtJumpPrev()
    call dtab#dtJump((len(b:sections) + w:section - 1) % len(b:sections))
endfunction


" Set up C-g keybindings
function! dtab#dtCgBindings()
    nnoremap <silent> <C-g>0 :call dtab#dtJump(0)<CR>
    nnoremap <silent> <C-g>1 :call dtab#dtJump(1)<CR>
    nnoremap <silent> <C-g>2 :call dtab#dtJump(2)<CR>
    nnoremap <silent> <C-g>3 :call dtab#dtJump(3)<CR>
    nnoremap <silent> <C-g>4 :call dtab#dtJump(4)<CR>
    nnoremap <silent> <C-g>5 :call dtab#dtJump(5)<CR>
    nnoremap <silent> <C-g>6 :call dtab#dtJump(6)<CR>
    nnoremap <silent> <C-g>7 :call dtab#dtJump(7)<CR>
    nnoremap <silent> <C-g>8 :call dtab#dtJump(8)<CR>
    nnoremap <silent> <C-g>9 :call dtab#dtJump(9)<CR>
    nnoremap <silent> <C-g><C-g> :call dtab#dtJumpAlt()<CR>
    nnoremap <silent> <C-g><C-n> :call dtab#dtJumpNext()<CR>
    nnoremap <silent> <C-g><C-p> :call dtab#dtJumpPrev()<CR>
    nnoremap <silent> <C-g>n :call dtab#dtJumpNext()<CR>
    nnoremap <silent> <C-g>p :call dtab#dtJumpPrev()<CR>
endfunction

