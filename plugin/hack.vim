" hack.vim - Hack typechecker integration for vim
" Language:     Hack (PHP)
" Maintainer:   Srećko Toroman <storoman@fb.com>
" Maintainer:   Max Wang <mwang@fb.com>
" URL:          https://github.com/hhvm/vim-hack
" Last Change:  April 3, 2014
"
" Copyright: (c) 2014, Facebook Inc.  All rights reserved.
"
" This source code is licensed under the BSD-style license found in the
" LICENSE file in the toplevel directory of this source tree.  An additional
" grant of patent rights can be found in the PATENTS file in the same
" directory.

if exists("g:loaded_hack")
  finish
endif
let g:loaded_hack = 1

if !exists('g:hack#hh_client')
  let g:hack#hh_client = 'hh_client'
endif

" Require the hh_client executable.
if !executable(g:hack#hh_client)
  finish
endif

" Lookup the identifier under cursor.
function! <SID>HackLookupCurrentIdentifier()
  silent let result = system(
  \ join(<SID>HackClientInvocation(['--identify-function', line('.').':'.col('.')])),
  \ getline(1, '$'))
  return substitute(result, '^\s*\(.\{-}\)\s*$', '\1', '') " strip ws
endfunction

" Main interface functions.
function! hack#find_refs(fn)
  call <SID>HackClientCall(['--find-refs', a:fn])
endfunction

function! hack#search(full_lookup, name)
  let name = a:name
  if name == ''
    " Look up full identifier.
    if a:full_lookup
      let name = <SID>HackLookupCurrentIdentifier()
    endif
    " Use current word.
    if name == ''
      let name = expand('<cword>')
    endif
  end
  call <SID>HackClientCall(['--search', name])
endfunction

" Get the Hack type at the current cursor position.
function! hack#get_type()
  let pos = line('.').':'.col('.')
  let cmd = join(<SID>HackClientInvocation(['--type-at-pos', pos]))
  let stdin = join(getline(1,'$'), "\n")

  let output = 'HackType: '.system(cmd, stdin)
  let output = substitute(output, '\n$', '', '')
  echo output
endfunction

" Go to the definition of the expression at the current cursor position.
function! hack#goto_def()
  if !has('nvim') && v:version < 800
    echom 'Vim 8.0 or Neovim is required for this function.'
    return
  endif

  let pos = line('.').':'.col('.')
  let cmd = join(<SID>HackClientInvocation([
  \ '--json',
  \ '--ide-get-definition',
  \ pos
  \ ]))
  let stdin = join(getline(1,'$'), "\n")

  let output = get(json_decode(system(cmd, stdin)), 0, {})
  if !has_key(output, 'definition_pos')
    return
  endif

  let pos = output.definition_pos
  if !empty(pos.filename)
    execute 'edit '.(pos.filename)
  endif
  call cursor(pos.line, pos.char_start)
endfunction

function! hack#format(from, to)
  if !executable(g:hack#hh_format)
    echo 'g:hack#hh_format not executable'
  endif

  if &modified
    echo 'Error[hack]: buffer has unsaved changes'
    return
  endif

  let frombyte = line2byte(a:from)
  let tobyte = line2byte(a:to) + strlen(getline(a:to))

  execute a:from.','.a:to.' ! '.g:hack#hh_format.
    \ ' --from '.frombyte.' --to '.tobyte.
    \ ' --root '.g:hack#root.' '.expand('%:p')
  let tmp = g:hack#enable
  " Disable auto checking
  let g:hack#enable = 0
  silent write
  let g:hack#enable = tmp
endfunction

" Commands and auto-typecheck.
command! HackType   call hack#get_type()
command! HackGotoDef call hack#goto_def()
command! -range=% HackFormat call hack#format(<line1>, <line2>)
command! -nargs=1 HackFindRefs call hack#find_refs(<q-args>)
command! -nargs=? -bang HackSearch call hack#search('<bang>' == '!', <q-args>)
