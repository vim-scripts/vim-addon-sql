" vimscript installer file intenteded to be sourced in text editor vim.
" You'll be notified which files will be overridden, saved to disk in advance.

" alias sensitive SQL completion support (MySQL implemented, should be easy to add others)
" this region is distributed whith each installation script.

let s:region_line = "^\\s*\"\\s*\\%(start\\|end\\)\\s*region\\s*'\\zs.*\\ze'"
let s:this_filename = expand('<sfile>')

let g:a=s:region_line
function! s:GetListOfRegions(lines)
  let regions = filter(deepcopy(a:lines), " v:val =~ ".string(s:region_line))
  let regions = map(regions, "matchstr(v:val, ".string(s:region_line).")")
  " filter duplicate elements:
  let regions_uniq = {}
  for region in  regions
    let regions_uniq[region] = 0
  endfor
  return keys(regions_uniq)
endfunction

function! s:ExtractRegion(lines, region_name)
  let result = []
  let l_count = len(a:lines)
  let escaped_region_name = substitute(a:region_name, '\\', '\\\\', 'g')
  for l in a:lines
    if l =~ "^\\s*\"\\s*start\\s*region\\s*'".escaped_region_name."'"
      let result = []
    elseif l =~ "^\\s*\"\\s*end\\s*region\\s*'".escaped_region_name."'"
      return result
    else 
      call add(result, l)
    endif
  endfor
  if len(result) == l_count
    throw "ExtractRegion: extracting region ".a:region_name." requested but not found!"
  else
    return result
  endif
endfunction

" I'd like to use vl#lib#files#filefunctions#FileDir here, but his file has to
" be distributed first. So we have local copy here
function! s:FileDir(file)
  return substitute(a:file,'\%(/\|\\\)[^/\\]*$','','')
endfunction
" the same here
fun! s:EnsureDirectoryExists(dir)
  let d = expand(a:dir)
  if !isdirectory(d)
    call mkdir(d,'p')
  endif
endfun

" scans this file for regions 
" " start region 'file <location>'
" and asks the user wether for confirmation to write them to disk
" paramter file should be expand('<sfile>')
function! s:DistributeAddedFiles(file)
  let this_file = readfile(a:file)
  let files = map( filter(s:GetListOfRegions(this_file), "v:val  =~ 'file '"),
	       \ "substitute(v:val,'^file ','' ,'')")
  let file_regions = map( deepcopy(files),
	\ "s:UnEscape(s:ExtractRegion(this_file,'file '.v:val))")
  echo "You'll be asked for confirmation before anything happens."
  if len(filter(deepcopy(files),"v:val =~'<dotvim>'")) > 0
    echo "Some files will be saved to a vimruntimepath folder. Choose one (default should be ok in most cases)"
    let dotvim = substitute(input('.vim directory :',
		 	\ expand(substitute(&runtimepath,',.*','','')),'dir'),
			\ '/$\|\\$','','g')
    let dotvim = substitute(dotvim, '\\', '\\\\', 'g')
    call map(files, "substitute(v:val,'<dotvim>',".string(dotvim).",'')")
  endif
  echo " "
  let already_existing_files = []
  let already_existing_files_which_differ = []
  for i in range(len(files)-1, 0 , -1)
    if filereadable(files[i])
      let file_on_disk = readfile(files[i])
      if file_on_disk == file_regions[i]
	call add(already_existing_files, files[i])
        call remove( files, i)
	call remove( file_regions, i)
      else
	call add(already_existing_files_which_differ, files[i])
      endif
    endif
  endfor
  if len(already_existing_files) > 0
    echo "files which won't be written because they are already there:"
    echo join(already_existing_files, "\n")
  endif
  echo "files to be written:"
  if len(files) == 0
    echo "everything seems to be installed already! exiting."
    return
  endif
  echo join(files, "\n")
  if len(already_existing_files_which_differ) > 0
    echoe " !! be careful: The following files will be overwritten !!"
    echo join(already_existing_files_which_differ,"\n")
  endif
  if input("The files listed above will be written directories will be created if necessary. Procced? [y/ s.th. else to abort] ") == "y"
    for i in range(0, len(files)-1)
      let file = files[i]
      let directory = s:FileDir(file)
      call s:EnsureDirectoryExists(directory)
      echo 'writing file '.file
      call writefile(file_regions[i], file)
    endfor
  endif
endfunction

function! s:Escape(file)
  call map(a:file, "'\" '.v:val")
  return a:file
endfunction
function! s:UnEscape(file)
  call map(a:file, "substitute(v:val,'^\" \\=','','')")
  return a:file
endfunction


" invoke installer function
call s:DistributeAddedFiles(s:this_filename)


"  ===================== attached files : ================ 


" start region 'file <dotvim>/autoload/vl/lib/system/system.vim'
" "|fld   description : provides a convinient function checking the return value "when running system
" "|fld   keywords : system() replacement
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2007 Aug 29 07:35:34
" "|fld   version: 0.0
" 
" 
" " usage: vl#lib#system#system#System( ['echo', 'foo'], {'stdin-text' : 'will be ignored by echo', status : 0 })
" function! vl#lib#system#system#System( items, ... )
"   exec vl#lib#brief#args#GetOptionalArg('opts','{}')
" 
"   let cmd = ''
"   for a in a:items
"     let cmd .=  ' '.escape(a, "* '\"\\`")
"   endfor
"   if has_key(opts, 'stdin-text')
"     let f = tempname()
"     " don't know why writefile(["line 1\nline 2"], f, 'b') has a different
"     " result?
"     call writefile(split(opts['stdin-text'],"\n"), f, 'b')
"     let cmd = cmd. ' < '.f
"   endif
" 
"   call vl#lib#ide#logging#Log('executing system command '.cmd)
"   let result = system(cmd)
"   if exists('f')
"     "call delete(f)
"   endif
"   let g:systemResult = result
" 
"   let s = get(opts,'status',0)
"   if v:shell_error !=  s
"     let g:systemResult = result
"     throw "command ".cmd."failed with exit code ".v:shell_error
"      \ . " but ".s." expected. Have a look at the program output with :echo g:systemResult".repeat(' ',400)
"      \ . " the first 500 chars of the result are \n".strpart(result,0,500)
"   endif
"   return result
" endfunction
" 
" end region 'file <dotvim>/autoload/vl/lib/system/system.vim'


" start region 'file <dotvim>/autoload/vl/settings.vim'
" "|fld   description : provide some basic settings for vimlib
" "|fld   keywords : <+ this is used to index / group scripts ?+> 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2006 Nov 01 09:44:07
" "|fld   version: 0.0
" "|fld   dependencies: <+ vim-python, vim-perl, unix-tool sed, ... +>
" "|fld   contributors : <+credits to+>
" "|fld   maturity: stable
" "|
" "|H1__  Documentation
" "|
" "|H2__  settigns
" "|set   <description of setting(s)>
" "| function! a#Dotvim()
" "|
" "|hist <+ historical information. (Which changes have been made ?) +>
" "|
" "|TODO:  <+ its a good start to write a list to do first+>
" 
" let s:vimlibdir = substitute(expand('<sfile>'),'[\//]autoload.*','','').'/'
" 
" "|func the .vim or vimfiles directory containning your plugins and so on...
" function! vl#settings#DotvimDir()
"   if !exists('g:dotvim')
"     let g:dotvim = substitute(&runtimepath,',.*','','')
"   endif
"   return g:dotvim.'/'
" endfunction
" 
" function! vl#settings#VimlibDir()
"   return s:vimlibdir
" endfunction
" end region 'file <dotvim>/autoload/vl/settings.vim'


" start region 'file <dotvim>/autoload/vl/lib/conversion/string.vim'
" "|fld   description : <+ really short description to get a picture. less than 2 sentences if possible +>
" "|fld   keywords : <+ this is used to index / group scripts ?+> 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2007 Feb 08 12:50:19
" "|fld   version: 0.0
" "|fld   dependencies: <+ vim-python, vim-perl, unix-tool sed, ... +>
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: unusable, experimental
" "|fld     os: <+ remove this value if script is os independent +>
" "|
" "|H1__  Documentation
" "|
" "|p     <+some more in depth discription
" "|+     <+ joined line ... +>
" "|p     second paragraph
" "|H2_   typical usage
" "|
" "|pl    " <+ description +>
" "|      <+ plugin command +>
" "|
" "|      " <+ description +>
" "|      <+ plugin mapping +>
" "|
" "|ftp   " <+ description +>
" "|     <command -nargs=0 -buffer XY2 :echo "XY2"
" "|
" "|H2__  settings
" "|set   <description of setting(s)>
" "|      "description
" "|
" "|
" "|hist <+ historical information. (Which changes have been made ?) +>
" "|
" "|TODO:  <+ its a good start to write a list to do first+>
" "|+      
" "|+      
" "|+      
" "|rm roadmap (what to do, where to go?)
" 
" 
" " in contrast to string() this function escapes using "
" " not complete
" function! vl#lib#conversion#string#ToDoubleQuotedString(str)
"   return '"'.vl#lib#conversion#string#QuoteBackslashSpecial(a:str).'"'
" endfunction
" 
" function! vl#lib#conversion#string#QuoteBackslashSpecial(str)
"   " use escape() of vim instead ! (TODO)
"   let subst = [ 
" 	    \   ['\\'  ,'\\\\']
"             \ , ["\r" ,'\\r']
" 	    \ , ["\t" ,'\\t']
" 	    \ , ['"' ,'\\"']
" 	    \ ]
"   let s = a:str
"   for su in subst
"     let s = substitute(s, su[0], su[1] ,'g')
"   endfor
"   return s
" endfunction
" 
" function! vl#lib#conversion#string#EscapCmd(string)
"   return substitute(a:string,'|','\|','g')
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/conversion/string.vim'


" start region 'file <dotvim>/autoload/vl/lib/ide/logging.vim'
" "|fld   description : provides logging messages in a buffer
" "|fld   keywords : logging vimscript 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2007 Apr 20 05:03:31
" "|fld   version: 0.0
" "|fld   maturity: unusable, experimental
" "|
" "|H1__  Documentation
" "|H2_   settings
" "|      You can choose log_target (see source) to log to "['echom','file://<file>','buffer']
" "|p     file:// isn't implemented yet
" "|H2_   Example usage:
" "|pre
" "|      call vl#lib#ide#logging#Enter('my sect')
" "|      call vl#lib#ide#logging#Log("text -important",10)
" "|      call vl#lib#ide#logging#Leave()
" "|      call vl#lib#ide#logging#LogWindowAction('show')
" "|H3_   importance
" "|      0 - 2 debug (not logged by default)
" "|      3 - 4 notice (logged by default)
" "|      >= 5 viewed causes log window popup by default
" "|      5 - 7  experienced users don't have to see it (eg "direcotry xy created" messages)
" "|      8 - 10 user should see them (eg. operation failed ..)
" "|TODO  testing/ highlighting ? rewrite using resultBuffer.vim
" "
" " There is some trouble somewhere - thats why I've switched it off by using
" " log_level 20
" 
" " using echom may make some scripts no longer work as they depend on no output
" " (because vim else will show a "press enter" which catches <cr> which should
" " have gone somewhere else (TODO: fix that somehow) Examples which might fail:
" " include dependend c completion)
" let s:log_targets=vl#lib#vimscript#scriptsettings#Load('vl.lib.ide.logging.log_targets',
"   \ ['buffer','file'])
" 
" " if log_targets contains 'file' log to this file
" let s:log_file=vl#lib#vimscript#scriptsettings#Load('vl.lib.ide.logging.log_file',
"   \ g:store_vl_stuff.'/vl.log')
" 
" " pop up the log window if the importance of the logged message is greater
" " than this value (typicallly bewtween 0 - 10)
" let g:vl_pop_up_log_window=vl#lib#vimscript#scriptsettings#Load('vl.lib.ide.logging.pop_up_log_window',
"   \ 6 )
" 
" " log everything more important or equal to this value - default 2
" let g:vl_log_level=vl#lib#vimscript#scriptsettings#Load('vl.lib.ide.logging.vl_log_level',
"   \ 20 )
" 
" " you can loose most logging messages without beeing harmed
" let s:set_unmodified=vl#lib#vimscript#scriptsettings#Load('vl.lib.ide.logging.',
"   \ 1 )
" let s:indent = 0
" " log time_stamp and importance
" let s:add_header = 0
" 
" " TODO: log to file ?
" let s:known_log_targets = { 
"  \   'echom'  : 'for msgline in msg | echom msgline | endfor'
"  \ , 'buffer' : 'call vl#lib#ide#logging#LogWindowAction("add message", msg, importance)'
"  \ , 'file'   : 'call writefile(extend(vl#lib#files#filefunctions#ReadFile(s:log_file,[]), msg),s:log_file)'
"  \ }
" 
" let s:log_window_name = '__log_window__'
" 
" let s:time_format = vl#lib#vimscript#scriptsettings#Load('vl.lib.ide.logging.log_targets',
"   \ "[%= strftime('%y-%b-%d %X') %]")
" 
" " see Enter Leave
" let s:sections = []
" 
" "func make the logfile public
" function! vl#lib#ide#logging#LogFile()
"   return s:log_file
" endfunction
" 
" "func log a message
" "     optinal argument: importance.
" function! vl#lib#ide#logging#Log(msg,...)
"   exec vl#lib#brief#args#GetOptionalArg('importance',string(5))
"   if importance < g:vl_log_level
"     return
"   endif
"   if type(a:msg) == 1
"     let msg = [a:msg]
"   else
"     let msg = a:msg
"   endif
"   if s:add_header
"     let header = printf("== %2d, %s" importance
"      \ , vl#lib#template#template#SimplePreprocessTemplateText(s:time_format))
"     let msg = extend([header], msg)
"   endif
"   let indent = repeat(s:indent, '  ')
"   call map(msg, string(indent).'.v:val')
"   for i in s:log_targets
"     exec s:known_log_targets[i]
"   endfor
" endfunction
" 
" function! vl#lib#ide#logging#Enter(section)
"   let s:indent = s:indent+1
"   call vl#lib#ide#logging#Log('entering section '.a:section)
"   call add(s:sections, a:section)
" endfunction
" 
" function! vl#lib#ide#logging#Leave()
"   call vl#lib#ide#logging#Log('leaving section '
"    \ . vl#lib#listdict#list#PopLast(s:sections) )
" 
"   let s:indent = s:indent-1
" endfunction
" 
" "func  actions: 
" " 'add message': params msg, optional importance (default 5), will be scrolled down
" " 'show': (focus will be set to logging window)
" " 'hide': hide the window
" function! vl#lib#ide#logging#LogWindowAction(action, ...)
"   let current_buf = bufnr('%')
"   let current_window = winnr()
"   let reset_window_focus = 1
" 
"   let was_visible = bufwinnr(bufnr(s:log_window_name)) >= 0
"   silent! let new = bufnr(s:log_window_name) == -1
"    
"   let buf_nr = bufnr(s:log_window_name,1)
" 
"   if buf_nr < 0
"     " create logging window (using preview is the only way I know
"     silent! exec 'sp '.s:log_window_name
"     setlocal buftype=nofile
"     setlocal noswapfile
"     setlocal noreadonly
"     call vl#lib#ide#logging#LogWindowAction('add message', '" use Ctrl-w z to close this logging window')
"     let is_visible = 1
"   else
"     let is_visible = was_visible
"   endif
" 
"   if new
"     " make visible
"     silent! exec 'sp '.s:log_window_name
"     exec bufwinnr(bufnr(s:log_window_name)).' wincmd w'
"     call append(getline('$'), [
" 	  \   '============= logging window ========================================='
" 	  \ , ' see file autoload/l/lib/ide/logging.vim to customize logging behaviour'
"           \ , ' press <cr> to hide' ] )
"     noremap <buffer> <cr> :hide<cr>
"     let is_visible = 1
"   endif
" 
"   let hide_lw = !was_visible
" 
"   if a:action == 'add message'
"     exec vl#lib#brief#args#GetOptionalArg('msg', string('no message passed ??'),1)
"     exec vl#lib#brief#args#GetOptionalArg('importance', string(5) ,2)
"     if !is_visible
"       " make visible
"       silent! exec 'sp '.s:log_window_name
"     endif
"     " set focus
"     exec bufwinnr(bufnr(s:log_window_name)).' wincmd w'
"     " add lines
"     call append(line('$'), msg)
"     normal G
"     if s:set_unmodified
"       set nomodified
"     endif
"     let hide_lw = !was_visible && importance < g:vl_pop_up_log_window
"   elseif a:action == 'show'
"     if !is_visible
"       exec 'sp '.s:log_window_name
"     endif
"     " set focus
"     exec bufwinnr(bufnr(s:log_window_name)).' wincmd w'
"     let hide_lw = 0
"     let reset_window_focus = 0
"   elseif a:action == 'hide'
"     if was_visible
"       let hide_lw = 1
"     endif
"   endif
" 
"   if hide_lw
"     " set focus
"     exec bufwinnr(bufnr(s:log_window_name)).' wincmd w'
"     hide
"   endif
" 
"   " switch to buffer which had focus before again
"   if reset_window_focus
"     exec current_window.' wincmd w'
"   endif
" endfunction
" 
" function! vl#lib#ide#logging#AddUICommands()
"   command! LogWindow call vl#lib#ide#logging#LogWindowAction('show')
"   command! LogShowAll let g:vl_pop_up_log_window=0 <bar> let g:vl_log_level = 0
"   command! Log call vl#lib#ide#logging#Log(<f-args>)
" endfunction
" 
" end region 'file <dotvim>/autoload/vl/lib/ide/logging.vim'


" start region 'file <dotvim>/autoload/vl/lib/brief/args.vim'
" "|fld   description : get additional args
" "|fld   keywords : "shorten vimscript" 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2006 Nov 06 21:31:32
" "|fld   version: 0.0
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: stable
" "|
" "|H1__  Documentation
" "|
" 
" "|p     returns optional argument or default value
" "|p     Example usage:
" "|code  function! F(...)
" "|        exec GetOptionalArg('optional_arg',string('no optional arg given'))
" "|        exec GetOptionalArg('snd_optional_arg',string('no optional arg given'),2)
" "|        echo 'optional arg is '.string(optional_arg)
" "|      endfunction
" function! vl#lib#brief#args#GetOptionalArg( name, default, ...)
"   if a:0 == 1
"     let idx = a:1
"   else
"     let idx = 1
"   endif
"   if type( a:default) != 1
"     throw "wrong type: default parameter of vl#lib#brief#args#GetOptionalArg must be a string, use string(value)"
"   endif
"   let script = [ "if a:0 >= ". idx
" 	     \ , "  let ".a:name." = a:".idx
" 	     \ , "else"
" 	     \ , "  let ".a:name." = ".a:default
" 	     \ , "endif"
" 	     \ ]
"   return join( script, "\n")
" endfunction
" 
" "|func    creates a dict out of it'arguments arguments are given as key:value
" "|+       where you can omit key when specifying default keys as list
" "|        meant to be used with commands (See contextcompletion.vim where it
" "|        is used)
" "| 
" "| example :
" "|pre    command -nargs=* Command call FunctionWhichTakesDict(vl#lib#brief#args#CommandArgsAsDict(['a','b','c'], <f-args> ))
" "|       Command a:a c:c b:b
" "|       Command a b c
" "|       Command a:a b c
" "|       will all result in
" "|       {'a':'a', 'b':'b', 'c':'c'}
" "|       
" "|       drawback: you can only pass strings
" function! vl#lib#brief#args#CommandArgsAsDict( defaultkeys, ... )
"   let dict = {}
"   let key_idx = 0
"   let dk = deepcopy(a:defaultkeys)
"   for arg in a:000
"     let pos=-1
"     while pos < strlen(arg)
"       let pos = stridx(arg, ':', pos+1)
"       if arg[pos-1] != '\'
"         break
"       endif
"     endwhile
"     if pos == -1
"       let dict[vl#lib#listdict#list#Pop(dk,'superfluous')] = arg
"       let key_idx = key_idx +1
"     else
"       let key = strpart(arg, 0, pos)
"       let dict[ key ] = strpart(arg, pos+1)
"       call filter(dk, 'v:val != '.string(key) )
"     endif
"   endfor
"   return dict
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/brief/args.vim'


" start region 'file <dotvim>/autoload/vl/ui/userSelection.vim'
" "|fld   description : some abstraction on input list
" "|fld   keywords : "choose item from list" 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2006 Nov 15 00:52:16
" "|fld   version: 0.0
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: stable
" "|
" "|H1__  Documentation
" "|
" "|p     <+some more in depth discription
" "|+     <+ joined line ... +>
" "|p     second paragraph
" "|H2_   typical usage
" "|
" "|pl    " <+ description +>
" "|      <+ plugin command +>
" "|
" "|      " <+ description +>
" "|      <+ plugin mapping +>
" "|
" "|ftp   " <+ description +>
" "|     <command -nargs=0 -buffer XY2 :echo "XY2"
" "|
" "|H2__  settings
" "|set   <description of setting(s)>
" "|      "description
" "|      use this option to not use input list but getchar.
" "|      Thus you can just type 1/2 ...  01/02 .. 10 instead of 1<cr>
" let s:use_getchar=vl#lib#vimscript#scriptsettings#Load('vl.ui.userSelection.use_getchar',1)
" "1
" "|
" "|hist <+ historical information. (Which changes have been made ?) +>
" "|
" "|TODO:  <+ its a good start to write a list to do first+>
" "|+      
" "|+      
" "|+      
" "|rm roadmap (what to do, where to go?)
" "
" " I could imagine showing the items in a buffer and providing a continuation
" " function..  I need more time to implement it ;)
" 
" "|func the same as inputlist except that it uses getchar if option is set.
" "|+    This way you don't have to type the return key
" function! vl#ui#userSelection#Inputlist(list)
"   if s:use_getchar
"     echo join(a:list,"\n")
"     echo "choose a number :"
"     let answer = ''
"     for i in range(1,len(string(len(a:list))))
"       let c = getchar()
"       if c == 13 
" 	break
"       endif
"       let answer .= nr2char(c)
"     endfor
"     let g:answer = answer
"     if len(matchstr(answer, '\D')) > 0
"       return 0
"     else
"       return answer
"     endif
"   else
"     return inputlist(a:list)
"   endif
" endfunction
" 
" "|func  returns: item by default
" "|      optional parameter: "return index" to return the index instead of the value
" "|                          "return both" t return both ([index,item]  [-1,""] in case of no selection )
" function! vl#ui#userSelection#LetUserSelectOneOf(caption, list, ...)
"   let list_to_show = [a:caption]
"   " add numbers
"   for i in range(1,len(a:list))
"     call add(list_to_show, i.') '.a:list[i-1])
"   endfor
"   let index = vl#ui#userSelection#Inputlist(list_to_show)
"   if index == 0
"     let result = [ -1,  ""]
"   else 
"     let result = [index -1, a:list[index -1] ]
"   endif
"   if a:0 > 0
"     if a:1 == "return index"
"       return result[0] " return index
"     else
"       return result " return both
"     endif
"   else
"     return result[1] "return item
"   endif
" endfunction
" 
" "|func if list contains more than one item let the user select one
" "|     else return the one item
" function! vl#ui#userSelection#LetUserSelectIfThereIsAChoice(caption, list, ...)
"   if len(a:list) == 0
"     throw "LetUserSelectIfThereIsAChoice: list has no elements"
"   elseif len(a:list) == 1
"     return a:list[0]
"   else
"     if a:0 > 0 
"       return vl#ui#userSelection#LetUserSelectOneOf(a:caption, a:list, a:1)
"     else
"       return vl#ui#userSelection#LetUserSelectOneOf(a:caption, a:list)
"   endif
" endfunction
" 
" function! vl#ui#userSelection#LetUserSelectIfThereIsAChoiceAppendExtraInfo(
"       \ caption, list, additionalInfo, ...)
"   let listToShow = vl#lib#listdict#list#MapCopy(a:list, 
"         \ "Val.' '.string(".a:additionalInfo.")" )
"   let idx = vl#ui#userSelection#LetUserSelectIfThereIsAChoice(
"         \ a:caption, listToShow, "return index")
"   if a:0 > 0
"     if a:1 == "return index"
"       return idx " return index
"     else
"       return [idx, a:list[idx]] " return both
"     endif
"   else
"     return a:list[idx] "return item
"   endif
" endfunction
" 
" " is a stub which can be used
" " returns a list instead compared to SeletOneOf (copied)
" " consider using extending userSettings instead
" "function! vl#ui#userSelection#LetUserSelectMany(caption, list, ...)
"  "TODO
" "endfunction
" end region 'file <dotvim>/autoload/vl/ui/userSelection.vim'


" start region 'file <dotvim>/autoload/vl/lib/files/filefunctions.vim'
" " script-purpose: provide some useful file functions I did need yet
" " author: Marc Weber
" 
" " can't use load setting here here (would be  recursive as ReadFile is defined here)
" let s:wine_root='z:/'
" " returns the directory which contains this folder/ file
" " expand('%:p:h') doesn't work here
" fun! vl#lib#files#filefunctions#FileDir(file)
"   "return substitute(a:file,'\%(/\|\\\)[^/\\]*$','','')
"   return matchstr(a:file, '^\zs.*\ze[/\\]' )
" endfun
" 
" " returns the name of this file
" fun! vl#lib#files#filefunctions#FileName(file)
"   return substitute(a:file,'.*\%(/\|\\\)','','')
" endfun
" 
" fun! vl#lib#files#filefunctions#RelativeFileComponent(dir, file)
"   return substitute(a:file, '^'.expand(a:dir).'\%(/\|\\\)\=','','')
" endfun
" 
" function! vl#lib#files#filefunctions#PathAbsolute(p)
"   return strpart(a:p,0,1) == "/" || a:p =~ '[a-zA-Z]:\\'
" endfunction
" 
" fun! vl#lib#files#filefunctions#JoinPaths(a,b)
"   if vl#lib#files#filefunctions#PathAbsolute(a:b)
"     return a:b
"   elseif a:a==''
"     return a:b
"   else
"     return substitute(a:a,'[/\\]$','','').'/'.substitute(a:b,'^[/\\]','','')
"   endif
"   "let a = copy(a:000)
"   "call map(a, "substitute(v:val,'\%(^[/\\]\)\|\%([/\\]$\)','','g')")
"   "return join(a,'/')
" endfun
" 
" " returns 1 if directory has been created
" fun! vl#lib#files#filefunctions#EnsureDirectoryExists(dir)
"   let d = expand(a:dir)
"   if !isdirectory(d)
"     call mkdir(d,'p')
"     return 1
"   endif
"   return 0
" endfun
" 
" "|func replaces non word characters with _. Thus the os should accept this as
" "|     filename
" fun! vl#lib#files#filefunctions#FileHashValue(file)
"   "return substitute(a:file,'\.\|#\|''\|(\|)\|/\|\\\|{\|}\|\$\|:','_','g')
"   return substitute(a:file,'\W','_','g')
" endfun
" 
" " expands filename and supports a default value in case file doesn't exist
" function! vl#lib#files#filefunctions#ReadFile(filename, default)
"   let  fn = expand(a:filename)
"   if filereadable(fn)
"     return readfile(fn)
"   else
"     return a:default
"   endif
" endfunction
" 
" " expands filename and ensures that the directory is created
" function! vl#lib#files#filefunctions#WriteFile(list, filename)
"   let  fn = expand(a:filename)
"   let fd = vl#lib#files#filefunctions#FileDir(fn)
"   call vl#lib#files#filefunctions#EnsureDirectoryExists(fd)
"   call writefile(a:list,fn)
" endfunction
" 
" "|func This implementation only works on unix by now
" function! vl#lib#files#filefunctions#RemoveDirectoryRecursively(directory)
"   if !has('unix')
"     echo "Please remove ".a:directory." manually:"
"     echoe "vl#lib#files#filefunctions#RemoveDirectoryRecursively() has to be implemented for none unix vim versions"
"   else
"     call system("rm -fr ".expand(a:directory))
"   endif
" endfunction
" 
" "| add trailing / or \ on windows if not present
" function! vl#lib#files#filefunctions#AddTrailingDelimiter(path)
"   return substitute(a:path,'[^/\\]\zs\ze$',expand('/'),'')
" endfunction
" 
" "| if you pass dir a/b/c ["a/b/c","a/b","a"] will be returned
" function! vl#lib#files#filefunctions#WalkUp(path)
"   let sep='\zs.*\ze[/\\].*'
"   let result = [a:path]
"   let path = a:path
"   while 1
"     let path=matchstr(path, sep)
"     if path==""
"       break
"     endif
"     call add(result, path)
"   endwhile
"   return result
" endfunction
" 
" "func usage: WalkUpAndFind("mydir","tags")
" "let tags=vl#lib#files#filefunctions#WalkUpAndFind(a:path,"glob(vl#lib#files#filefunctions#JoinPaths(path,'tags'))",1)
" " consider using findfile of vim
" " optional arg: 1 : continue even if a file was found
" " "all" to return all visited pathes as well
" function! vl#lib#files#filefunctions#WalkUpAndFind(path,f_as_text,...)
"   exec vl#lib#brief#args#GetOptionalArg("option",string(0))
"   let matches = []
"   for path in vl#lib#files#filefunctions#WalkUp(a:path)
"     exec 'let item = '.a:f_as_text
"     if (len(item) >0 )
"       call add(matches, item)
"       if option == 0
" 	break
"       endif
"     elseif option == "all" && type(option) == type("all")
"       call add(matches, path)
"     endif
"   endfor
"   if option == "all"
"     return matches
"   else
"     if len(matches) > 0 
"       if option == 1
"         return matches
"       else
"         return matches[0]
"       endif
"     else
"       return []
"     endif
"   endif
" endfunction
" 
" function! vl#lib#files#filefunctions#PathToWine(path)
"   if has('unix')
"     return s:wine_root.substitute(a:path,'^[/\\]','','')
"   else
"     return a:path
"   endif
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/files/filefunctions.vim'


" start region 'file <dotvim>/autoload/vl/lib/buffer/splitlineatcursor.vim'
" " script-purpose: get the current line and returns an array containg the text till and from the cursor to eol
" " author: Marc Weber
" 
" " blah<cursor>foo will return ["blah","foo"]
" fun! vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"   let pos = col('.') -1
"   let line = getline('.')
"   return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/buffer/splitlineatcursor.vim'


" start region 'file <dotvim>/autoload/vl/lib/files/scan_and_cache_file.vim'
" "|fld   description : Get some content from file and cache it.
" "|fld   keywords : cache, filecontent 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2006 Oct 03 13:22:17
" "|fld   version: 0.0
" "|fld   maturity: tested on linux and windows
" "|
" "|doc   
" "|H1__  Documentation
" "|
" "|p     Use
" "|code  let scan_result = ScanIfNewer('<file_path>','<scan_func>')
" "|p     this will return the scanned file or the cached previous value
" "|
" "|H2_   Known problems: If two scripts want to use ScanIfNewer only the last
" "|+     value will be kept
" "|
" "|H2_   Examples:
" "|      See autoload/vl/dev/vimscript/vimfile.vim function ScanVimFile
" "|
" "|set   
" "|      " set s:cache_results to 1 to cache scanned results in files located
" "|        in s:cache_dir
" let s:cache_results=vl#lib#vimscript#scriptsettings#Load(
"   \ 'vl.lib.files.scan_and_cache_file.cache_results', 1)
" let s:cache_dir=vl#lib#vimscript#scriptsettings#Load(
"   \ 'vl.lib.files.scan_and_cache_file.cache_dir',
"  \ g:store_vl_stuff.'/scan_and_cache_file_cache')
" "|
" "|pl    " clear cache
" "|      command! ClearScanAndCacheFileCache :call ClearScanAndCacheFileCache()
" "|TODO add command to clear cache.. because it will grow and grow.
" 
" "|func  scans the file using given function if it hasn't been scanned yet returns
" "|      result of this scan or previous scan.
" "|      scan_func takes the file as line list ( readfile ) and should return the
" "|+     scanned file info
" function! vl#lib#files#scan_and_cache_file#ScanIfNewer(file, asLines, scan_func, ...)
"   exec vl#lib#brief#args#GetOptionalArg("cache",string("1"))
"   let file = expand(a:file)
"   let func_as_string = string(a:scan_func)
"   if !exists('g:scanned_files')
"     let g:scanned_files = {}
"   endif
"   if !vl#lib#listdict#dict#HasKey(g:scanned_files, func_as_string)
"     let g:scanned_files[func_as_string] = {}
"   endif
"   let dict = g:scanned_files[func_as_string]
"   if s:cache_results
"     let cache_file = expand(s:cache_dir.'/'.s:CacheFileName(a:scan_func, a:file))
"     if !vl#lib#listdict#dict#HasKey(dict, a:file) " try getting from cache
"       if filereadable(cache_file)
" 	let dict[file] = eval(readfile(cache_file)[0])
"       endif
"     endif
"   endif
"   if vl#lib#listdict#dict#HasKey(dict, a:file)
"     " return cached value if up to date
"     if getftime(a:file) <= dict[a:file]['ftime']
"       return dict[a:file]['scan_result']
"     endif
"   endif
"   if a:asLines
"     let scan_result = a:scan_func(readfile(a:file))
"   else
"     let scan_result = a:scan_func(a:file)
"   endif
"   "echo "scanning ".a:file
"   let  dict[a:file] = {"ftime": getftime(a:file), "scan_result": scan_result }
"   if s:cache_results && cache
"     call vl#lib#files#filefunctions#WriteFile([string(dict[a:file])], cache_file)
"   endif
"   return scan_result
" endfunction
" 
" function! s:CacheFileName(scan_func, file)
"   let f=vl#lib#files#filefunctions#FileHashValue(string(a:scan_func).a:file)
"   let l = min([len(f), 100])
"   return strpart(f, len(f) - l, l)
" endfunction
" 
" function! vl#lib#files#scan_and_cache_file#ClearScanAndCacheFileCache()
"   call vl#lib#files#filefunctions#RemoveDirectoryRecursively(s:cache_dir)
"   unlet g:scanned_files
" endfunction
" 
" " only saves file content
" function! vl#lib#files#scan_and_cache_file#ScanFileContent(file_lines)
"   return a:file_lines
" endfunction
" 
" if vl#lib#files#filefunctions#EnsureDirectoryExists(s:cache_dir)
"   call vl#lib#ide#logging#Log('scan and cache directory '.s:cache_dir.' has been created', 10)
" endif
" end region 'file <dotvim>/autoload/vl/lib/files/scan_and_cache_file.vim'


" start region 'file <dotvim>/autoload/vl/lib/brief/handler.vim'
" "|fld   description : try some functions and return result of first function
" "|+                   which succeeds
" "|fld   keywords : <+ this is used to index / group scripts ?+> 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2006 Nov 06 19:13:42
" "|fld   version: 0.0
" "|fld   dependencies: <+ vim-python, vim-perl, unix-tool sed, ... +>
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: unusable, experimental
" "|fld     os: <+ remove this value if script is os independent +>
" "|
" "|H1__  Documentation
" "|
" "|p     See vl#lib#template#template for an example
" "|
" "|H2_   typical usage see Handle function
" 
" "|func
" "|p     tries to feed different functions with the given value.
" "|      and returns on sucess [1, returned_value]  
" "|      otherwise [0, failure_messages]
" "|p     All handler functions must return [1, value] on success, [0, "failure_message"] otherwise
" "|p     example usage:
" "|code  let [success, value] = Handle( value, [function('handler1'), function('handler2')])
" "|p     You can also pass the name of the function (exec will be instead)
" function! vl#lib#brief#handler#Handle( handler_list, ...)
"   let failure_messages = []
"   let value = "dummy assignment to be able to call unlet"
"   for H in a:handler_list
"     unlet value
"     if a:0 == 1
"       if type(H) == type('')
"           exec 'let [success, value] = '.H.'(a:1)'
"       else
"         let [success, value] = H(a:1)
"       endif
"     else " a:0 == 0
"       if type(H) == type('')
"         exec 'let [success, value] = '.H.'()'
"       else
"         let [success, value] = H()
"       endif
"     endif
" 
"     if success
"       return [1, value]
"     else
"       call add(failure_messages, 'handler '.string(H).' failed. message: '.string(value))
"     endif
"   endfor
"   return [0, failure_messages]
" endfunction
" 
" "|func calls a function with each argument of the list
" "|+    when it succeeds the returned value is returned similar to Handle(..)
" "|+    defined above
" function! vl#lib#brief#handler#HandleList( value_list, handler)
"   let failure_messages = []
"   for item in a:value_list
"     let H = a:handler
"     let [success, value] = H(item)
"     if success
"       return [1, value]
"     else
"       call add(failure_messages, 'handler '.string(H).' failed. message: '.string(value))
"     endif
"   endfor
"   return [0, failure_messages]
" endfunction
" 
" "|func  You can use this in combination with HandleList to find a executable.
" "|p     example
" "|code  let [success, executable_or_error_message] = vl#lib#brief#handler#HandleList( ['tags','exuberant-ctags']
" "|                  \ , vl#dev#vimscript#vimfile#Function('vl#lib#brief#handler#IsExecutableHandlerfunc'))
" function! vl#lib#brief#handler#IsExecutableHandlerfunc(filename)
"   let fn = expand(a:filename)
"   if executable(fn)
"     return [1, fn]
"   else
"     return [0, "not an executable or not in path ".fn]
"   endif
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/brief/handler.vim'


" start region 'file <dotvim>/autoload/vl/lib/brief/conditional.vim'
" "" brief-description : some conditional functions to shorten scripts
" "" keywords : conditional functions
" "" author : Marc Weber marco-oweber@gmx.de
" "" started on :2006 Oct 05 02:11:04
" "" version: 0.0
" 
" "| returns either if_value or else_value
" function! vl#lib#brief#conditional#IfElse(condition,if_value,else_value)
"   if a:condition
"     return a:if_value
"   else
"     return a:else_value
"   endif
" endfunction
" 
" "| executes statement if condition is true
" function! vl#lib#brief#conditional#If( condition, statement)
"   if a:condition
"     exec a:statement
"   endif
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/brief/conditional.vim'


" start region 'file <dotvim>/autoload/vl/lib/regex/regex.vim'
" " script-purpose: find text with left opened brackets/ .... used in my
" " contextcompletion ftpplugin-scripts using vl#textediting#contextcompletion
" " author: Marc Weber
" " started : Sat Sep 16 08:04:31 CEST 2006
" " stabilitiy : usable
" " description: Do not just add a tag to the currrent file but to all files of
" " the same type and those who will be opened in the  future using
" 
" " returns regular regex which matches arbitrary amount of 
" " (outer* open inner* close outer*)* outer* open inner
" function! vl#lib#regex#regex#MatchLeftOpen(open,close,inner,outer)
"   return '\%('.a:outer.'*'.a:open.a:inner.'*'.a:close.'\)*'.a:outer.'*'.a:open.a:inner.'*'
" endfunction
" " vl#lib#regex#regex#OpenCloseManyTimes(<,>,a,b,1) matches <aaa>bbbb<a>b
" function! vl#lib#regex#regex#OpenCloseManyTimes(open,close,inner,outer,includeLeadingOuter, includeTrailingOuter)
"   return vl#lib#brief#conditional#IfElse(a:includeLeadingOuter,a:outer.'*','')
" 	\ .'\%('.a:outer.'*'.a:open.a:inner.'*'.a:close.'\)\='
" 	\ .vl#lib#brief#conditional#IfElse(a:includeTrailingOuter,a:outer.'*','')
" endfunction
" " matches "sdf"..."sdfkj".."slfdj\"k"
" function! vl#lib#regex#regex#ManyQuotedStrings(notOuterSet, includeLeadingOuter, includeTrailingOuter)
"   let openclose='"'
"   let inner='\%([^"]\|\\"\)'
"   return vl#lib#regex#regex#OpenCloseManyTimes(openclose,openclose,inner,'[^"'.a:notOuterSet.']',a:includeLeadingOuter,a:includeTrailingOuter)
" endfunction
" 
" " matches "blah..\ but not "blah"
" function! vl#lib#regex#regex#MatchLeftOpenQuotedString()
"   let openclose='\%(\\\@<!"\)'
"   let inner='\%([^"]\|\\"\)'
"   return vl#lib#regex#regex#MatchLeftOpen(openclose,openclose,inner,'[^"]')
" endfunction
" 
" "|func returns regular expression which matches many regex seperated by
" "|+    separator
" function! vl#lib#regex#regex#SeperatedBy(regex, separator)
"   return '\%('.a:regex.a:separator.'\)*'.a:regex
" endfunction
" 
" "function! MatchEvenNumber(matchItem,inner,outer)
" "endfunction
" 
" "|func returns a list of all matches of the regex
" function! vl#lib#regex#regex#MatchAll(str, regex)
"   let matches = []
"   let s = a:str
"   while 1
"     let pos = match(s,a:regex)
"     if pos == -1 
"       return matches
"     else
"       let match = matchstr(s, a:regex)
"       call add(matches, match)
"       let s = strpart(s,strlen(match)+pos)
"     endif
"   endwhile
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/regex/regex.vim'


" start region 'file <dotvim>/autoload/vl/dev/vimscript/vimfile.vim'
" "|fld   description : scan a vim file and provide some information (currently only which functions are defined), fix autload functions, user function completion
" "|fld   keywords : autoload 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : Sun Sep 17 19:20:01 CEST 2006
" "|fld   version: 0.3
" "|fld   dependencies: vl.vim plugin becauso of s:vl_regex settings
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : linux
" "|fld   maturity: unusable, experimental
" "|
" "|H1__  Documentation
" "|
" "|H2    FixPrefixesOfAutoloadFunctions
" "|ftp   command! -buffer -nargs=0 FixPrefixesOfAutoloadFunctions :call vl#dev#vimscript#vimfile#FixPrefixesOfAutoloadFunctions()<cr>
" "|p     This command does two different things.
" "|p     1) just type 
" "|code  function a#YourFunction() 
" "|p     to replace a with the correct function
" "|+     location. When the file is located in autoload/a/foo.vim it will
" "|+     become
" "|code  function a#foo#YourFunction() 
" "|
" "|p     2) If you're using an autoload function you can write:
" "|code  call Load()
" "|p     and FixPrefixesOfAutoloadFunctions will lookup the right prefix for
" "|      you. Thus it will look like:
" "|code  call vl#lib#vimscript#scriptsettings#Load()
" "|P     You have to know that everything looking like a#b#c#Func( will be
" "|+     treated as beeing a autoload function call. This is not perfect but
" "|+     works well in practise.
" "|
" "|H2    Function completion
" "|ftp   inoremap <buffer> <c-m-f> <c-r>=vl#lib#completion#useCustomFunctionNonInteracting#GetInsertModeMappingText('omnifunc','vl#dev#vimscript#vimfile#CompleteFunction',"\<c-x>\<c-o>")<cr>
" "|
" "|p     another tip: use 
" "|code  syn match Tag '\%(\%(\w\+#\)*\|s:\|g:\)\zs\u\a*\ze' containedin=ALL 
" "|p     in your .vim/after/syntax/vim.vim to highlight function names with s:, g: or
" "|      autoload prefix
" "|
" "|TODO: implement gf handler to jump to the definition of used files
" "|      recognize these references as well as used autoload functions:
" "|code   function('vl#dev#vimscript#vimfile#ScanVimFile')
" "|H2__ roadmap
" "|rm   There is a lot which can be done: also parse commands, ..
" 
" 
" " script  internal variables
" let s:vl_regex = {}
" let s:vl_regex['fap']='\%(\w\+#\)\+' " match function autoload prefix ( blah#foo#)
" let s:vl_regex['ofp']='\%(\w\+#\)*' " optional match function location prefix ( blah#foo#)
" let s:vl_regex['fp']='\%('.s:vl_regex['ofp'].'\|s:\|g:\)' " match any (or no function prefix)
" let s:vl_regex['Fn']='\w*'  " match function name
" let s:vl_regex['uFn']='\u\w*'  " match user function name
" let s:vl_regex['function']='^\s*fun\%(ction\)\=!\=\s\+'
" " match function declaration and get function name / doesn't match fun s:Name
" let s:vl_regex['fn_decl']=s:vl_regex['function'].'\zs'.s:vl_regex['fp'].s:vl_regex['uFn'].'\ze('
" call vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching('')
" let s:quick_match_expr = vl#lib#vimscript#scriptsettings#Load('dev.vimscript.function_quick_match',
"    \ function('vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching'))
" 
" "|func scan vim file (is used with ScanIfNewer()
" "|     returns (to be extended ?)
" "|     dictionary { 'declared functions' : list
" "|                , 'declared autoload functions' : list
" "|                , 'used user functions' : list
" "|                , 'used autoload functions' : list
" "|                }
" "|    
" function! vl#dev#vimscript#vimfile#ScanVimFile(file_lines)
"   let declared_functions = vl#dev#vimscript#vimfile#GetAllDeclaredFunctions(
" 				      \ a:file_lines)
"   let declared_autoload_functions = filter(deepcopy(declared_functions),
" 	      \ 'v:key =~ '.string(s:vl_regex['fap'].s:vl_regex['uFn']))
"   let used_user_functions = vl#dev#vimscript#vimfile#GetAllUsedUserFunctions(
" 				      \ a:file_lines)
"   let used_autoload_functions = filter(deepcopy(used_user_functions),
" 	      \ 'v:key =~ '.string(s:vl_regex['fap'].s:vl_regex['uFn']))
"   let g:c = s:vl_regex['fap'].s:vl_regex['uFn']
"   return { 'declared functions' : declared_functions
"        \ , 'declared autoload functions' : declared_autoload_functions
"        \ , 'used autoload functions' : used_autoload_functions
"        \ , 'used user functions' : used_user_functions
"        \ }
" endfunction
" 
" " takes a file and subdir and tries to locate file in &runtimepath/subdir
" " file has to be expanded.
" " [ 1, [ runtimepath, file ] ] on success
" " [ 0, "not <file> not found"] on failure
" function! vl#dev#vimscript#vimfile#FileInDirOfRuntimePath(file, subdir)
"   let filepath = a:file
"   for path in split(&runtimepath,',')
"     if has('windows')
"       let ignore_case = '\c'
"     else
"       let ignore_case = ''
"     endif
"     let rest = matchstr(filepath, ignore_case.
" 	    \ substitute(expand(path),'\\','\\\\','g').a:subdir.'[/\\]\zs.*\ze')
"     if rest != ""
"       return [1, [path, rest] ]
"     endif
"   endfor
"   return [ 0, "file ".a:file." in directory ".a:subdir." not found in any runtimepath "]
" endfunction
" 
" function! s:HR(result)
"   if a:result[0] == 1 
"     return a:result[1][1]
"   else
"     return ""
"   endif
" endfunction
" 
" "|func returns the file part after autoload if the file is in a autoload directory
" "|     in runtimepath "" else
" function! vl#dev#vimscript#vimfile#FileInAutoloadDir(file)
"   return s:HR(vl#dev#vimscript#vimfile#FileInDirOfRuntimePath(a:file, '[/\\]autoload'))
" endfunction
" 
" "|func the same for runtimepath
" function! vl#dev#vimscript#vimfile#FileInRuntimePath(file)
"   return s:HR(vl#dev#vimscript#vimfile#FileInDirOfRuntimePath(a:file, ''))
" endfunction
" 
" "| tries to locate file rel_filepath in runtimepath
" "| FindFileInRuntimePath('autoload/vl/dev/vimscript/vimfile.vim')
" "| should find this file
" function! vl#dev#vimscript#vimfile#FindFileInRuntimePath(rel_filepath)
"   for path in split(&runtimepath,',')
"     let fn = expand(path.'/'.a:rel_filepath)
"     if exists(fn)
"      return fn
"    endif
"  endfor
"  return ""
" endfunction
" 
" "|func calculates the autoloadprefix of file based on runtimepath
" function! vl#dev#vimscript#vimfile#GetPrefix(file)
"   "let filepath = substitute(a:file,'\%(/\|\\\)[^/\\]*$','','')
"   let filepath = expand(substitute(a:file,'.vim$','',''))
"   " file is not in a autoloaddir, return it without change
"   return substitute( substitute(vl#dev#vimscript#vimfile#FileInAutoloadDir(a:file),'/\|\\','#','g')
" 		   \ , '.vim$','','')
" endfunction
" 
" " returns dictionary { "<functionname>" : <line_nr> , ... }
" function! vl#dev#vimscript#vimfile#GetAllDeclaredFunctions(file_as_string_list)
"   let functions = {}
"   let line_nr = 1
"   for l in a:file_as_string_list
"     let function = matchstr(l,s:vl_regex['fn_decl'])
"       if function !=  ""
" 	let functions[function] = line_nr
"       endif
"     let line_nr = line_nr + 1
"   endfor
"   return functions
" endfunction
" 
" 
" " returns a dictionary { "function name": linenr, ...}
" " thus the last occurence will be listed
" function! vl#dev#vimscript#vimfile#GetAllUsedUserFunctions(file_as_string_list)
"   let file = a:file_as_string_list
"   let result = {}
"   let line_nr=1
"   for l in file
"     if l =~ '^\s*"' || l =~ s:vl_regex['fn_decl']
"       let line_nr = line_nr + 1
"       continue " simple comment handling.. can be improved much
" 	       " also continue on function declarations
"     endif
"     let matches = map(split(l,s:vl_regex['fp'].s:vl_regex['uFn'].'(\zs\ze'),"matchstr(v:val,'".s:vl_regex['fp'].s:vl_regex['uFn']."(')")
"     for m in map(matches,"substitute(v:val,'($','','')")
"       if m == ""
" 	continue
"       endif
"       if !exists("result['".m."']")
" 	let result[m] = line_nr
"       endif
"     endfor
"     let line_nr = line_nr+1
"   endfor
"   return result
" endfunction
" 
" " returns list of all used autoload files
" " If you have 2 autoload/file.vim files
" " the one beeing first in runtimepath will be used
" " returns dictionary { "prefix": "file", ... }
" " file autoload/blah/ehh.vim results in prefix
" " blah#
" function! vl#dev#vimscript#vimfile#ListOfAutoloadFiles()
"   let files = {}
"   for path in reverse(split(&runtimepath,','))
"     for file in split(globpath(expand(path.'/autoload'),"**/*.vim"),"\n")
"       let prefix = vl#dev#vimscript#vimfile#GetPrefix(file)
"       let files[prefix] = file
"     endfor
"   endfor
"   return files
" endfunction
" 
" " corrects all function blah#foo# in funciton declarations
" " corrects all prefixes in applied autoload functions such like a#b#C(
" " commands are not yet recognized because the ( is missing there.
" function! vl#dev#vimscript#vimfile#FixPrefixesOfAutoloadFunctions()
"   echo "press Ctrl-c to abort. This command may still be buggy. "
"      \ ." You have to wait some seconds when invoking this command the first time because vim has to scan all autload files. " 
"      \ ."Use undo/ redo to show see changes or log which will be echoed"
"   let log = {} " dictionary used to to get uniq values
"   let prefix_curr = vl#dev#vimscript#vimfile#GetPrefix(expand('%:p'))
"   let autofile_list = vl#dev#vimscript#vimfile#ListOfAutoloadFiles()
"   "call filter(autofile_list, 'v:val =~ "test"')
"   let fix_to_death_count = {}
" 
"   " correct prefix of function declarations:
"   let curr_file = vl#dev#vimscript#vimfile#ScanVimFile(getline(1,line('$')))
"   let df = curr_file['declared functions']
"   for key in keys(df)
"     let match = matchstr(key,'\zs.*\ze#')
"     if match != '' && match != prefix_curr " fix it automatically. Here is nothing which can be done wrong
"       let line_nr = df[key]
"       let line = getline(line_nr)
"       call setline(line_nr, substitute(line , s:vl_regex['fap'],  prefix_curr.'#', ''))
"       let log["line ".line_nr." wrong prefix of function declaration '".line."' corrected"] = 0
"     endif
"   endfor
"   let ok = 0
"   let result = "define to cause no error on unlet"
"   while !ok
"     let ok = 1
"     let used_functions = curr_file['used user functions']
"     for f in keys(used_functions)
"       unlet result
"       let result = vl#dev#vimscript#vimfile#DoesAutoloadFunctionExist(autofile_list, f)
"       let line_nr = used_functions[f]
"       if exists("fix_to_death_count['".line_nr."']") &&  fix_to_death_count[line_nr] > 10
" 	continue
"       endif
"       if type(result) == 0 && result == 1
" 	continue
"       endif
"       if type(result) == 3
" 	if exists("fix_to_death_count['".line_nr."']")
" 	  let fix_to_death_count[line_nr] += 1
" 	  if fix_to_death_count[line_nr] > 10
" 	    let log[ "line ".used_functions[f]." internal script error. tried to fix this line more than 10 times and still not correct."] = 0
" 	  endif
" 	else
" 	  let fix_to_death_count[line_nr] = 1
" 	endif
" 	let ok = 0 " this can be fixed, try again because only the last occurence of the wrong function is stored in curr_file
" 	let use_func = vl#ui#userSelection#LetUserSelectIfThereIsAChoice(
" 	      \ 'There is more than one matching function, choose the one you like:', result)
" 	let line = getline(line_nr)
" 	let new_line = substitute(line , f.'(', use_func.'(', 'g')
" 	call setline(line_nr,new_line) 
" 	let log[ "line ".used_functions[f].": '".line."' replaced with '".new_line."'"] = 0
"       else
" 	let log[ "function application ".f." line: ".used_functions[f]." not found, can't fix." ] =  0
"       endif
"     endfor
"     " rescan the file  after each correction because only the last application
"     " is listed
"     if ok == 0
"      let curr_file = vl#dev#vimscript#vimfile#ScanVimFile(getline(1,line('$')))
"     endif
"   endwhile 
"   if len(log) == 0
"     echo "nothing found to be corrected"
"   else
"     echo "log :\n".join(keys(log),"\n")
"   endif
" endfunction
" 
" " returns either
" " 1: exists
" " 0: doesn't exist
" " ["location"]: does exist in another file with different prefix
" " function: typically a#b#file#Func
" " files: list of files to check (get file list using ListOfAutoloadFiles()
" function! vl#dev#vimscript#vimfile#DoesAutoloadFunctionExist(files, function)
"   let file = substitute(a:function,'#[^#]*$','','') " blah#foo value
"   if exists("a:files['".file."']") 
"     let file_content = vl#lib#files#scan_and_cache_file#ScanIfNewer(
" 	  \ a:files[file], 1, s:ScanVimFile)
"     if exists("file_content['declared functions']['".a:function."']")
"       return 1
"     endif
"   endif
"   " search the function in all files
"   let matches = []
"   for f in keys(a:files)
"     let file_content = vl#lib#files#scan_and_cache_file#ScanIfNewer(
" 	  \ a:files[f],1,  s:ScanVimFile)
"     let function = substitute(a:function,'.*#','','')
"     for f in keys(file_content['declared functions'])
"       if f =~ '\<'.function.'$'
" 	call add(matches, f)
"       endif
"     endfor
"   endfor
"   if len(matches) > 0
"     return matches
"   endif
" return 0
" endfunction
" 
" let s:ScanVimFile = function('vl#dev#vimscript#vimfile#ScanVimFile')
" 
" function! vl#dev#vimscript#vimfile#CompleteFunction(findstart,base)
"   if a:findstart
"     " locate the start of the word
"     let [bc,ac] = vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"     return len(bc)-len(matchstr(bc,'\%(\a\|\.\|\$\|\^\)*$'))
"   else
"     let prefix = matchstr(a:base,'.*\.')
"     let func = substitute(a:base,'.*\.','','')
"     " matching patterns
"     let quick_pattern = s:quick_match_expr(func)
"     let g:q = quick_pattern
"     let pattern = '^'.func
"     let regex = substitute('\%('.pattern.'\)\|\%('.quick_pattern.'\)', '\^', '^'.substitute(s:vl_regex['fp'],'\\','\\\\','g'),'g')
"     let g:regex = regex
" 
"     " take functions from this file
"     let curr_file = vl#dev#vimscript#vimfile#ScanVimFile(getline(1,line('$')))
"     let functions = keys(curr_file['declared functions'])
"     call filter(functions ,'v:val =~ '.string(regex))
"     for f in functions
"       call complete_add(f)
"     endfor
"     "if complete_check()
"       "return []
"     "endif
"     " take functions from autoload directories
"     let autoload_functions = vl#dev#vimscript#vimfile#ListOfAutoloadFiles()
"     for file  in values(autoload_functions)
"       "if complete_check()
" 	"return []
"       "endif
"       let file_content = vl#lib#files#scan_and_cache_file#ScanIfNewer(
" 	  \ file, 1,  s:ScanVimFile)
"       let g:f = file
"       let functions = keys(file_content['declared autoload functions'])
"       call filter(functions ,'v:val =~ '.string(regex))
"       for f in functions
" 	call complete_add(f)
"       endfor
"     endfor
"     return []
"   endif
" endfunction
" 
" "|func only works with autoload functions 
" "|     is intended to be used with gfHandler to jump to files.
" "|     limitation: only finds first match (because FileInDirOfRuntimePath does so)
" "|     returns either [[filename, linenr]]
" "|     or [filename]. in case that function does not exist (than you can jump to the file and add it manually)
" function! vl#dev#vimscript#vimfile#GetFuncLocation()
"   let [b,a] = vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"   let func = matchstr(b,'\zs[#a-zA-Z0-9]*\ze$').matchstr(a,'^\zs[#a-zA-Z0-9]*\ze(')
"   let results = []
"   let autofile_list = vl#dev#vimscript#vimfile#ListOfAutoloadFiles()
"   let keys = keys(autofile_list)
"   for file in keys
"     let functions = vl#lib#files#scan_and_cache_file#ScanIfNewer(
" 	  \ autofile_list[file], 1, s:ScanVimFile)['declared functions']
"     if vl#lib#listdict#dict#HasKey(functions, func)
"       let line = functions[func]
" 	call add(results, [autofile_list[file], line])
"     endif
"   endfor
"   if len(results) == 0
"     let file = substitute(func,'#[^#]*$','','') 
"     if vl#lib#listdict#dict#HasKey(autofile_list, file)
"       return [autofile_list[file]]
"     endif
"   endif
"   return results
" endfunction
" 
" 
" "|func can be used instead of function.
" "|     difference: this function sources the file if the function doesn't exsist
" "|     yet
" "|     doesn't work that well
" function! vl#dev#vimscript#vimfile#Function(name)
"   if !exists(a:name)
"     let files = vl#dev#vimscript#vimfile#ListOfAutoloadFiles()
"     let file_prefix = substitute(a:name,'#[^#]*$','','')
"     if vl#lib#listdict#dict#HasKey(files, file_prefix)
"       exec 'source '.files[file_prefix]
"       return function(a:name)
"     endif
"   endif
" endfunction
" end region 'file <dotvim>/autoload/vl/dev/vimscript/vimfile.vim'


" start region 'file <dotvim>/autoload/vl/lib/completion/quick_match_functions.vim'
" "" brief-description : match a omni completion entry by less characters
" "" keywords : omnicompletion 
" "" author : Marc Weber marco-oweber@gmx.de
" "" started on :2006 Oct 03 02:24:20
" "" version: 0.1
" "" 
" ""  proposed-usage:
" ""  ==============
" "" vl/dev/haskell/modules_list_cache_jump.vim uses it.
" 
" " replaces upper characters C with C\u*\U* 
" " so Ohh can be matched by O
" " and lower characters c with c\U* 
" " so ohh can be matched by o
" function! vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching(expr)
"   let result = ''
"   if len(a:expr) > 10 " vim can't cope with to many \( ? and propably we no longer want this anyway
"     return 'noMatchDoh'
"   endif
"   for index in range(0,len(a:expr))
"     let c = a:expr[index]
"     if c =~ '\u'
"       let result .= c.'\u*\l*_\='
"     elseif c =~ '\l'
"       let result .= c.'\l*\%(\l\)\@!_\='
"     else
"       let result .= c
"     endif
"   endfor
"   return '^'.result
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/completion/quick_match_functions.vim'


" start region 'file <dotvim>/autoload/vl/lib/template/template.vim'
" "|fld   description : Provide some templating support.
" "|fld   keywords : <+ this is used to index / group scripts ?+> 
" "|fld   initial author : Marc Weber marco-oweber@gmx.de
" "|fld   mantainer : author
" "|fld   started on : 2006 Nov 06 18:41:17
" "|fld   version: 0.0
" "|fld   dependencies: <+ vim-python, vim-perl, unix-tool sed, ... +>
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: directory templates not yet tested, experimental
" "|fld     os: <+ remove this value if script is os independent +>
" "|
" "|H1__  Documentation
" "|
" "|p     Some ideas are stolen from vimplate written by Urs Stotz except this
" "|+     uses vimscript only ;)
" "|
" "|H2__  settings
" "|set   template handlers. default is the list seen in the next code snippet.
" "|      the DirectoryHandler globs a directory for template files and adds them ( call 
" "|+     function AddTemplatesFromDirectory to add a directory).
" "|      the TemplateHandler just returns the template having been added by call AddTemplate
" "|code  let s:templateHandlers=vl#lib#vimscript#scriptsettings#Load('vl.lib.template.template.template_handlers', 
" "|      \ [function('vl#lib#template#template_handlers#TemplateGivenDirectlyHandler'), function('vl#lib#template#template_handlers#DirectoryTemplateHandler')])
" "|      It should be easy to add your own temlate handlers.
" "|      This is an additional function returning a regular expression matching
" "|+     ids by CamelCase. Thus you can match MyHeader by MH
" "|code  let s:quick_match_expr = vl#lib#vimscript#scriptsettings#Load('dev.vimscript.function_quick_match',
" "|         \ function('vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching'))
" "|
" "|H2    template handler
" "|p     a template handler takes an item which has been added to b:vl_templates
" "|+     and returns [0, "wrong handler"] if the list entry wasn't meant for
" "|      this handler [1, <list of templates> ]. template entry is a
" "|      dictionary:
" "|code  { 'id' : <name of this template>
" "|    \ , 'value' : arg_to_next_func
" "|    \ , 'get_template' : <function taking value returning text to be inserted>
" "|    \ }
" "|p     The  function get_template must return
" "|code       { 'text' : <text to be inserted> }
" "|         \ , 'post execute' : <vim script text to be executed using exec> }
" "|p     where the entry 'post execute' is optional. If some text is selected
" "|+     will be surrounded.
" "|p     The cursor will be placed at the beginning of the inserted template.
" "|p     You can use "text inserted<++>" and 'post execute' : 'normal <c-j>' to
" "|+     set the cursor at the end or somewhere else. ! post execute is not yet
" "|+     used and not yet implemented.
" "|
" "|H2_   Preprocessor
" "|p     The template is run through the Preprocessor, which replaces all
" "|+     occurrences of [% = code %] with the result of code. code is a vimscript snippet
" "|p     Example:      
" "|code  Example template having 3 lines
" "|      Today is [% = strftime("%Y %b %d %X") %]
" "|      end
" "|p     You can use a value more than once this way:
" "|code  Example template having 3 lines
" "|      Today is [% let vars['today'] = strftime("%Y %b %d %X") %][% = vars['today'] %]
" "|      and today again [% = vars['today'] %]
" "|p     you can use b:template_vars and g:template_vars to provide some
" "|      default values which will be added to vars automatically
" "|p     There are two special vars [% = cursor %] and [% = selection %].
" "|      '= cursor' is used to set a cursor mark which defaults to <++> and 
" "|+     '= selection' where the selected text will be inserted.
" "|p     Special functions: (to be implemented )
" "|      AskUser("vars['dummy']", [default [, completion]]) 
" "|      will ask the user for a value to enter and save it to vars['dummy'] if
" "|+     the value hasn't been specified yet
" "|p     I hope this lets you do all you need. ( Inserting filenames,
" "|      conditional text using if cond | text | else  | ..
" "|H2_   Interface
" "|p     call this function
" "|code  call vl#lib#template#template#AddTemplateUI('dir containing template files','another dir')
" "|p     to add the commands TemplateShowAvailibleIds, TemplateNew,
" "|      TemplateInsert and the mapping <c-s-t>
" "|p     So you can type te<c-s-t> to insert a template beeing called test.
" "|H2_   One complete working example:
" "|code  call vl#lib#template#template#AddTemplate('hello','bc')
" "|      call vl#lib#template#template#AddTemplate('files_in_current_directory','[% = string(glob("*")) %]')
" "|      call vl#lib#template#template#AddTemplate('today',"Today is \n[% let vars['today'] = strftime('%Y %b %d %X') %][% = vars['today'] %]")
" "|      call vl#lib#template#template#AddTemplateUI(vl#settings#DotvimDir().'templates/'.&ft)
" "|
" "|TODO:  Do much more testing
" "|       implement escaping of [% and proper parsing of [% %]
" "|       add edit template function
" "|+      
" "|+      
" "|+      
" "|rm roadmap (what to do, where to go?)
" 
" " this is used to complete templates
" let s:quick_match_expr = vl#lib#vimscript#scriptsettings#Load('dev.vimscript.function_quick_match',
"    \ vl#dev#vimscript#vimfile#Function('vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching'))
" " cursor mark is inserted when [% = cursor %] is used
" let s:cursor_mark = vl#lib#vimscript#scriptsettings#Load('dev.vimscript.function_quick_match',
"   \ '<++>')
" 
" "|func  adds the directory to template list
" "|      the directory content is read when templates are requested
" function! vl#lib#template#template#AddTemplatesFromDirectory(directory)
"   call vl#lib#brief#conditional#If(!exists('b:vl_templates'), 'let b:vl_templates = []')
"   call vl#lib#listdict#list#AddUnique(b:vl_templates, { 'directory': a:directory } )
" endfunction
" 
" "|func   adds another template which can be requested using id
" function! vl#lib#template#template#AddTemplate(id, text)
"   call vl#lib#brief#conditional#If(!exists('b:vl_templates'), 'let b:vl_templates = []')
"   call vl#lib#listdict#list#AddUnique(b:vl_templates, {'template': { 'id' : a:id, 'text' : a:text } } )
" endfunction
" 
" "|func   lets the user add a template to a directory selected from
" "|+      b:vl_templates
" function! vl#lib#template#template#TemplateNew()
"   let no_dirs_specified_message = "call vl#lib#template#template#AddTemplatesFromDirectory('<dir>') from within a ftplugin file to specify directories conaining templates first"
"   if !exists('b:vl_templates')
"     echo no_dirs_specified_message
"   else
"     let ft = &ft
"     let directory_entries = filter(deepcopy(b:vl_templates), 'type(v:val)==4 && vl#lib#listdict#dict#HasKey(v:val,"directory")')
"     if len(directory_entries) == 0
"       echo no_dirs_specified_message
"     else
"       let directories = map(directory_entries, 'v:val["directory"]')
"       let directory = vl#ui#userSelection#LetUserSelectIfThereIsAChoice('Add template to which directory?', directories)
"       echo "remeber that you can use subdirectories, too"
"       echo "use [% = selection %] to insert selected text. (te be implemented)"
"       echo "    [% let vars['foo'] = <vimscript expession> %] to set a variable"
"       echo "    [% = vars['foo'] %] to insert it "
"       let file = input('template file: ', vl#lib#files#filefunctions#AddTrailingDelimiter(directory),'file')
"       if file == ''
" 	echo "user aborted"
"       else
" 	exec 'sp '.file
" 	if &ft == ''
" 	  let &ft = ft " set filetype to the same filetype
" 	endif
"         runtime ftplugin/template*.vim
"         put='[% set paste %]'
"         1d
"       endif
"     endif
"   endif
"   return ""
" endfunction
" 
" "|func   lets the user edit a template from a directory selected from
" "|+      b:vl_templates
" "|       TODO : this can be made better! redundancy see TemplateNew
" function! vl#lib#template#template#TemplateEdit()
"   let no_dirs_specified_message = "call vl#lib#template#template#AddTemplatesFromDirectory('<dir>') from within a ftplugin file to specify directories conaining templates first"
"   if !exists('b:vl_templates')
"     echo no_dirs_specified_message
"   else
"     let ft = &ft
"     let directory_entries = filter(deepcopy(b:vl_templates), 'type(v:val)==4 && vl#lib#listdict#dict#HasKey(v:val,"directory")')
"     if len(directory_entries) == 0
"       echo no_dirs_specified_message
"     else
"       let directories = map(directory_entries, 'v:val["directory"]')
"       let directory = vl#ui#userSelection#LetUserSelectIfThereIsAChoice('Add template to which directory?', directories)
"       let file = input('template file: ', vl#lib#files#filefunctions#AddTrailingDelimiter(directory),'file')
"       " change also TemplateNew
"       if file == ''
" 	echo "user aborted"
"       else
" 	exec 'sp '.file
" 	if &ft == ''
" 	  let &ft = ft " set filetype to the same filetype
" 	endif
"       endif
"     endif
"   endif
"   return ""
" endfunction
" 
" 
" "| returns a list of all templates
" function! vl#lib#template#template#TemplateList()
"   let result = []
"   for entry in b:vl_templates 
"     let [success, template_list] = vl#lib#brief#handler#Handle(s:templateHandlers, entry)
"     if !success
"       echoe "wasn't able to handle template entry ".string(entry)
"     else
"       call extend(result, template_list)
"     endif
"   endfor
"   return result
" endfunction
" 
" function! vl#lib#template#template#TemplateIdList()
"   return map(vl#lib#template#template#TemplateList()
" 	  \ , "v:val['id']")
" endfunction
" 
" "| preprocesses the text.
" "| This means you can assign variables using [% foo=<some term>%] and use them
" "| this way [% = vars['foo'] %]
" "| optional argument specifies selected text which replaces [% = selection %] (TODO)
" function! vl#lib#template#template#PreprocessTemplatetext(text, vars, ...)
"   exec vl#lib#brief#args#GetOptionalArg('selection',string('no optional arg given'))
"   let cursor = s:cursor_mark
"   "let AskUser = function('vl#lib#template#template#AskUser')
" 
"   let vars = deepcopy(a:vars)
"   let result = ""
"   let parts = split(a:text, '\zs\ze\[%')
"   for part in parts
"     if part =~ '\[%.*%]'
"       let subparts = split(part, '%\]\zs\ze')
"       if len(subparts) > 2
" 	echoe "missing \[%"
"       endif
"       call add(subparts, '') " add empty string in case of '[% ... %]' without trailing text which will be added
"       let vim_script_command = matchstr(subparts[0], '\[%\s*\zs.*\s*\ze%\]$')
"       if vim_script_command =~ '^='
" 	let term = matchstr( vim_script_command, '=\s*\zs.*\ze\s*$')
" 	exec 'let text = '.term
" 	let result .= text.subparts[1]
"       else
" 	if vim_script_command  =~ '^\s*let\s\+vars\[' || vim_script_command =~ '^set \%(no\)\=paste'
" 	  " this term should be something like this: 
" 	  exec vim_script_command
" 	else
" 	  echoe "wrong assignment found: '".vim_script_command."'. Should be something like 'let vars[\"today\"] = ime(\"%Y %b %d %X\")! I do note execute this statement."
" 	endif
" 	let result .= subparts[1]
"       endif
"     else
"       let result .= part
"     endif
"   endfor
"   return [result, vars]
" endfunction
" 
" "func pass no options
" function! vl#lib#template#template#SimplePreprocessTemplateText(text)
"   return vl#lib#template#template#PreprocessTemplatetext(a:text,{})[0]
" endfunction
" 
" function! vl#lib#template#template#GetTemplateById(id, ...)
"   exec vl#lib#brief#args#GetOptionalArg('vars', string({}))
"   let result = []
"   for entry in b:vl_templates 
"     let [success, template_list] = vl#lib#brief#handler#Handle(s:templateHandlers, entry)
"     if !success
"       echoe "wasn't able to handle template entry ".string(entry)
"     else
"       for entry in template_list
" 	if entry['id'] == a:id
" 	  let F = entry['get_template']
" 	  return F(entry['value'],vars)
" 	endif
"       endfor
"     endif
"   endfor
"   echoe "template with id '".a:id."' not found"
" endfunction
" 
" function! vl#lib#template#template#TemplateTextById(id, ...)
"   exec vl#lib#brief#args#GetOptionalArg('vars', string({}))
"   let template = vl#lib#template#template#GetTemplateById(a:id, vars)
"   return template['text']
" endfunction
" 
" function! vl#lib#template#template#InsertTemplate(id,...)
"   exec vl#lib#brief#args#GetOptionalArg('vars', string({}))
"   let cursor_saved = getpos(".")
"   let text_to_insert = vl#lib#template#template#TemplateTextById(a:id,vars)
"   let @" = text_to_insert
"   if len(text_to_insert) == 0
"     echoe "strange. template resulted in empty string"
"   endif
"   exec "normal a\<c-r>\""
"   call cursor(cursor_saved)
" endfunction
" 
" function! vl#lib#template#template#CompleteTemplateId(ArgLead,L,P)
"   let ids = vl#lib#template#template#TemplateIdList()
"   let matching_ids= filter(deepcopy(ids), 
"      \ "v:val =~".string(s:quick_match_expr(a:ArgLead)))
"   call extend(matching_ids, filter(ids, "v:val =~".string(a:ArgLead)))
"   let matching_ids = vl#lib#listdict#list#Unique(matching_ids)
"   return join(matching_ids,"\n")
" endfunction
" 
" "|func this function can be used to be able to use omni completion
" function! vl#lib#template#template#CompleteTemplate(findstart, base)
"   if a:findstart
"     " locate the start of the word
"     let [bc,ac] = vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"     return len(bc)-len(matchstr(bc,'\%(\a\|\.\|\$\|\^\)*$'))
"   else
"     let ids = vl#lib#template#template#TemplateList()
"     let matching_ids= filter(deepcopy(ids), 
"        \ "v:val['id'] =~".string(s:quick_match_expr(a:base)))
"     call extend(matching_ids, filter(ids, "v:val['id'] =~".string(a:base)))
"     " let matching_ids = vl#lib#listdict#list#Unique(matching_ids)
"     echo len(matching_ids).' tepmlates found. choose on from list'
"     " unfortunately we have to add the text to be inserted right now..
"     for entry in matching_ids
"       if complete_check()
" 	return []
"       endif
"       let F = entry['get_template']
"       let template =   F(entry['value'])
"       let text_to_insert = template['text']
"       call complete_add( { 'word' : substitute(text_to_insert,"\n","\r",'g')
" 		       \ , 'abbr' : entry['id']
" 		       \ } )
" 		       "\ , 'menu': text_to_insert
" 
"     endfor
"   endif
" endfunction
" 
" "|func reads the last words before cursor and lets user choose an matching
" "|     template id from list. See example mapping
" "|     this also restores the paste option. This way you can use [%set paste%]
" "|+    in your template
" function! vl#lib#template#template#TemplateFromBufferWord()
"   let paste = &paste
"   let [b, a] = vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"   let word = matchstr(b,'\w*$')
"   let ids = split(vl#lib#template#template#CompleteTemplateId(word,0,0),"\n")
"   let id = vl#ui#userSelection#LetUserSelectIfThereIsAChoice("which template?", ids)
"   if id == ""
"     return 
"   endif
"   let text = repeat("\<bs>",len(word)).vl#lib#template#template#TemplateTextById(id)
"   return text."\<c-o>:set ".(paste ? "" : "no")."paste\<cr>"
" endfunction
" 
" "| adds template commands
" "| optional arguments are diretories to add templates form
" function! vl#lib#template#template#AddTemplateUI(...)
"   " gets a list of directories from b:vl_templates and lets the user choose one
"   " of them to add a new template
"   command! TemplateNew :call vl#lib#template#template#TemplateNew()<cr>
"   " gets a list of directories from b:vl_templates and lets the user choose one
"   " of them to edit a template
"   command! TemplateEdit :call vl#lib#template#template#TemplateEdit()<cr>
"   command! -buffer -nargs=1 -complete=custom,vl#lib#template#template#CompleteTemplateId TemplateInsert  :call vl#lib#template#template#InsertTemplate(<f-args>)
"   command! -buffer TemplateShowAvailibleIds :echo join(map(vl#lib#template#template#TemplateList(),"v:val['id']"),"\n")
"   " inoremap <m-t> <c-r>=vl#lib#template#template#TemplateTextById(input("template id :",'',"custom,vl#lib#template#template#CompleteTemplateId"))<cr>
"   Inoremap <m-s-t> <c-r>=vl#lib#template#template#TemplateFromBufferWord()<cr>
"  " <c-o>:redraw<cr>
"   call vl#lib#listdict#list#MapCopy(a:000,'vl#lib#template#template#AddTemplatesFromDirectory(Val)')
" endfunction
" 
" "| joins items from g:template_vars and b:template_vars to be used as initial
" "| variable dictionary in your own template providing functions (see ...#GetTemplate)
" function! vl#lib#template#template#GetVars()
"   let vars = deepcopy(vl#lib#vimscript#scriptsettings#GetValueByNameOrDefault('b:template_vars', {}))
"   call extend(vars, vl#lib#vimscript#scriptsettings#GetValueByNameOrDefault('g:template_vars', {}))
"   return vars
" endfunction
" 
" 
" "func arg list: list of [ "file", "template" ] to create
" "     optional arg is default values
" function! vl#lib#template#template#CreateFilesFromTemplates(list,...)
"   exec vl#lib#brief#args#GetOptionalArg('vars',string([]))
"   for [file, template] in a:list
"     exec 'sp '.file
"     " remove everything which might have been written by filetype templates
"     normal ggdG
"     let template_text = vl#lib#template#template#GetTemplateById(template, vars)
"     call vl#lib#template#template#InsertTemplate(template, vars)
"   endfor
" endfunction
" 
" " ------------------------
" " template handler where template text is given directly
" function! vl#lib#template#template#GetTemplate( template_text, ...)
"   exec vl#lib#brief#args#GetOptionalArg('vars', string({}))
"   let [ text, vars ] = vl#lib#template#template#PreprocessTemplatetext( a:template_text 
" 	\ ,  vars )
"   return { 'text' : text }
" endfunction
" 
" 
" " handles template given directly
" function! vl#lib#template#template#TemplateGivenDirectlyHandler(template)
"   if type(a:template) == 4 && vl#lib#listdict#dict#HasKey(a:template, 'template')
"     let template = a:template['template']
"     return [1, [{ 'id' : template['id']
" 	      \ , 'value' : template['text']
" 	      \ , 'get_template' : function('vl#lib#template#template#GetTemplate')
" 	      \ }] ]
"   else
"     return [0, "wrong handler"]
"   endif
" endfunction
" 
" " ------------------------
" " directory template handler
" function! vl#lib#template#template#GetDirectoryTemplate(path, ...)
"   exec vl#lib#brief#args#GetOptionalArg('vars', string({}))
"   let text = join(vl#lib#files#filefunctions#ReadFile(expand(a:path), ['strange error, template file '.a:path .' file not found'])
" 		\ , "\n")
"   let [ text2, vars ] = vl#lib#template#template#PreprocessTemplatetext( text
" 	\ , vars)
"   return { 'text' : text2 }
" endfunction
" 
" function! vl#lib#template#template#DirectoryTemplateHandler( template )
"   if type(a:template) == 4 && vl#lib#listdict#dict#HasKey(a:template, 'directory')
"     let directory = a:template['directory']
"     let template_files = split(globpath(expand(directory),'**/*'),"\n")
"     call filter(template_files, 'filereadable(v:val)') " no directories!
"     let templates = []
"     for file in template_files
"       call add(templates, { 'id' : matchstr(file, '^\%('.vl#lib#conversion#string#QuoteBackslashSpecial(expand(directory)).'\)\=[/\\]\=\zs.*\ze')
" 			\ , 'value' : file
" 			\ , 'get_template' : function('vl#lib#template#template#GetDirectoryTemplate')
" 			\ })
"     endfor
"     return [1, templates]
"   else
"     return [0, "wrong handler"]
"   endif
" endfunction
" 
" let s:templateHandlers=vl#lib#vimscript#scriptsettings#Load(
"     \ 'vl.lib.template.template.template_handlers'
"     \ , [ function('vl#lib#template#template#TemplateGivenDirectlyHandler')
"     \   , function('vl#lib#template#template#DirectoryTemplateHandler')
"     \   ] )
" end region 'file <dotvim>/autoload/vl/lib/template/template.vim'


" start region 'file <dotvim>/autoload/vl/dev/sql/sql.vim'
" "|fld   description : some helpers to make accessing SQL databases most easy
" "|fld   keywords : <+ this is used to index / group scripts ?+> 
" "|fld   initial author : <+ script author & email +>
" "|fld   mantainer : author
" "|fld   started on : 2008 Sep 14 08:31:10 PM
" "|fld   version: 0.0
" "|fld   dependencies: <+ vim-python, vim-perl, unix-tool sed, ... +>
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: unusable, experimental
" "|fld     os: <+ remove this value if script is os independent +>
" "|
" "|H1__  Documentation
" "|
" "|+     Also have a look at dbext on vim.org which has much more features
" 
" " retuns the text
" " a command is separated from other commands either
" " by empty lines or by ; (at the end of line)
" function! vl#dev#sql#sql#ThisSQLCommand()
"   if exists('b:thisSQLCommand')
"     return b:thisSQLCommand()
"   endif
"   let nr = line('.')
"   let up = nr -1
"   let down = nr
"   while up > 0 && getline(up) !~ ';$\|^\s*$'
"     let up = up - 1
"   endwhile
"   while down > 0 && getline(down) !~ ';$\|^\s*$'
"     let down = down + 1
"   endwhile
"   return getline(up+1,down)
" endfunction
" 
" function! vl#dev#sql#sql#UI()
"   nnoremap <buffer> <F2> :echo b:db_conn.query(join(vl#dev#sql#sql#ThisSQLCommand(),"\n"))<cr>
" endfunction
" 
" " =========== completion =============================================
" " what one of [ identifier, module ]
" function! vl#dev#sql#sql#Complete(findstart, base)
"     "findstart = 1 when we need to get the text length
"     if a:findstart == 1
"         let [bc,ac] = vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"         return len(bc)-len(matchstr(bc,'\%(\a\|\.\)*$'))
"     "findstart = 0 when we need to return the list of completions
"     else
"       if !exists('b:db_conn')
"         echoe "b:db_conn not set, call vl#dev#sql#sql#Connect(dbType,settings) to setup the connection"
"         return []
"       endif
"       let text = vl#dev#sql#sql#ThisSQLCommand()
"       let words = split(join(text,"\n"),'\s\|,')
"       let tables = b:db_conn.tables()
" 
"       let l = matchlist(a:base,'\([^.]*\)\.\([^.]*\)')
"       if len(l) > 2
"         let alias = l[1]
"         let aliasP = alias.'.'
"         let base = l[2]
"       else
"         let alias = ''
"         let aliasP = ''
"         let base = a:base
"       endif
" 
"       let tr = b:db_conn['regex']['table']
"       let pat = '\zs\('.tr.'\)\s\+[aS][sS]\s\+\('.tr.'\)\ze' 
"       let pat2 = b:db_conn['regex']['table_from_match']
"       let aliases = {}
"       for aliasstr in vl#lib#regex#regex#MatchAll(join(text,"\n"),pat)
"         let l = matchlist(aliasstr, pat)
"         if len(l) > 2
"           let aliases[matchstr(l[2],pat2)] = matchstr(l[1], pat2)
"         endif
"       endfor
" 
"       " add table completion
"       if alias == ''
"         for t in tables
"           if t =~ vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching(base).'\|^'.base
"             call complete_add({'word' : t, 'menu' : 'a table'})
"           endif
"         endfor
"       endif
" 
"       let [bc,ac] = vl#lib#buffer#splitlineatcursor#SplitCurrentLineAtCursor()
"       if bc =~ '[fF][rR][oO][mM]\s\+$' || ac =~ '^\s*as\>' " before as are only tables allowed, after FROM as well
"         return []
"       endif
" 
"       " field completion
"       let table = get(aliases, alias,'')
"       if alias != '' && table == ''
"         let noAliasMatchWarning = ' ! alias not defined or table not found'
"       else
"         let noAliasMatchWarning = ''
"       endif
" 
"       if table == ''
"         let usedTables = vl#lib#listdict#list#Intersection(tables, words)
"       else
"         let usedTables = [table]
"       endif
"       let  g:usedTables = usedTables
"       let fields = []
"       for table in usedTables
"         for f in b:db_conn['fields'](table)
"           " maybe cache these regex - is it too slow?
"           if f =~ vl#lib#completion#quick_match_functions#AdvancedCamelCaseMatching(base).'\|^'.base
"             call complete_add({'word' : aliasP.f, 'abbr' : f, 'menu' : 'field of '.table.noAliasMatchWarning })
"           endif
"         endfor
"         call complete_check()|
"       endfor
"       return []
"     endif
" endfunction
" 
" " =========== selecting dbs ==========================================
" 
" " of course it's not a real "connection". It's an object which knows how to
" " run the cmd line tools
" function! vl#dev#sql#sql#Connect(dbType,settings)
"   let types =  { 'mysql' : function('vl#dev#sql#sql#MysqlConn') }
"   let b:db_conn = types[a:dbType](a:settings)
" endfunction
" 
" " the following functions (only MySQL implemented yet) all return 
" " an "object" having the function
" " query(sql)      runs any query and returns the result from stderr and stdout
" " tables()        list of tables
" " fields(table)   list of fields of the given table
" " invalidateSchema() removes cached schema data
" " schema          returns the schema
" " regex.table  : regex matching a table identifier
" 
" 
" " conn = attribute set
" " user : 
" " password :
" " database : (optional)
" " optional:
" " host :
" " port :
" " or
" " cmd : (this way you can even use ssh mysql ...)
" function! vl#dev#sql#sql#MysqlConn(conn)
"   let conn = a:conn
"   let conn['regex'] = {
"     \ 'table' :'\%(`[^`]\+`\|[^ \t`]\+\)' 
"     \ , 'table_from_match' :'^`\?\zs[^`]*\ze`\?$' 
"     \ }
"   if ! has_key(conn,'cmd')
"     let cmd=['mysql']
"     if has_key(conn, 'host')
"       call add(cmd,'-h') | call add(cmd,conn['host'])
"     endif
"     if has_key(conn, 'port')
"       call add(cmd,'-P') | call add(cmd,conn['port'])
"     endif
"     if has_key(conn, 'user')
"       call add(cmd,'-u') | call add(cmd,conn['user'])
"     endif
"     if has_key(conn, 'password')
"       call add(cmd,'--password='.conn['password'])
"     endif
"     let conn['cmd'] = cmd
"   endif
" 
"   function! conn.invalidateSchema()
"     let self['schema'] = {'tables' : {}}
"   endfunction
"   call conn['invalidateSchema']()
" 
"   function! conn.databases()
"     return vl#lib#listdict#list#MapIf(
"             \ split(vl#lib#system#system#System(self['cmd']+["-e",'show databases\G']),"\n"),
"             \ "Val =~ '^Database: '", "matchstr(Val, ".string('Database: \zs.*').")")
"   endfun
" 
"   " output must have been created with \G, no multilines supported yet
"   function! conn.col(col, output)
"     return vl#lib#listdict#list#MapIf( split(a:output,"\n")
"             \ , "Val =~ '^\\s*".a:col.": '", "matchstr(Val, ".string('^\s*'.a:col.': \zs.*').")")
"   endfunction
" 
"   if !has_key(conn,'database')
"     let conn['database'] = vl#ui#userSelection#LetUserSelectIfThereIsAChoice(
"       \ 'Select a mysql database', conn['databases']())
"   endif
" 
"   function! conn.tables()
"     " no caching yet
"     return vl#lib#listdict#list#MapIf(
"             \ split(vl#lib#system#system#System(self['cmd']+[self.database,"-e",'show tables\G']),"\n"),
"             \ "Val =~ '^Tables_in[^:]*: '", "matchstr(Val, ".string('Tables_in[^:]*: \zs.*').")")
" 
"   endfun
" 
"   function! conn.loadFieldsOfTables(tables)
"     for table in a:tables
"       let r = self.query('describe `'.table.'`\G')
"       let self['schema']['tables'][table] = { 'fields' : self.col('Field',r) }
"     endfor
"   endfunction
" 
"   function! conn.fields(table)
"     if !exists('self["schema"]["tables"]['.string(a:table).']["fields"]')
"       call self.loadFieldsOfTables([a:table])
"     endif
"     return self["schema"]["tables"][a:table]['fields']
"   endfunction
" 
"   function! conn.query(sql)
"     return  vl#lib#system#system#System(self['cmd']+[self['database']],{'stdin-text': a:sql})
"   endfun
" 
" 
"   return conn
" endfunction
" end region 'file <dotvim>/autoload/vl/dev/sql/sql.vim'


" start region 'file <dotvim>/autoload/vl/lib/listdict/list.vim'
" "" brief-description : Some util functions processing lists
" "" keywords : list 
" "" author : Marc Weber marco-oweber@gmx.de
" "" started on :2006 Oct 02 05:42:31
" "" version: 0.0
" 
" "|func returns last value of list or value_if_empty if list is empty
" function! vl#lib#listdict#list#Last(list, value_if_empty)
"   let len = len(a:list) 
"   if len == 0
"     return a:value_if_empty
"   else
"     return a:list[len-1]
"   endif
" endfunction
" 
" function! vl#lib#listdict#list#MaybeIndex(list, index, default)
"   if a:index>=0 && a:index < len(a:list)
"     return a:list[a:index]
"   else
"     return a:default
"   endif
" endfunction
" 
" function! vl#lib#listdict#list#ListContains(list, value)
"   for v in a:list
"     if v == a:value
"       return 1
"     endif
"   endfor
"   return 0
" endfunction
" 
" function! vl#lib#listdict#list#AddUnique(list, value)
"   if !vl#lib#listdict#list#ListContains(a:list, a:value)
"     return add(a:list, a:value)
"   else
"     return a:list
"   endif
" endfunction
" 
" function! vl#lib#listdict#list#Unique(list)
"   let result = {}
"   for v in a:list
"     let result[v]=0 " this will add the value only once
"   endfor
"   return keys(result)
" endfunction
" 
" "|func joins the list of list ( [[1,2],[3,4]] -> [1,2,3,4] )
" function! vl#lib#listdict#list#JoinLists(list_of_lists)
"   let result = []
"   for l in a:list_of_lists
"     call extend(result, l)
"   endfor
"   return result
" endfunction
" 
" "func this is used only in scriptsettings to merge global and buffer opts
" function! vl#lib#listdict#list#Concat(...)
"   return vl#lib#listdict#list#JoinLists(a:000)
" endfunction
" 
" " is there a better way to do this?
" " using remove?
" function! vl#lib#listdict#list#TrimListCount(list, count)
"   let c = 0
"   let result = []
"   for i in a:list
"     if c >= a:count 
"       break
"     endif
"     call add(result, i)
"     let c = c+1
"   endfor
"   return result
" endfunction
" 
" " the sme as map but returns the result of the map operation
" " You have to use Val instead of v:val
" " tip: You can also use things like
" " call vl#lib#listdict#list#MapCopy(['A'], ' exec "command ".Val." ".Val)
" function! vl#lib#listdict#list#MapCopy(listOrDict, expr)
"   let result = []
"   for Val in a:listOrDict
"     exec 'call add(result, '.a:expr.')'
"   endfor
"   return result
" endfunction
" 
" " combination of map and filter
" function! vl#lib#listdict#list#MapIf(list, pred, expr)
"   let result = []
"   for Val in a:list
"     exec 'let p = ('.a:pred.')'
"     exec 'if p | call add(result, '.a:expr.')|endif'
"   endfor
"   return result
" endfunction
" 
" function! vl#lib#listdict#list#Zip(...)
"   let a = a:000
"   let c = min( vl#lib#listdict#list#MapCopy(a,'len(Val)'))
"   let r = range(0,a:0-1)
"   let result = []
"   for i in range(0,c-1)
"     let l = []
"     for j in r
"       call add(l,a[j][i])
"     endfor
"     call add(result,l)
"   endfor
"   return result
" endfunction
" 
" function! vl#lib#listdict#list#Transpose(a)
"   let max_len = max( vl#lib#listdict#list#MapCopy(a:a, 'len(Val)')
"   let result = []
"   for i in range(0, max_len - 1)
"     let l = []
"     for j in len(a:a)
"       call add(result,a:a[j][i])
"     endfor
"     call add(result, l)
"   endfor
"   return result
" endfunction
" 
" "func 
" "pre  ['a','bbbbb','c']
" "     ['AAAAaa','B','C']
" "/pre is aligned this way:
" "pre  ['a     ','bbbbb','c']
" "     ['AAAAaa','B    ','C']
" "/pre this way
" "p    Example usage: AlignByChar 
" function! vl#lib#listdict#list#AlignToSameIndent(a)
"   call vl#lib#ide#logging#Log('align by char called with '.string(a:a))
"   "let result = a:a
"   "call map(result,"map(v:val,'substitute(v:val,\"^\\s*\\|\\s*$\",\"\",\"g\")')")
"   let result = []
"   for i in range(0, len(a:a) -1 )
"     let l = []
"       for j in range(0, len(a:a[i]) -1 )
"       call add(l, substitute(a:a[i][j],'^\s*\|\s*$','','g'))
"     endfor
"     call add(result, l)
"   endfor
"   let max_len = max( vl#lib#listdict#list#MapCopy(result, 'len(Val)'))
"   for i in range(0, max_len -1)
"     let max = -1
"     for j in range(0, len(result)-1)
"       let c = strlen(vl#lib#listdict#list#MaybeIndex(result[j] , i,''))
"       if c > max
"         let max = c
"       endif
"     endfor
"     for j in range(0, len(result) -1)
"       if i < len(result[j])
"         let v = result[j][i]
"         let result[j][i] = repeat(' ',max-strlen(v)) . v
"       endif
"     endfor
"   endfor
"   return result
" endfunction
" 
" "func tries to give these characters the same indent
" function! vl#lib#listdict#list#AlignByChar(char) range
"   let lines = getline(a:firstline, a:lastline)
"   call map(lines,"split(v:val,".string('\s*'.a:char.'\s*').",1)")
"   call vl#lib#ide#logging#Log('lines '.string(lines))
"   let lists = vl#lib#listdict#list#AlignToSameIndent(lines)
"   call vl#lib#ide#logging#Log('lists '.string(lists))
"   call map(lists, "join(v:val,".string(a:char).")")
"   call vl#lib#ide#logging#Log('lists joined '.string(lists))
"   for i in range(0, len(lists) - 1)
"     call setline(a:firstline+i, lists[i])
"   endfor
" endfunction
" 
" "func removes the last element from the list and returns it
" "     as push simply use call add(list,item)
" function! vl#lib#listdict#list#PopLast(list)
"   return remove(a:list,len(a:list)-1)[0]
" endfunction
" 
" function! vl#lib#listdict#list#Pop(list, ...)
"   if len(a:list) == 0
"     exec vl#lib#brief#args#GetOptionalArg('default',string('empty list'))
"     return default
"   else
"     return remove(a:list,0,0)[0]
"   endif
" endfunction
" 
" function! vl#lib#listdict#list#Union(...)
"   let result = {}
"   for l in a:000
"     for item in l
"       let result[item] = 1
"     endfor
"   endfor
"   return keys(result)
" endfunction
" 
" " returns the items beeing contained only in and not in b (might be slow)
" function! vl#lib#listdict#list#Difference(a,b)
"   let result = []
"   for i in a:a
"     if !vl#lib#listdict#list#ListContains(a:b, i)
"       call add(result, i)
"     endif
"   endfor
"   return result
" endfunction
" 
" " element must be contained in both (might be slow)
" function! vl#lib#listdict#list#Intersection(a,b)
"   let result = []
"   for i in a:a
"     if vl#lib#listdict#list#ListContains(a:b, i)
"       call add(result, i)
"     endif
"   endfor
"   return result
" endfunction
" 
" " returns true if all list items satisfy pred
" function! vl#lib#listdict#list#All(l,pred)
"   for Val in a:l
"     exec 'if !('.a:pred.')| return 0|endif'
"   endfor
"   return 1
" endfunction
" 
" " returns true if at least one item satisfies pred
" function! vl#lib#listdict#list#Any(l,pred)
"   for Val in a:l
"     exec 'let res = '.a:pred
"     if res
"       return 1
"     endif
"   endfor
"   return 0
" endfunction
" " this dosen't work for some unkown reason:
"   "for val in a:l
"     "exec 'if ('.a:pred.')| return 1|endif'
"   "endfor
" 
" function! vl#lib#listdict#list#ToList(a)
"   if type(a:a) == 3
"     return a:a
"   else
"     return [a:a]
"   endif
" endfunction
" 
" function! vl#lib#listdict#list#ForEach(l, toExecute)
"   for Val in a:l 
"     exec a:toExecute
"   endfor
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/listdict/list.vim'


" start region 'file <dotvim>/autoload/vl/lib/listdict/dict.vim'
" "|fld   description : Some helper functions to work with dictionaries
" "|fld   keywords : <+ this is used to index / group scripts ?+> 
" "|fld   initial author : <+ script author & email +>
" "|fld   mantainer : author
" "|fld   started on : 2006 Oct 29 19:10:32
" "|fld   version: 0.0
" "|fld   dependencies: <+ vim-python, vim-perl, unix-tool sed, ... +>
" "|fld   contributors : <+credits to+>
" "|fld   tested on os : <+credits to+>
" "|fld   maturity: unusable, experimental
" "|fld     os: <+ remove this value if script is os independent +>
" "|
" "|H1__  Documentation
" "|
" "|p     <+some more in depth discription
" "|+     <+ joined line ... +>
" "|p     second paragraph
" "|H2_   typical usage
" "|H3    plugin-file
" "|pl    " <+ description +>
" "|      <+ plugin command +>
" "|
" "|      " <+ description +>
" "|      <+ plugin mapping +>
" "|H3    ftp-file
" "|ftp   " <+ description +>
" "|     <command -nargs=0 -buffer XY2 :echo "XY2"
" "|
" "|H2__  settigns
" "|set   <description of setting(s)>
" "|      "description
" 
" "|func Does dictionary has the key key?
" function! vl#lib#listdict#dict#HasKey(dict, key)
"   return exists('a:dict['.string(a:key).']')
" endfunction
" 
" "|func empties a dictionary
" function! vl#lib#listdict#dict#EmptyDict(dict)
"   for key in keys(a:dict)
"     call remove(a:dict, key)
"   endfor
" endfunction
" 
" " to be used in map( (see quickfix#filtermod
" " example can be found in  vl#lib#quickfix#filtermod#ProcessQuickFixResult(functionName)
" function! vl#lib#listdict#dict#SetReturn(dict,key,value)
"   let d = a:dict
"   let d[a:key] = a:value
"   return d
" endfunction
" end region 'file <dotvim>/autoload/vl/lib/listdict/dict.vim'


" start region 'file <dotvim>/autoload/vl/lib/vimscript/scriptsettings.vim'
" " script-purpose: store/ restore script settings in one place/ file
" " author: Marc Weber (marco-oweber@gmx.de)
" " started : Mon Sep 18 07:12:45 CEST 2006
" " description: Its not a very good idea to store script settings in the
" " script file.. because you might update them and you'll have to copy your
" " settings. This implementation tries to improve this by providing a small
" " interface to load/ save custom settings in a unique file..
" "
" " Todo: Implement set setting
" " a) Set<SettnigName> <value>
" " b) Set <settingname> <value>
" "
" " proposed usage: 
" " * see let g:settings_file below,
" " * let s:setting = vl#lib#vimscript#scriptsettings#Load('script.settingname',default)
" " * let s:setting = CreateSetting('script.settingname',default)
" 
" " proposed values  (need your help and opinion here)
" " * if your script needs some permanent memory 
" "   (eg vl#dev#vimscript#autoloadprefix#UpdateAutoloadFunctionList )
" "   save it somewhere in 
" "   vl#lib#vimscript#scriptsettings#Load('permanent_memory',vl#settings#DotvimDir().'permament_memory')
" " * your proposals ...
" 
" "|func  if setting 'globalname' (eg g:test_var) exists return it else return
" "|      default_value
" function! vl#lib#vimscript#scriptsettings#GetValueByNameOrDefault(globalname, default_value)
"   if exists(a:globalname)
"     exec 'return '.a:globalname
"   else
"     return a:default_value
"   endif
" endfunction
" 
" "|func gets value if var is defined else defines var with result of func
" function! vl#lib#vimscript#scriptsettings#GetOrDefine(var, get_var_content)
"   if exists(a:var)
"     exec 'return '.a:var
"   else
"     exec 'let '.a:var.' = '.a:get_var_content
"     exec 'return '.a:var
"   endif
" endfunction
" 
" "|func gets value if var is defined else defines var with result of func
" "|+    advantage over GetOrDefine: The string value get_var_content_str is
" "|+    evaluated if needed only thus you can use this to ask the user (eg
" "|+    input)
" function! vl#lib#vimscript#scriptsettings#GetOrDefineFromString(var, get_var_content_str)
"   if exists(a:var)
"     exec 'return '.a:var
"   else
"     exec 'let '.a:var.' = '.a:get_var_content_str
"     exec 'return '.a:var
"   endif
" endfunction
" 
" let g:settings_file = vl#lib#vimscript#scriptsettings#GetValueByNameOrDefault('g:settings_file',vl#settings#DotvimDir().'script_settings')
" 
" " save setting value with id
" " fix me: preserve order ?
" function! vl#lib#vimscript#scriptsettings#Save(id, value)
"   let f = filter(vl#lib#files#filefunctions#ReadFile(g:settings_file,[]),"v:val !~ '^".a:id.":'")
"   call add(f,a:id.':'.string(a:value))
"   call vl#lib#files#filefunctions#WriteFile(f, g:settings_file)
" endfunction
" 
" function! vl#lib#vimscript#scriptsettings#Load(id, default)
"   let f = filter(vl#lib#files#filefunctions#ReadFile(g:settings_file,[]),"v:val =~ '^".a:id.":'")
"   if len(f) == 0
"     return a:default
"   else
"     return eval(substitute(f[0],'^'.a:id.':','',''))
"   endif
" endfunction
" 
" " some helper functions
" 
" " add String to Stringlist if it hasn't been added yet
" function! vl#lib#vimscript#scriptsettings#AddValueToListUnique(id, value)
"   call vl#lib#vimscript#scriptsettings#AlterSetting(a:id, [], 
" 	\ "call vl#lib#listdict#list#AddUnique(value,".string(a:value).")")
" endfunction
" " remove a value from a list
" function! vl#lib#vimscript#scriptsettings#RemoveValueFromList(id, value)
"   call vl#lib#vimscript#scriptsettings#AlterSetting(a:id, [], 
" 	\ 'call filter(value,"v:val!='.string(a:value).'")')
" endfunction
" 
" " use this function to alter a value using command cmd. the value can be
" " accessed by value. If you need an example have a look at 
" " function! vl#lib#tags#taghelper#AddTagProfile(profile_name, cmd)
" function! vl#lib#vimscript#scriptsettings#AlterSetting(id, default, cmd)
"   let value = vl#lib#vimscript#scriptsettings#Load(a:id ,a:default)
"   exec a:cmd
"   call vl#lib#vimscript#scriptsettings#Save(a:id, value)
" endfunction
" 
" " caption will be shown above the list
" " cmd_nothing_selected will get executed if user selects nothing (thus you can
" " return a value or raise an exception or ..0)
" function! vl#lib#vimscript#scriptsettings#LetUserChoseKeyFromDict(caption, id, default, cmd_nothing_selected )
"   let dict = vl#lib#vimscript#scriptsettings#Load(a:id, a:default)
"   let [index, key] = vl#ui#userSelection#LetUserSelectOneOf(a:caption, keys(dict), "return both")
"   if index == -1 
"     exec a:cmd_nothing_selected
"   else
"     return key
"   endif
" endfunction
" 
" "TODO: Remove (used in switch_files) replace by get MergeSetting
" function! vl#lib#vimscript#scriptsettings#MergeGlobBList(name)
"   let Result = []
"   let g = vl#lib#vimscript#scriptsettings#GetValueByNameOrDefault('g:'.a:name,[])
"   let b = vl#lib#vimscript#scriptsettings#GetValueByNameOrDefault('b:'.a:name,[])
"   return g+b
" endfunction
" 
" function! vl#lib#vimscript#scriptsettings#MergeSettings(name, merge_func, default, ...)
"   exec vl#lib#brief#args#GetOptionalArg('allowFunctions', string(1))
"   let settings_to_merge = ['g:','b:']
"   call map(settings_to_merge,'v:val.a:name')
"   for s in settings_to_merge
"     if exists(s)
"       exec 'let V = '.s
"       if type(V) == 2 && allowFunctions
"         let v2 = V()  " is function
"       else
"         let v2 = V
"       endif
"       if exists('Result')
"         let Result = a:merge_func(Result, v2)
"       else 
"         let Result = v2
"       endif
"       unlet V
"       unlet v2
"     endif
"   endfor
"   if !exists('Result')
"     exec 'return '.a:default
"   else 
"     return Result
"   endif
" endfunction
" 
" "|func merges setting name (g: and b:) returs [] if not set at all
" "|p     example
" "|code 
" "|     let g:t=range(1,10)
" "|     let b:t=range(120,130)
" "|     echo vl#lib#vimscript#scriptsettings#SettingList('t')
" "|     returns
" "|     [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130]
" "|
" "| needs vl#lib#listdict#list#Concat( (dummy for auto dependencies)
" function! vl#lib#vimscript#scriptsettings#SettingList(name, ...)
"   exec vl#lib#brief#args#GetOptionalArg('default', string([]))
"   return vl#lib#vimscript#scriptsettings#MergeSettings(a:name
"         \ , vl#dev#vimscript#vimfile#Function('vl#lib#listdict#list#Concat')
"         \ , string(default), 1)
" endfunction
" 
" " .. more to come
" 
" " snd argument is value to set to
" " if it doesn't exist can't be nested
" function! vl#lib#vimscript#scriptsettings#StoreSetting(setting_as_string, ...)
"   if exists(a:setting_as_string)
"     let dict = vl#lib#vimscript#scriptsettings#GetOrDefine('g:stored_settings',{})
"     let val = get(dict, a:setting_as_string, [])
"     let dict[a:setting_as_string] = val " in case it didn't exst reassign
"     " prepend setting (push on stack)
"     exec 'call add(val,'.a:setting_as_string.')'
"   endif
"   if a:0 > 0
"     if exists(a:setting_as_string)
"       unlet a:setting_as_string
"     endif
"     exec 'let '.a:setting_as_string.' = a:1'
"   endif
" endfunction
" 
" function! vl#lib#vimscript#scriptsettings#RestoreSetting(setting_as_string)
"   " TODO: remove empty lists from g:stored_settings
"   let dict = vl#lib#vimscript#scriptsettings#GetOrDefine('g:stored_settings','{}')
"   let val = get(dict, a:setting_as_string, [])
"   " prevent type mismatch value"
"   if exists(a:setting_as_string)
"     exec 'unlet '.a:setting_as_string
"   endif
"   if len(val)>0
"     let last = len(val) -1
"     " we assume wasn't set when storing
"     exec 'let '.a:setting_as_string.' = remove(val,last)'
"   endif
" endfunction
" 
" ""| joins items from g:template_vars and b:template_vars to be used as initial
" ""| variable dictionary in your own template providing functions (see ...#GetTemplate)
" "function vl#lib#vimscript#scriptsettings#GetGOrBVar()
" "let vars = vl#lib#vimscript#scriptsettings#GetValueOrDefault('b:template_vars', {})
" "call extend(vars, vl#lib#vimscript#scriptsettings#GetValueOrDefault('g:template_vars', {})
" "return vars
" "endfunction
" 
" end region 'file <dotvim>/autoload/vl/lib/vimscript/scriptsettings.vim'

