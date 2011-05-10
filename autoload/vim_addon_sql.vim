" first implementation done on 2008 Sep 14 08:31:10 PM
" After including this code in TOVL (which is deprecated) this code has a new
" (final)
" home in vim-addon-sql now.
"
" alternative plugins: SQLComplete and dbext (However the completion system
" provided by this code is more accurate cause it only shows fields of all
" talbes found in a query. What is a query? See ThisSQLCommand
"
" supported databases:
" - MySQL
" - postgresql
" - sqlite (work in progress
"
" There are two windows:
" a) the result window
" b) the error window
"
" Mayb this code could be cleaned up ?

" vam#DefineAndBind('s:config','g:vim_addon_sql','{}')
if !exists('g:vim_addon_sql') | let g:vim_addon_sql = {} | endif | let s:c = g:vim_addon_sql
let s:c['isql'] = get(s:c,'isql','isql')
let s:c['mysql'] = get(s:c,'mysql','mysql')
let s:c['psql'] = get(s:c,'psql','psql')
let s:c['sqlite3'] = get(s:c,'sqlite3','sqlite3')

let s:thisDir = expand('<sfile>:h')
let s:mysqlFunctionsDump = s:thisDir.'/mysql-functions.dump'

" retuns the text
" a command is separated from other commands either
" by empty lines or by ; (at the end of line)
function! vim_addon_sql#ThisSQLCommand()
  if exists('b:thisSQLCommand')
    return b:thisSQLCommand()
  endif
  let nr = line('.')
  let up = nr -1
  let down = nr
  while up > 0 && getline(up) !~ ';$\|^\s*$'
    let up = up - 1
  endwhile
  while down <= line('$') && getline(down) !~ ';$\|^\s*$'
    let down = down + 1
  endwhile
  return getline(up+1,down)
endfunction

fun! vim_addon_sql#RunAndShow(sql)
  let result =  b:db_conn.query(a:sql)
  TScratch 'scratch': '__SQL_RESULT__'
  call append(line('$'), ['',''])
  call append(line('$'), a:sql)
  call append(line('$'), split(result,"\n"))
  normal G
  wincmd w
endf

function! vim_addon_sql#UI()
  nnoremap <buffer> <F2> :call vim_addon_sql#RunAndShow(join(vim_addon_sql#ThisSQLCommand(),"\n"))<cr>
  vnoremap <buffer> <F2> y:echo b:db_conn.query(@")<cr>
endfunction

let s:error_buf_name = '__SQL_ERROR__'

fun! s:ShowError(err)
  exec "TScratch 'scratch':'".s:error_buf_name."'"
  normal ggdG
  call append(line('$'), split(a:err,"\n"))
endf

fun! s:ClearError(result)
  let r = bufnr('__SQL_ERROR__')
  if r > 0
    exec r.'bw'
  endif
  return a:result
endf

" duplicate code, also found in TOVL {{{1
fun! vim_addon_sql#SplitCurrentLineAtCursor()
  let pos = col('.') -1
  let line = getline('.')
  return [strpart(line,0,pos), strpart(line, pos, len(line)-pos)]
endfunction

"|func returns a list of all matches of the regex
function! vim_addon_sql#MatchAll(str, regex)
  let matches = []
  let s = a:str
  while 1
    let pos = match(s,a:regex)
    if pos == -1 
      return matches
    else
      let match = matchstr(s, a:regex)
      call add(matches, match)
      let s = strpart(s,strlen(match)+pos)
    endif
  endwhile
endfunction


fun! vim_addon_sql#Intersection(a,b)
  let result = []
  for i in a:a
    if index(a:b, i) != -1
      call add(result, i)
    endif
  endfor
  return result
endf

" combination of map and filter
function! vim_addon_sql#MapIf(list, pred, expr)
  let result = []
  for Val in a:list
    exec 'let p = ('.a:pred.')'
    exec 'if p | call add(result, '.a:expr.')|endif'
  endfor
  return result
endfunction


fun! vim_addon_sql#EscapeShArg(arg)
  " zsh requires []
  return escape(a:arg, ";()*<>| '\"\\`[]&")
endf

" usage: vim_addon_sql#System( ['echo', 'foo'], {'stdin-text' : 'will be ignored by echo', status : 0 })
fun! vim_addon_sql#System(items, ... )
  let opts = a:0 > 0 ? a:1 : {}
  let cmd = ''
  for a in a:items
    let cmd .=  ' '.vim_addon_sql#EscapeShArg(a)
  endfor
  if has_key(opts, 'stdin-text')
    let f = tempname()
    " don't know why writefile(["line 1\nline 2"], f, 'b') has a different
    " result?
    call writefile(split(opts['stdin-text'],"\n"), f, 'b')
    let cmd = cmd. ' < '.f
    " call s:Log(1, 'executing system command: '.cmd.' first 2000 chars of stdin are :'.opts['stdin-text'][:2000])
  else
    " call s:Log(1, 'executing system command: '.cmd)
  endif

  let result = system(cmd .' 2>&1')
  "if exists('f') | call delete(f) | endif
  let g:systemResult = result

  let s = get(opts,'status',0)
  if v:shell_error != s && ( type(s) != type('') || s != '*'  )
    let g:systemResult = result
    throw "command ".cmd."failed with exit code ".v:shell_error
     \ . " but ".s." expected. Have a look at the program output with :echo g:systemResult".repeat(' ',400)
     \ . " the first 500 chars of the result are \n".strpart(result,0,500)
  endif
  return result
endfun

" =========== completion =============================================


fun! s:Match(s)
  return a:s =~ s:base || s:additional_regex != "" && a:s =~ s:additional_regex
endf

" what one of [ identifier, module ]
function! vim_addon_sql#Complete(findstart, base)
    "findstart = 1 when we need to get the text length
    if a:findstart == 1
        let [bc,ac] = vim_addon_sql#SplitCurrentLineAtCursor()
        return len(bc)-len(matchstr(bc,'\%(\a\|\.\|_\)*$'))
    "findstart = 0 when we need to return the list of completions
    else

      if !exists('b:db_conn')
        echoe "b:db_conn not set, call vim_addon_sql#Connect(dbType,settings) to setup the connection"
        return []
      endif
      let text = vim_addon_sql#ThisSQLCommand()
      let words = split(join(text,"\n"),"[\n\r \t'\"()\\[\\],;]")
      let tables = b:db_conn.tables()

      let l = matchlist(a:base,'\([^.]*\)\.\([^.]*\)')
      if len(l) > 2
        let alias = l[1]
        let aliasP = alias.'.'
        let base = l[2]
      else
        let alias = ''
        let aliasP = ''
        let base = a:base
      endif
      let s:base = a:base[len(aliasP):]
      let s:additional_regex = ""
      let patterns = vim_addon_completion#AdditionalCompletionMatchPatterns(s:base
            \ , "vim_dev_plugin_completion_func", {'match_beginning_of_string': 0})
      let s:additional_regex = get(patterns, 'vim_regex', "")

      let tr = b:db_conn['regex']['table']
      let pat = '\zs\('.tr.'\)\s\+\cas\C\s\+\('.tr.'\)\ze' 
      let pat2 = b:db_conn['regex']['table_from_match']
      let aliases = {}
      for aliasstr in vim_addon_sql#MatchAll(join(text,"\n"),pat)
        let l = matchlist(aliasstr, pat)
        if len(l) > 2
          let aliases[matchstr(l[2],pat2)] = matchstr(l[1], pat2)
        endif
      endfor

      let [bc,ac] = vim_addon_sql#SplitCurrentLineAtCursor()

      " before AS or after SELECT ... FROM, INSERT INTO .. CREATE / DROP / ALTER TABLE only table names will be shown
      let tablesOnly =  (bc =~ '\c\%(FROM[^(]*\s\+\|JOIN\s\+\|INTO\s\+\|TABLE\s\+\)\C$' && bc !~ '\cWHERE' ) || ac =~ '^\s*as\>'

      if ! tablesOnly
        " field completion
        let table = get(aliases, alias,'')
        if alias != '' && table == ''
          let noAliasMatchWarning = ' ! alias not defined or table not found'
        else
          let noAliasMatchWarning = ''
        endif

        if table == ''
          let usedTables = vl#lib#listdict#list#Intersection(tables, words)
        else
          let usedTables = [table]
        endif
        let  g:usedTables = usedTables
        let fields = []
        for table in usedTables
          for f in b:db_conn['fields'](table)
            if s:Match(f)
              call complete_add({'word' : aliasP.f, 'abbr' : f, 'menu' : 'field of '.table.noAliasMatchWarning, 'dup': 1})
            endif
          endfor
          call complete_check()
        endfor
      endif

      if alias == '' && !(bc !~ '\cFROM' && ac =~ '\cFROM')
        for t in tables
          if s:Match(t)
            call complete_add({'word' : t, 'menu' : 'a table'})
          endif
        endfor
      endif

      if alias == '' && exists('b:db_conn.extraCompletions')
        call b:db_conn.extraCompletions()
      endif

      return []
    endif
endfunction

" =========== selecting dbs ==========================================

" of course it's not a real "connection". It's an object which knows how to
" run the cmd line tools
function! vim_addon_sql#Connect(dbType,settings)
  let types = {
    \ 'mysql' : function('vim_addon_sql#MysqlConn'),
    \ 'pg' : function('vim_addon_sql#PostgresConn'),
    \ 'sqlite' : function('vim_addon_sql#SqliteConn')
    \ }
  let b:db_conn = types[a:dbType](a:settings)
endfunction

" the following functions (only MySQL, Postgresql, SQLite implemented yet) all return 
" an "object" having the function
" query(sql)      runs any query and returns the result from stderr and stdout
" tables()        list of tables
" fields(table)   list of fields of the given table
" invalidateSchema() removes cached schema data
" schema          returns the schema
" regex.table  : regex matching a table identifier

" MySQL implementation {{{1
" conn = attribute set
" user : 
" password :
" database : (optional)
" optional:
" host :
" port :
" or
" cmd : (this way you can even use ssh mysql ...)
function! vim_addon_sql#MysqlConn(conn)
  let conn = a:conn
  let conn['regex'] = {
    \ 'table' :'\%(`[^`]\+`\|[^ \t`]\+\)' 
    \ , 'table_from_match' :'^`\?\zs[^`]*\ze`\?$' 
    \ }
  if ! has_key(conn,'cmd')
    let cmd=[s:c.mysql]
    if has_key(conn, 'host')
      call add(cmd,'-h') | call add(cmd,conn['host'])
    endif
    if has_key(conn, 'port')
      call add(cmd,'-P') | call add(cmd,conn['port'])
    endif
    if has_key(conn, 'user')
      call add(cmd,'-u') | call add(cmd,conn['user'])
    endif
    if has_key(conn, 'password')
      call add(cmd,'--password='.conn['password'])
    endif
    if has_key(conn, 'extra_args')
      call add(cmd,conn['extra_args'])
    endif
    let conn['cmd'] = cmd
  endif

  fun! conn.extraCompletions()
    " TODO add Postgresql function names
    if !exists('self["functions"]')
      let self['functions'] = eval(readfile(s:mysqlFunctionsDump)[0])
    endif
    for [d,v] in items(self['functions'])
      if s:Match(d)
        let args = d.'('. v.args .')'
        call complete_add({'word': d.(v.args == '' ? '' : '(')
              \ ,'menu': args
              \ ,'info': args."\n".v.description
              \ ,'dup': 1})
      endif
    endfor
  endf

  function! conn.invalidateSchema()
    let self['schema'] = {'tables' : {}}
  endfunction
  call conn['invalidateSchema']()

  function! conn.databases()
    return vim_addon_sql#MapIf(
            \ split(vim_addon_sql#System(self['cmd']+["-e",'show databases\G']),"\n"),
            \ "Val =~ '^Database: '", "matchstr(Val, ".string('Database: \zs.*').")")
  endfun

  " output must have been created with \G, no multilines supported yet
  function! conn.col(col, output)
    return vim_addon_sql#MapIf( split(a:output,"\n")
            \ , "Val =~ '^\\s*".a:col.": '", "matchstr(Val, ".string('^\s*'.a:col.': \zs.*').")")
  endfunction

  if !has_key(conn,'database')
    let conn['database'] = tlib#input#List("s" 'Select a mysql database', conn['databases']())
  endif

  function! conn.tables()
    " no caching yet
    return vim_addon_sql#MapIf(
            \ split(vim_addon_sql#System(self['cmd']+[self.database,"-e",'show tables\G']),"\n"),
            \ "Val =~ '^Tables_in[^:]*: '", "matchstr(Val, ".string('Tables_in[^:]*: \zs.*').")")

  endfun

  function! conn.loadFieldsOfTables(tables)
    for table in a:tables
      let r = self.query('describe `'.table.'`\G')
      let self['schema']['tables'][table] = { 'fields' : self.col('Field',r) }
    endfor
  endfunction

  function! conn.fields(table)
    if !exists('self["schema"]["tables"]['.string(a:table).']["fields"]')
      call self.loadFieldsOfTables([a:table])
    endif
    return self["schema"]["tables"][a:table]['fields']
  endfunction

  function! conn.query(sql)
    try
      return s:ClearError(vim_addon_sql#System(self['cmd']+[self['database']],{'stdin-text': a:sql}))
    catch /.*/
      call s:ShowError(v:exception)
    endtry
  endfun


  return conn
endfunction


fun! vim_addon_sql#ExtractMysqlFunctionsFromInfoFile(path)
  " mysql source contains Docs/mysql.info
  " Thus func extracts info about all functions
  exec 'sp '.fnameescape(a:path)
  normal gg
  let functions = {}
  while search('^   \*  \`\S\+(','W')
    exec 'normal v/^   \*  \`\S\+(\|^\S/-1'."\<cr>y"
    let c = split(@","\n")
    let header = ''
    while c[0] !~ '^\s*$'
      let header .= c[0]
      let c = c[1:]
    endwhile
    let header = substitute(header,'\s\+',' ','g')[4:]
    for i in split(header, "', \\`")
      let r = matchlist(i, '\([^(]\+\)(\([^)]*\)')
      if len(r) < 2
        echoe '>> '.string(i)
      endif
      let functions[r[1]] = {'args': r[2], 'description':join(c[1:],"\n")}
    endfor
  endwhile
  call writefile([string(functions)], s:mysqlFunctionsDump)
endf

" postgres implementation {{{1
function! vim_addon_sql#PostgresConn(conn)
  let conn = a:conn
  let conn['regex'] = {
    \ 'table' :'\%(`[^`]\+`\|[^ \t`]\+\)' 
    \ , 'table_from_match' :'^`\?\zs[^`]*\ze`\?$' 
    \ }
  if ! has_key(conn,'cmd')
    let cmd=[s:c.psql]
    if has_key(conn, 'host')
      call add(cmd,'-h') | call add(cmd,conn['host'])
    endif
    if has_key(conn, 'port')
      call add(cmd,'-P') | call add(cmd,conn['port'])
    endif
    if has_key(conn, 'user')
      call add(cmd,'-U') | call add(cmd,conn['user'])
    endif
    " use a .pgpass file or define PGPASS ..
    "if has_key(conn, 'password')
    "  call add(cmd,'--password='.conn['password'])
    "endif
    if has_key(conn, 'extra_args')
      call add(cmd,conn['extra_args'])
    endif
    let conn['cmd'] = cmd
  endif

  fun! conn.extraCompletions()
    " TODO add Postgresql function names
    if !exists('self["functions"]')
      let self['functions'] = self.parse(self.query('\df'))
    endif
    for line in self['functions']
      if s:Match(line[1])
        call complete_add({'word': line[1] .'('.join(map(split(line[3],', '),'"<+".v:val."+>"'),", ").')'
              \ ,'abbr': line[1]
              \ ,'menu': line[0].' '.line[2].' '.substitute(line[3],'\<\([^ ]\{0,2}\)[^, ]*','\1','g')
              \ ,'info': line[3]
              \ ,'dup': 1})
      endif
    endfor
  endf

  function! conn.invalidateSchema()
    let self['schema'] = {'tables' : {}}
  endfunction
  call conn['invalidateSchema']()

  " parse output of psql -l or echo '\d tablename' | psql
  " output must be a string
  function conn.parse(output)
    let lines = split(a:output, "\n")
    let idx = 0
    " ignore headlines
    while idx < len(lines) && lines[idx][:3] != "----" 
      let idx = idx+1
    endwhile
    let idx = idx+1

    let result = []
    while idx < len(lines)
      if lines[idx][0] == '(' || lines[idx] =~ '^\s*$'
        " break when reaching num of lines
        break
      endif
      let cols = split(lines[idx],'|')
      call map(cols, 'matchstr(v:val, "^\\s*\\zs.\\{-}\\ze\\s*$")')
      call add(result, cols)
      let idx=idx+1
    endwhile
    return result
  endfun

  function! conn.databases()
    throw "conn.dabases not implemented for sqlite"
  endfun

  function! conn.tables()
    return map(self.parse(self.query('\dt')),'v:val[1]')
  endfun

  function! conn.loadFieldsOfTables(tables)
    if !exists('self["schema"]["tables"]['.string(a:table).']["fields"]')
      call self.loadFieldsOfTables([a:table])
    endif
    return self["schema"]["tables"][a:table]['fields']
  endfunction

  function! conn.fields(table)
    if !exists('self["schema"]["tables"]['.string(a:table).']["fields"]')
      call self.loadFieldsOfTables([a:table])
    endif
    return self["schema"]["tables"][a:table]['fields']
  endfunction

  function! conn.query(sql)
    try
      return s:ClearError(vim_addon_sql#System(self['cmd']+[self['database']],{'stdin-text': a:sql}))
    catch /.*/
      call s:ShowError(v:exception)
    endtry
  endfun

  return conn
endfunction


" sqlite implementation {{{1
" conn must be {'filepath:'..','cmd':'sqlite3'}
function! vim_addon_sql#SqliteConn(conn)
  let conn = a:conn
  let conn['executable'] = get(conn,'executable', 'sqlite3')
  let conn['regex'] = {
    \ 'table' :'\%(`[^`]\+`\|[^ \t`]\+\)' 
    \ , 'table_from_match' :'^`\?\zs[^`]*\ze`\?$' 
    \ }
  if ! has_key(conn,'database')
    throw 'sqlite connection requires key database!'
  endif

  if ! has_key(conn,'cmd')
    let conn['cmd']=[s:c.sqlite3]
  endif

  fun! conn.extraCompletions()
    " TODO add sqlite function names etc
    return []
  endf

  function! conn.invalidateSchema()
    let self['schema'] = {'tables' : {}}
  endfunction
  call conn['invalidateSchema']()

  function! conn.databases()
    return vim_addon_sql#MapIf(
            \ split(vim_addon_sql#System(self['cmd']+["-e",'show databases\G']),"\n"),
            \ "Val =~ '^Database: '", "matchstr(Val, ".string('Database: \zs.*').")")
  endfun

  " output must have been created with \G, no multilines supported yet
  function! conn.col(col, output)
    return vim_addon_sql#MapIf( split(a:output,"\n")
            \ , "Val =~ '^\\s*".a:col.": '", "matchstr(Val, ".string('^\s*'.a:col.': \zs.*').")")
  endfunction

  function! conn.tables()
    " no caching yet
    " TODO: handle spaces and quoting ?
    return split(self.query('.tables'),'[ \t\r\n]\+')
  endfun

  function! conn.loadFieldsOfTables(tables)
    for table in a:tables
      let fields = []
      let lines = split(self.query('.schema '.table),"\n")
      for l in lines
        if l =~ 'CREATE TABLE' | continue | endif
        " endo of field list
        if l =~ ');' | break | endif
        call add(fields, matchstr( l, '^,\zs\?\S*\ze') )
      endfor
      let self['schema']['tables'][table] = { 'fields' : fields }
    endfor
  endfunction

  function! conn.fields(table)
    if !exists('self["schema"]["tables"]['.string(a:table).']["fields"]')
      call self.loadFieldsOfTables([a:table])
    endif
    return self["schema"]["tables"][a:table]['fields']
  endfunction

  function! conn.query(sql)
    try
      return vim_addon_sql#System(self['cmd']+[self['database']],{'stdin-text': a:sql})
    catch /.*/
      call s:ShowError(v:exception)
    endtry
  endfun

  return conn
endfunction

" vim:fdm=marker
" firebird implementation {{{1
" conn must be {'database:'..', ['user':'..','password':.., 'cmd':'isql']}
function! vim_addon_sql#FirebirdConn(conn)
  let conn = a:conn
  let conn['executable'] = get(conn,'executable', s:c.isql)
  let conn['username'] = get(conn,'username','SYSDBA')
  let conn['password'] = get(conn,'password','masterkey')
  let conn['regex'] = {
    \ 'table' :'\%(`[^`]\+`\|[^ \t`]\+\)' 
    \ , 'table_from_match' :'^`\?\zs[^`]*\ze`\?$' 
    \ }
  if ! has_key(conn,'database')
    throw 'firebird connection requires key database!'
  endif

  if !has_key(conn,'cmd')
    let conn['cmd']=[conn.executable,'-u',conn['username'],'-p',conn['password']]
  endif

  fun! conn.extraCompletions()
    " TODO add firebird function names etc
    return []
  endf

  function conn.create()
    let command = "CREATE DATABASE '". self.database ."' page_size 8192\n"
	      \ ."user '". self.username ."' password '". self.password ."';"
    call vim_addon_sql#System([self['executable']],{'stdin-text': command.';;'})
  endfunction

  function! conn.invalidateSchema()
    let self['schema'] = {'tables' : {}}
  endfunction
  call conn['invalidateSchema']()

  function! conn.col(col, output)
    return vim_addon_sql#MapIf( split(a:output,"\n")
            \ , "Val =~ '^\\s*".a:col.": '", "matchstr(Val, ".string('^\s*'.a:col.': \zs.*').")")
  endfunction

  function! conn.tables()
    " no caching yet
    " TODO: handle spaces and quoting ?
    return split(self.query('show tables'),'[ \t\r\n]\+')
  endfun

  function! conn.loadFieldsOfTables(tables)
    for table in a:tables
      let fields = []
      let lines = split(self.query('show table '.table),"\n")
      for l in lines
	" : denotes trigger or constraints section
	if l =~ ':$' | break | endif
        call add(fields, matchstr( l, '^\zs\S*\ze') )
      endfor
      let self['schema']['tables'][table] = { 'fields' : fields }
    endfor
  endfunction

  function! conn.fields(table)
    if !exists('self["schema"]["tables"]['.string(a:table).']["fields"]')
      call self.loadFieldsOfTables([a:table])
    endif
    return self["schema"]["tables"][a:table]['fields']
  endfunction

  function! conn.query(sql)
    try
      return vim_addon_sql#System(self['cmd']+[self['database']],{'stdin-text': a:sql.';;'})
    catch /.*/
      call s:ShowError(v:exception)
    endtry
  endfun

  return conn
endfunction

"echo c.query('CREATE DATABASE')

" vim:fdm=marker
