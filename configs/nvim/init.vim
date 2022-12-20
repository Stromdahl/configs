 "TEST THIS! 
 " CENTER CURSORk
 "set scrolloff=99999
 nnoremap <C-U> 11kzz
 nnoremap <C-D> 11jzz
 nnoremap j jzz
 nnoremap k kzz
 nnoremap # #zz
 nnoremap * *zz
 nnoremap n nzz
 nnoremap N Nzz
 nnoremap gg ggzz
 nnoremap G Gzz
 nnoremap gj gjzz
 nnoremap gk gkzz
 " ===============================
 " toggle relative numbers
 :set number

 :augroup numbertoggle
 :  autocmd!
 :  autocmd BufEnter,FocusGained,InsertLeave,WinEnter * if &nu && mode() != "i" | setlocal relativenumber  | endif
 :  autocmd BufLeave,FocusLost,InsertEnter,WinLeave   * if &nu                  | setlocal norelativenumber | endif
 :augroup END

 set autoindent              " Indent newlines automatically
 set backupcopy=yes          " Do not write new inode when saving file
 set cindent                 " Indent c-style syntax automatically
 set clipboard+=unnamedplus  " Always use system clipboard for cut/copy
 set colorcolumn=100         " Color colorcolumn
 set cursorline              " Highlight the line the Cursor is on
 set expandtab               " Indent tabs as spaces
 set guifont=Hack:h10        " Font and size in GUI:s
 set hidden                  " Keep unsaved data and undo information when switching buffers
 set hlsearch                " Search results are highlighted
 set ignorecase              " Search is not case-sensitive
 set incsearch               " Search while typing
 set linebreak               " Break long lines by word-boundaries instead of in the middle of word
 set mouse=a                 " Mouse support
 set scrolloff=999            " Cursor centered-ish
 set shiftwidth=0            " Indent with cindent the same amount of characters as tabstop
 set shortmess-=S            " Display search hit count
 set showcmd                 " Show count of marked lines in bottom right
 set smartcase               " Search is case sensitive when searching for words with capital letters
 set softtabstop=-1          " Indent is removed with same amount of characters as tabstop
 set tabstop=2               " Indent with 2 spaces
 set termguicolors           " Enables truecolor support
 set updatetime=300          " Wait 300 milliseconds for saving swap files and cursorhold autocommand
 set wildmenu                " Better completion mode
 set wildmode=full           " Complete to first word
 syntax on                   " Syntax highlighting
" set signcolumn=number       " Add signs on top of number column
 
 autocmd FileType json syntax match Comment +\/\/.\+$+
 
 " Check if working file is updated when entering that buffer
 autocmd FocusGained,BufEnter * :silent! checktime
 
 " Clear the jumplist once vim starts
 autocmd VimEnter * clearjumps
 
 " Filetype specific indentation
 autocmd FileType rust setlocal tabstop=4
 autocmd FileType javascript setlocal tabstop=2
 autocmd FileType python setlocal tabstop=4 noexpandtab
 autocmd FileType yaml setlocal tabstop=2
 autocmd FileType html setlocal tabstop=2
 
 " Key map
 " ===============================
 " Map leader 
 let g:mapleader = "\<Space>"
 let g:maplocalleader = ','
 
 """ Witch Key
 nnoremap <silent> <leader> :WhichKey '<Space>'<CR>
 
 " Create map to add keys to
 let g:which_key_map = {}
 " Define a separator
 let g:which_key_sep = '→'
 " set timeoutlen=100
 
 nmap <leader>ex :Files expand('%:p')<CR>
 """ Keymap by Daniel Ohlsson 
 """ https://github.com/DOhlsson/configs/blob/master/nvim/init.vim
 
 " Remap s key as a delete without writing to cut register
 noremap s "_d
 noremap ss "_dd
 noremap S "_D
 
 " Remap x key so that it does not write to cut register
 noremap x "_x
 noremap X "_X
 
 " Remap Y key to act as all the other capital letters
 " Seriously, why is Y = yy when D = d$ and C = c$ ?!
 noremap Y y$
 
 " Use F12 to switch buffers
 nnoremap <silent> <F12> :bn<CR>
 nnoremap <silent> <S-F12> :bp<CR>
 
 " Move vertically by visual line
 nnoremap j gj
 nnoremap k gk
 
 " Use ctrl-k/ctrl-j as up/down
 map <c-k> <c-p>
 map <c-j> <c-n>
 map! <c-k> <c-p>
 map! <c-j> <c-n>
 
 " Disable arrow-keys, use hjkl instead
 noremap <Up> <NOP>
 noremap <Down> <NOP>
 noremap <Left> <NOP>
 noremap <Right> <NOP>
 inoremap <Up> <NOP>
 inoremap <Down> <NOP>
 inoremap <Left> <NOP>
 inoremap <Right> <NOP>
 
 " Disable PageUp/PageDown use ctrl-u/ctrl-d instead
 noremap <PageUp> <NOP>
 noremap <PageDown> <NOP>
 
 " Get highlighting group under cursor
 map <F10> :echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<'
       \ . synIDattr(synID(line("."),col("."),0),"name") . "> lo<"
       \ . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>
 
 " I do this often enough it requires its own keymap =P
 nmap <leader>ee :e ~/.dotfiles/nvim/init.vim<CR>
 nmap <leader>es :source ~/.config/nvim/init.vim<CR>
 nmap <leader>ep :pwd <CR>
 " e is for editor config
 let g:which_key_map.e = {
       \ 'name' : '+Editor' ,
       \ 'e' : [':e ~/.config/nvim/init.vim'     , 'config'],
       \ 's' : [':source ~/.config/nvim/init.vim'     , 'reload'],
       \ 'p' : [':pwd'     , 'pwd'],
       \ } 
 
 "
 " Plugins
 " ===============================
 
 call plug#begin()
 
 " Prettiness 
 Plug 'gruvbox-community/gruvbox'
 Plug 'vim-airline/vim-airline'
 
 " Utils
 Plug 'airblade/vim-rooter'   
 Plug 'liuchengxu/vim-which-key'
 Plug 'luochen1990/rainbow'
 Plug 'tpope/vim-fugitive'   
 
 " File management
 Plug 'jeetsukumaran/vim-indentwise'
 Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
 Plug 'junegunn/fzf.vim'
 Plug 'preservim/nerdtree'
 
 " Language
 Plug 'neoclide/coc.nvim', {'branch': 'release'} 
 Plug 'pangloss/vim-javascript'      
 Plug 'rust-lang/rust.vim'           
 
 call plug#end()
 
 " Plugins Key Map
 " ===============================
 
" === Fzf
nmap <leader>s/ :History/<CR>
nmap <leader>s; :Commands<CR>
nmap <leader>sa :Ag<CR>
nmap <leader>sb :BLines<CR>
nmap <leader>sB :Buffers<CR>
nmap <leader>sC :BCommits<CR>
nmap <leader>sc :Commits<CR>
nmap <leader>sF :Files %:p:h<CR>
nmap <leader>sf :Files<CR>
nmap <leader>sg :GFiles<CR>
nmap <leader>sG :GFiles?<CR>
nmap <leader>sH :History:<CR>
nmap <leader>sh :History<CR>
nmap <leader>sl :Lines<CR>
nmap <leader>sM :Maps<CR>
nmap <leader>sm :Marks<CR>
nmap <leader>sp :Helptags<CR>
nmap <leader>sP :Tags<CR>
nmap <leader>sS :Colors<CR>
nmap <leader>ss :Snippets<CR>
nmap <leader>sT :Btags<CR>
nmap <leader>st :Rg<CR>
nmap <leader>sw :Windows<CR>
nmap <leader>sy :Filetypes<CR>
nmap <leader>sz :FZF<CR>

" s is for search
let g:which_key_map.s = {
      \ 'name' : '+search' ,
      \ '/' : [':History/'     , 'history'],
      \ ';' : [':Commands'     , 'commands'],
      \ 'a' : [':Ag'           , 'text Ag'],
      \ 'b' : [':BLines'       , 'current buffer'],
      \ 'B' : [':Buffers'      , 'open buffers'],
      \ 'C' : [':BCommits'     , 'buffer commits'],
      \ 'c' : [':Commits'      , 'commits'],
      \ 'f' : [':Files'        , 'files'],
      \ 'g' : [':GFiles'       , 'git files'],
      \ 'G' : [':GFiles?'      , 'modified git files'],
      \ 'h' : [':History'      , 'file history'],
      \ 'H' : [':History:'     , 'command history'],
      \ 'l' : [':Lines'        , 'lines'] ,
      \ 'M' : [':Maps'         , 'normal maps'] ,
      \ 'm' : [':Marks'        , 'marks'] ,
      \ 'p' : [':Helptags'     , 'help tags'] ,
      \ 'P' : [':Tags'         , 'project tags'],
      \ 'S' : [':Colors'       , 'color schemes'],
      \ 's' : [':Snippets'     , 'snippets'],
      \ 'T' : [':BTags'        , 'buffer tags'],
      \ 't' : [':Rg'           , 'text Rg'],
      \ 'w' : [':Windows'      , 'search windows'],
      \ 'y' : [':Filetypes'    , 'file types'],
      \ 'z' : [':FZF'          , 'FZF'],
      \ }

" b is for buffer
nmap <leader>q :bd<CR>
nmap <leader>Q :bd!<CR>

" g is for GIT
nmap <leader>gb :Git blame<CR>
nmap <leader>gg :Git<CR>
nmap <leader>gd :Gvdiffsplit<CR>

" t is for file tree
nmap <leader>ft :NERDTreeToggle<CR>
nmap <leader>ff :NERDTreeFind<CR>
nmap <leader>fl :NERDTreeFocus<CR>

nmap <leader>w :w<CR>
" nmap <leader>Q :q<CR>

map [- <Plug>(IndentWisePreviousLesserIndent)
map [= <Plug>(IndentWisePreviousEqualIndent)
map [+ <Plug>(IndentWisePreviousGreaterIndent)
map ]- <Plug>(IndentWiseNextLesserIndent)
map ]= <Plug>(IndentWiseNextEqualIndent)
map ]+ <Plug>(IndentWiseNextGreaterIndent)
map [_ <Plug>(IndentWisePreviousAbsoluteIndent)
map ]_ <Plug>(IndentWiseNextAbsoluteIndent)
map [% <Plug>(IndentWiseBlockScopeBoundaryBegin)
map ]% <Plug>(IndentWiseBlockScopeBoundaryEnd)

""" Rust
let g:rustfmt_autosave = 1
let g:rustfmt_emit_fiels = 1
let g:rustfmt_fail_silently = 0
let g:rust_clip_command = 'xci'

""" NERDTree
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>

" fugitive.vim
" g is for GIT
nmap <leader>gb :Git blame<CR>
nmap <leader>gg :Git<CR>
nmap <leader>gd :Gvdiffsplit<CR>

""" CoC 

" Start Coc
nmap <leader>cs :CocStart<CR>    

" Get all diagnostics of current buffer in location list
nmap <leader>cd :CocDiagnostics<CR>

" Format current buffer
nmap <leader>cf :call CocAction('format')<CR>

" Get suggestions to fix warnings and errors on cursor or selection
nmap <leader>ca <Plug>(coc-codeaction-cursor)
xmap <leader>ca <Plug>(coc-codeaction-selected)

" Rename symbol under cursor
nmap <leader>cr <Plug>(coc-rename)

" Various jump-to commands
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gD <Plug>(coc-declaration)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
" Use `[g` and `]g` to navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  elseif (coc#rpc#ready())
    call CocActionAsync('doHover')
  else
    execute '!' . &keywordprg . " " . expand('<cword>')
  endif
endfunction

" Use tab for trigger completion with characters ahead and navigate
   " inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
    inoremap <silent><expr> <C-x><C-z> coc#pum#visible() ? coc#pum#stop() : "\<C-x>\<C-z>"
    " remap for complete to use tab and <cr>
    inoremap <silent><expr> <TAB>
        \ coc#pum#visible() ? coc#pum#next(1):
        \ <SID>check_back_space() ? "\<Tab>" :
        \ coc#refresh()
    inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
    inoremap <silent><expr> <c-space> coc#refresh()

    hi CocSearch ctermfg=12 guifg=#18A3FF
    hi CocMenuSel ctermbg=109 guibg=#13354A

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" End completion with CR in insert mode
" Highlight the symbol and its references when holding the cursor
autocmd CursorHold * silent call CocActionAsync('highlight')


" Plugin config 
" ===============================
""" vim-rooter
let g:rooter_patterns = ['.git']

""" Airline
let g:airline_powerline_fonts = 1

""" Rainbow (Parentheses Improved)
let g:rainbow_active = 1 "set to 0 if you want to enable it later via :RainbowToggle

""" NERDTree
" quit NERDTree on file open
let g:NERDTreeQuitOnOpen = 1

" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" Close the tab if NERDTree is the only window remaining in it.
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

""" Gruvbox colorscheme
let g:gruvbox_contrast_light = 'hard'
let g:gruvbox_contrast_dark = 'hard'
let g:gruvbox_italic = 1
set background=dark
colorscheme gruvbox
