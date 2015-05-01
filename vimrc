execute pathogen#infect()

"" Handle attention warning after a crash about the swp file
set shortmess+=A

"""""""" Vim
"syntax on
filetype plugin indent on

"enabled solarized colours
"set colorscheme based on time
let hour = strftime("%H")
if 8 <= hour && hour < 17
  set background=light
else
  set background=dark
endif

colorscheme solarized

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

" always show 80 column
set colorcolumn=80

" show trailing whitespace: using a . as space
set list
set listchars=trail:.

" set Source Code Pro as default font
set guifont=Source\ Code\ Pro\ for\ Powerline:h11

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
let g:airline_powerline_fonts = 1

" always show powerline
let g:airline#extensions#tabline#enabled = 1
" always show powerline
set laststatus=2

"""""""" Supertab
" scroll supertab completion list from top to bottom
let g:SuperTabDefaultCompletionType = "<c-n>"

"""""""" CtrlP
set runtimepath^=~/.vim/bundle/ctrlp.vim

"""""""" Powerline
"python from powerline.vim import setup as powerline_setup
"python powerline_setup()
"python del powerline_setup
source /usr/local/lib/python2.7/site-packages/powerline/bindings/vim/plugin/powerline.vim
set laststatus=2
inoremap { {}<Esc>i
inoremap ' ''<Esc>i
inoremap " ""<Esc>i
