" Install plugins by running :PluginInstall inside vim.
" Begin Vundle
set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'vim-syntastic/syntastic'
Plugin 'scrooloose/nerdtree'
Plugin 'tpope/vim-surround'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'vim-airline/vim-airline'

" Install:
"   $ cd ~/.vim/bundle/youcompleteme
"   $ git submodule update --init --recursive (Fixes: "error: unrecognized arguments: --js-completer")
"   $ ./install.py --js-completer
Plugin 'valloric/youcompleteme'

Plugin 'google/vim-searchindex'
call vundle#end()
filetype plugin indent on
" End Vundle

" Begin syntastic recommended settings
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_loc_list_height=3
" End syntastic

" Custom Syntastic
let g:syntastic_php_phpcs_args='--standard=PSR2'
"let g:syntastic_php_phpcs_args='--standard=~/.config/phpcs/ruleset.xml'
" End Custom Syntastic

set laststatus=2

" Show hidden files in nerdtree.
let g:NERDTreeShowHidden=1

" Open CtrlP in new tabs.
let g:ctrlp_prompt_mappings = {
    \ 'AcceptSelection("e")': ['<c-t>'],
    \ 'AcceptSelection("t")': ['<cr>', '<2-LeftMouse>'],
    \ }

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

" General
set autochdir " always switch to the current file directory
set backspace=indent,eol,start " allow backspacing over these
set iskeyword+=_,$,@,%,# " none of these are word dividers
set noerrorbells " don't make noise
set tabpagemax=100 " allow opening more tabs
execute "set colorcolumn=" . join(range(121,255), ',')
set redrawtime=10000

" Vim UI
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
set textwidth=80 " Set textwidth to wrap. e.g. when using "selection" + gq
set cmdheight=3 " Avoid 'Press ENTER or type command to continue'

" Search
set ignorecase " case insensitive by default
set smartcase " if there are caps, go case-sensitive
set hlsearch " highlight search
highlight Search ctermbg=0 ctermfg=none

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

" Open tabs with just :T and :t instead of :tabe :tabedit :tabnew. :T filename
" works with tab completion.
command! -nargs=* -complete=file T tabnew <args>
nnoremap :t<CR>    :tabnew<CR>
xnoremap :t<CR>    :tabnew<CR>
nnoremap :t<Space> :tabnew<Space>
xnoremap :t<Space> :tabnew<Space>

" Move tabs left with Ctrl + Shift + Page Up and move tabs right with Ctrl +
" Shift + Page Down.
nnoremap <silent> <C-S-PageUp> :execute 'silent! tabmove ' . (tabpagenr()-2)<CR>
nnoremap <silent> <C-S-PageDown> :execute 'silent! tabmove ' . tabpagenr()<CR>

" Move tabs left with Alt + Left and move tabs right with Alt + Right for
" keyboards that don't have Page Up and Page Down keys.
nnoremap <silent> <A-Left> :execute 'silent! tabmove ' . (tabpagenr()-2)<CR>
nnoremap <silent> <A-Right> :execute 'silent! tabmove ' . tabpagenr()<CR>

" Move tabs left with Ctrl + h and move tabs right with Ctrl + l.
map <silent> <C-H> :execute 'tabmove' tabpagenr() - 2 <CR>
map <silent> <C-L> :execute 'tabmove' tabpagenr() <CR>

" Navigate between splits with ctrl + h, ctrl + j, ctrl + k, ctrl + l.
nnoremap <C-H> <C-W><C-H>
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>

" Open new split panes to right and bottom.
set splitbelow
set splitright

" Remove trailing spaces on save for certain file types.
autocmd BufWritePre *.css :%s/\s\+$//e
autocmd BufWritePre *.html :%s/\s\+$//e
autocmd BufWritePre *.json :%s/\s\+$//e
autocmd BufWritePre *.php :%s/\s\+$//e
autocmd BufWritePre *.py :%s/\s\+$//e
autocmd BufWritePre *.scss :%s/\s\+$//e
autocmd BufWritePre *.sh :%s/\s\+$//e
autocmd BufWritePre *.txt :%s/\s\+$//e

highlight BadWhitespace ctermbg=red guibg=red

" Shell
autocmd BufRead,BufNewFile *.sh set tabstop=4
autocmd BufRead,BufNewFile *.sh set softtabstop=4
autocmd BufRead,BufNewFile *.sh set shiftwidth=4

" Sass
autocmd BufRead,BufNewFile *.scss set tabstop=4
autocmd BufRead,BufNewFile *.scss set softtabstop=4
autocmd BufRead,BufNewFile *.scss set shiftwidth=4

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

" PHP
autocmd BufRead,BufNewFile *.php set tabstop=4
autocmd BufRead,BufNewFile *.php set softtabstop=4
autocmd BufRead,BufNewFile *.php set shiftwidth=4
autocmd BufRead,BufNewFile *.php set textwidth=120

" Python, PEP-008 except textwidth.
autocmd BufRead,BufNewFile *.py,*.pyw set expandtab
autocmd BufRead,BufNewFile *.py,*.pyw set textwidth=120
autocmd BufRead,BufNewFile *.py,*.pyw set tabstop=4
autocmd BufRead,BufNewFile *.py,*.pyw set softtabstop=4
autocmd BufRead,BufNewFile *.py,*.pyw set shiftwidth=4
autocmd BufRead,BufNewFile *.py,*.pyw set autoindent
autocmd BufRead,BufNewFile *.py,*.pyw match BadWhitespace /^\t\+/
autocmd BufRead,BufNewFile *.py,*.pyw match BadWhitespace /\s\+$/
autocmd         BufNewFile *.py,*.pyw set fileformat=unix
autocmd BufRead,BufNewFile *.py,*.pyw let b:comment_leader = '#'

" YAML
autocmd BufRead,BufNewFile *.yaml,*.yml set tabstop=2
autocmd BufRead,BufNewFile *.yaml,*.yml set softtabstop=2
autocmd BufRead,BufNewFile *.yaml,*.yml set shiftwidth=2

function! <SID>PythonSave()
    " Check python syntax.
    let tmpfile = tempname()
    silent execute "write! " . tmpfile
    let command = "python3 -m py_compile '" . tmpfile . "'"
    let output = system(command . " 2>&1")
    if output != ''
        let curfile = bufname("%")
        let output = substitute(output, fnameescape(tmpfile), fnameescape(curfile), "g")
        echo output
    endif
    call delete(tmpfile)

    " Save cursor position.
    let l = line(".")
    let c = col(".")

    " Strip trailing whitespace.
    %s/\s\+$//e

    " Restore cursor position.
    call cursor(l, c)
endfunction

autocmd FileType python autocmd BufWritePre <buffer> :call <SID>PythonSave()

" Move the directory for the backup file.
set backupdir=~/.vim/backup/

" Move the directory for the swap file.
set directory=~/.vim/swap/

if has("gui_running")
  colorscheme railscat
  highlight ColorColumn guibg=#424242

  " Hide the tool bar.
  set guioptions-=T

  if has("gui_macvim")
    " MacVim Settings
    set guifont=Roboto\ Mono:h16,Consolas:h16,Menlo:h16

    " Expand width in fullscreen.
    set fuoptions=maxvert,maxhorz

    " Resize splits when resizing window.
    autocmd VimResized * wincmd =
  elseif has("gui_gtk2")
    " gVim Settings
    set guifont=Ubuntu\ Mono\ 12

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
  highlight ColorColumn ctermbg=0

  " Close tabs with Ctrl + w.
  nnoremap <C-w> :q<CR>
endif

" Reload vimrc when changed.
augroup myvimrc
    au!
    au BufWritePost .vimrc so $MYVIMRC | if has('gui_running') | so $MYVIMRC | endif
augroup END
