call vim_addon_completion#RegisterCompletionFunc({
      \ 'description' : 'simple SQL completion. See autoload/vim_addon_sql.vim to learn about how to connect',
      \ 'completeopt' : 'preview,menu,menuone',
      \ 'scope' : 'sql',
      \ 'func': 'vim_addon_sql#Complete'
      \ })
