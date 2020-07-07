execute pathogen#infect()

"" Handle attention warning after a crash about the swp file
set shortmess+=A

"""""""" Vim
"syntax on
filetype plugin indent on

"enabled solarized colours
colorscheme solarized

"set colorscheme based on time
"let hour = strftime("%H")
"if 8 <= hour && hour < 17
"  set background=light
"else
"  set background=dark
"endif

"set colorscheme based on iterm profile
let iterm_profile = $ITERM_PROFILE

if iterm_profile == "Dark"
  set background=dark
else
  set background=light        " Set solarized background color
endif

" size of hard tabstop
set tabstop=2
" size of an 'indent'
set shiftwidth=2
" make "tab" insert indents instead of tabs at the beginning of a line
set smarttab

" always uses spaces instead of tab characters
set expandtab

" Enable folding based on syntax
set foldmethod=syntax
autocmd BufNewFile,BufReadPost *.coffee setl foldmethod=indent nofoldenable

" unfold all files on load
au BufRead * normal zR

" always show line numbers
set number

" always show 120 column
set colorcolumn=120
" set the column at the cursor
au WinLeave * set nocursorline nocursorcolumn
au WinEnter * set cursorline cursorcolumn
" set a column at the cursor
" set cursorline cursorcolumn

" show trailing whitespace: using a . as space
set list
set listchars=trail:.

"always show tab bar
set showtabline=2

"" Wen creating a vsplit, make it appear to the right of the current split
set splitright

" Keep 5 lines below and above the cursor
set scrolloff=5

"enable standard highlighting for .md Markdown files
au BufRead,BufNewFile *.md set filetype=markdown

"""""""" Vim-Airline
" use powerline fonts
" let g:airline_powerline_fonts = 1

" always show powerline
" let g:airline#extensions#tabline#enabled = 1
" always show powerline
" set laststatus=2

"""""""" Supertab
" scroll supertab completion list from top to bottom
let g:SuperTabDefaultCompletionType = "<c-n>"

"""""""" CtrlP
set runtimepath^=~/.vim/bundle/ctrlp.vim

"""""" Set up automatic adding of closing parenthesis
inoremap ( ()<Esc>i
inoremap { {}<Esc>i
inoremap [ []<Esc>i
inoremap ' ''<Esc>i
inoremap " ""<Esc>i
