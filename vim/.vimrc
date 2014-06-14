" Read the file as UTF-8.
scriptencoding utf-8

set nocompatible

" Display a tree style listing view.
let g:netrw_liststyle=3

" Hide matching files in the listing view.
let g:netrw_list_hide='.*\.pyc$,.*\.swp$'

syntax on

set showmatch

" Load file changes automatically.
set autoread

" Save on blur.
au FocusLost * :silent! wall

" Return to command mode on blur.
au FocusLost * call feedkeys("\<C-\>\<C-n>")

" Add jj to exit back to normal mode.
inoremap jj <ESC>

" General
set autochdir " always switch to the current file directory
set backspace=indent,eol,start " allow backspacing over these
set iskeyword+=_,$,@,%,# " none of these are word dividers
set noerrorbells " don't make noise

" Vim UI
set cursorline " highlight current line
set incsearch " BUT do highlight as you type you search phrase
set list " display unprintable characters
set listchars=tab:>·,trail:·,extends:>,precedes:< " show tabs and trailing; works with 'list'
set number " turn on line numbers
set numberwidth=5 " We are good up to 99999 lines
set ruler " display the cursor position in the status
set scrolloff=3 " Keep X lines (top/bottom) before the horizontal window border
set showtabline=2 " always show tabbar
set title " Show the filename in the window's titlebar
set nowrap " Don't wrap long lines
set cmdheight=3 " Avoid 'Press ENTER or type command to continue'

" Search
set ignorecase " case insensitive by default
set smartcase " if there are caps, go case-sensitive
set hlsearch " highlight search
hi Search ctermbg=0 ctermfg=none

" Automatic Indentation
set autoindent " turn on automatic indentation (copy the indentation of the previous line)

set shiftround " round indent to a multiple of 'shiftwidth'; e.g. when at 3 spaces and tabbed go to 4, not 5
set expandtab " no real tabs
set tabstop=4 " number of spaces that a <Tab> in the file counts for
set shiftwidth=4 " number of spaces to use for each step of (auto)indent
set softtabstop=4 " number of spaces that a <Tab> counts for while performing editing operations

au WinLeave * set nocursorline
au WinEnter * set cursorline
set ic
set nopaste " 'set paste' messes with autoindent

" Change indent using arrow keys
nmap <Left> <<
nmap <Right> >>
vmap <Left> <gv
vmap <Right> >gv

"nmap <Up> kddpk
"nmap <Down> ddp
"vmap <Up> [egv
"vmap <Down> ]egv

" Execute macro q by pressing spacebar
nnoremap <Space> @q

" Move tabs left with Ctrl + Shift + Page Up and move tabs right with Ctrl +
" Shift + Page Down.
nnoremap <silent> <C-S-PageUp> :execute 'silent! tabmove ' . (tabpagenr()-2)<CR>
nnoremap <silent> <C-S-PageDown> :execute 'silent! tabmove ' . tabpagenr()<CR>

" Move tabs left with Alt + Left and move tabs right with Alt + Right for
" keyboards that don't have Page Up and Page Down keys.
nnoremap <silent> <A-Left> :execute 'silent! tabmove ' . (tabpagenr()-2)<CR>
nnoremap <silent> <A-Right> :execute 'silent! tabmove ' . tabpagenr()<CR>

" Remove trailing spaces on save for certain file types.
autocmd BufWritePre *.css :%s/\s\+$//e
autocmd BufWritePre *.html :%s/\s\+$//e
autocmd BufWritePre *.php :%s/\s\+$//e
autocmd BufWritePre *.scss :%s/\s\+$//e

highlight BadWhitespace ctermbg=red guibg=red

" JavaScript
autocmd BufRead,BufNewFile *.js set expandtab
autocmd BufRead,BufNewFile *.js set tabstop=4
autocmd BufRead,BufNewFile *.js set softtabstop=4
autocmd BufRead,BufNewFile *.js set shiftwidth=4
autocmd BufRead,BufNewFile *.js set autoindent
autocmd BufRead,BufNewFile *.js match BadWhitespace /^\t\+/
autocmd BufRead,BufNewFile *.js match BadWhitespace /\s\+$/
autocmd         BufNewFile *.js set fileformat=unix
autocmd BufRead,BufNewFile *.js let b:comment_leader = '//'
autocmd BufWritePre        *.js :%s/\s\+$//e

" Python, PEP-008
autocmd BufRead,BufNewFile *.py,*.pyw set expandtab
autocmd BufRead,BufNewFile *.py,*.pyw set textwidth=79
autocmd BufRead,BufNewFile *.py,*.pyw set tabstop=4
autocmd BufRead,BufNewFile *.py,*.pyw set softtabstop=4
autocmd BufRead,BufNewFile *.py,*.pyw set shiftwidth=4
autocmd BufRead,BufNewFile *.py,*.pyw set autoindent
autocmd BufRead,BufNewFile *.py,*.pyw match BadWhitespace /^\t\+/
autocmd BufRead,BufNewFile *.py,*.pyw match BadWhitespace /\s\+$/
autocmd         BufNewFile *.py,*.pyw set fileformat=unix
autocmd BufRead,BufNewFile *.py,*.pyw let b:comment_leader = '#'
autocmd BufWritePre        *.py,*.pyw :%s/\s\+$//e
autocmd BufWriteCmd        *.py,*.pyw call CheckPythonSyntax()

function CheckPythonSyntax()
  let tmpfile = tempname()
  silent execute "write! " . tmpfile

  let command = "python -c \"__import__('py_compile').compile(r'" . tmpfile . "')\""
  let output = system(command . " 2>&1")
  if output != ''
    let curfile = bufname("%")
    let output = substitute(output, fnameescape(tmpfile), fnameescape(curfile), "g")
    echo output
  else
    write
  endif

  call delete(tmpfile)
endfunction

" Move the directory for the backup file.
set backupdir=~/.vim/backup/

" Move the directory for the swap file.
set directory=~/.vim/swap/

if has("gui_running")
  colorscheme railscat
  set colorcolumn=121

  " Hide the tool bar.
  set guioptions-=T

  if has("gui_macvim")
    " MacVim Settings
    set guifont=Consolas:h16

    " Expand width in fullscreen.
    set fuoptions=maxvert,maxhorz
  elseif has("gui_gtk2")
    " gVim Settings
    set guifont=Consolas\ 12

    " Show a maximum number of characters in the tabs.
    set guitablabel=%-0.30t%M

    " Make gVim behave a bit more like MacVim.
    " Ctrl + w => Close Tab
    map <C-w> :q<cr>

    " Alt + Shift + ] => Next Tab
    map <A-}> gt

    " Alt + Shift + [ => Previous Tab
    map <A-{> gT

    " Ctrl + a = Select All
    map <C-a> <esc>gg<S-v>G

    " Ctrl + s = Save
    map <C-s> :w<cr>

    " Add copy, cut, and paste.
    vmap <C-c> "+yi
    vmap <C-x> "+c
    vmap <C-v> c<ESC>"+p
    imap <C-v> <C-r><C-o>+

    " Ctrl + Tab => Next Tab
    map <C-Tab> gt

    " Ctrl + Shift + Tab => Previous Tab
    map <C-S-Tab> gT
  endif
else
  " Close tabs with Ctrl + w.
  nnoremap <C-w> :q<CR>
endif

" Reload vimrc when changed.
augroup myvimrc
    au!
    au BufWritePost .vimrc so $MYVIMRC | if has('gui_running') | so $MYVIMRC | endif
augroup END
