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

" ###Sections

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
            let matchgroup = substitute(matchgroup, '^\s*\(.\{-}\)\s*$', '\1', '')
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

" ###Rendering

" Render tabline and highlight current section
function! dtab#dtRenderTabline()
    set showtabline=2

    let line = ''

    let parts = ['', '', '']
    
    let curline = line('.')
    let ii = 0
    let which = 0
    for [tagname, tagpos, endpos, sectionview] in b:sections
        if curline >= tagpos && (endpos == '$' || curline <= endpos)
            let which = 1
        endif

        let name = tagname
        if g:doctabs_alpha_labels
            let labels = split(g:doctabs_labels, '\zs')
            if ii < len(labels)
                let name = labels[ii] . ':' . name
            else
                let name = ii . ':' . name
            endif
        elseif g:doctabs_number_tabs
            let name = ii . ':' . name
        endif

        let parts[which] .= ' ' . name . ' '

        if which == 1
            let which = 2
        endif

        let ii += 1
    endfor

    let linelen = len(parts[0]) + len(parts[1]) + len(parts[2])
    if len(parts[1]) >= &columns
        let parts[0] = ''
        let parts[1] = strpart(parts[1], 0, &columns)
        let parts[2] = ''
    elseif linelen > &columns
        let rem = &columns - len(parts[1])
        let sizeleft = rem / 2
        let sizeright = rem - sizeleft
        if sizeleft > len(parts[0])
            let sizeleft = len(parts[0])
            let sizeright = rem - sizeleft
        elseif sizeright > len(parts[2])
            let sizeright = len(parts[2])
            let sizeleft = rem - sizeright
        end
        
        if len(parts[0]) > sizeleft
            let parts[0] = '<' . strpart(parts[0], len(parts[0]) - sizeleft + 1, sizeleft - 1)
        endif

        if len(parts[2]) > sizeright
            let parts[2] = strpart(parts[2], 0, sizeright - 1) . '>'
        endif
    endif

    let line = '%#TabLine#' . parts[0] . '%#TabLineSel#' . parts[1] . '%#TabLine#' . parts[2] . '%#TabLineFill#'

    let &l:tabline = line
endfunction

" ###Init

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
                if g:_doctabs_section_fast_update == 1
                    au! CursorMoved * 
                        \ let w:newlen = line('$') 
                        \ | if w:curlen != w:newlen
                            \ | call dtab#dtUpdate()
                            \ | let w:curlen = w:newlen
                        \ | else
                            \ | let w:newline = line('.') 
                            \ | if w:curline != w:newline 
                                \ | if (w:newline < w:tagstart || 
                                    \ (w:tagend != '$' && w:newline > w:tagend)) 
                                    \ | call dtab#dtSectionMoved(1) 
                                \ | else 
                                    \ | if g:doctabs_section_views 
                                        \ | let b:sections[w:section][3] = winsaveview() 
                                    \ | endif 
                                \ | endif
                                \ | let w:curline = w:newline
                            \ | endif
                        \ | endif
                else
                    au! CursorMoved * 
                        \ let w:newline = line('.') 
                        \ | if w:curline != w:newline 
                            \ | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) 
                                \ | call dtab#dtSectionMoved(1) 
                            \ | else 
                                \ | if g:doctabs_section_views 
                                    \ | let b:sections[w:section][3] = winsaveview() 
                                \ | endif 
                            \ | endif 
                            \ | let w:curline = w:newline 
                        \ | endif
                endif
            else
                if g:_doctabs_section_fast_update == 1
                    au! CursorMoved * 
                        \ let w:newlen = line('$') 
                        \ | if w:curlen != w:newlen
                            \ | call dtab#dtUpdate()
                            \ | let w:curlen = w:newlen
                        \ | else
                            \ | let w:newline = line('.')
                            \ | if w:curline != w:newline
                                \ | if (w:newline < w:tagstart || 
                                    \ (w:tagend != '$' && w:newline > w:tagend))
                                    \ | call dtab#dtSectionMoved(0) 
                                \ | endif 
                                \ | let w:curline = w:newline 
                            \ | endif
                        \ | endif
                else
                    au! CursorMoved * 
                        \ let w:newline = line('.') 
                        \ | if w:curline != w:newline 
                            \ | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) 
                                \ | call dtab#dtSectionMoved(0) 
                            \ | endif 
                            \ | let w:curline = w:newline 
                        \ | endif
                endif
            endif
        else
            if g:_doctabs_section_fast_update == 1
                au! CursorMoved * 
                    \ let w:newlen = line('$') 
                    \ | if w:curlen != w:newlen
                        \ | call dtab#dtUpdate()
                        \ | let w:curlen = w:newlen
                    \ | else
                        \ | let w:newline = line('.') 
                        \ | if w:curline != w:newline 
                            \ | if (w:newline < w:tagstart || 
                                \ (w:tagend != '$' && w:newline > w:tagend)) 
                                \ | call dtab#dtSectionMoved(1) 
                            \ | endif 
                            \ | let w:curline = w:newline 
                        \ | endif
                    \ | endif
            else
                au! CursorMoved * 
                    \ let w:newline = line('.') 
                    \ | if w:curline != w:newline 
                        \ | if (w:newline < w:tagstart || (w:tagend != '$' && w:newline > w:tagend)) 
                            \ | call dtab#dtSectionMoved(1) 
                        \ | endif 
                        \ | let w:curline = w:newline 
                    \ | endif
            endif
        endif
        augroup END

        call dtab#dtRenderTabline()
    endif
endfunction

" Update sections and re-render
function! dtab#dtUpdate()
    call dtab#dtComputeSections()
    call dtab#dtRenderTabline()
endfunction

" Init per-window state (current line and section, number of lines, etc)
function! dtab#dtWindowInit()
    let [w:section, w:curtag, w:tagstart, w:tagend, w:sectionview] = dtab#dtGetCurrentSection()
    let w:lastsection = get(w:, 'lastsection', -1)
    let w:curline = line('.')
    let w:curlen = line('$')
    call dtab#dtRenderTabline()
endfunction

" ###Jumping

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
        " echoerr 'No alternate section yet (did you just open this window?)'
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

" ###Bindings

" Set up keybindings once g:doctabs_alpha_labels is available
function! dtab#dtBindings(which)
    " The jump to alternate binding depends on whether we use Leader or a chord
    if a:which == 'Leader'
        execute 'nnoremap <silent> <' . a:which . '>gg :call dtab#dtJumpAlt()<CR>'
    else
        execute 'nnoremap <silent> <' . a:which . '><' . a:which . '> :call dtab#dtJumpAlt()<CR>'
    end

    " The form of next and prev is the same
    execute 'nnoremap <silent> <' . a:which . '>n :call dtab#dtJumpNext()<CR>'
    execute 'nnoremap <silent> <' . a:which . '>p :call dtab#dtJumpPrev()<CR>'

    " The jump to label binding also depends on whether we use Leader or
    " a chord
    let labels = split('0123456789', '\zs')
    if g:doctabs_alpha_labels
        let labels = split(g:doctabs_labels, '\zs')
    end

    let ii = 0
    for label in labels
        if a:which == 'Leader'
            execute 'nnoremap <silent> <' . a:which . '>g' . label . ' :call dtab#dtJump(' . ii . ')<CR>'
        else
            execute 'nnoremap <silent> <' . a:which . '>' . label . ' :call dtab#dtJump(' . ii . ')<CR>'
        end
        let ii += 1
    endfor
endfunction

" Set up C-g keybindings. This method is provided for backward-compatibility.
function! dtab#dtCgBindings()
    call dtab#dtPrefixBindings('C-g')
endfunction

" Set up bindings with a given prefix
function! dtab#dtPrefixBindings(prefix)
    " We don't actually set any bindings here, as the exact bindings depend on
    " g:doctabs_alpha_labels, which is not necessarily loaded at ~/.vimrc time

    if a:prefix == ''
        echoerr "Can't specify an empty keybinding prefix"
        return
    endif

    let g:_doctabs_user_prefix = a:prefix
endfunction

