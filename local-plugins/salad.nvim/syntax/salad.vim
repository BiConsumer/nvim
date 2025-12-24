if exists("b:current_syntax")
  finish
endif

syn match saladId /^\/\d* / conceal

let b:current_syntax = "salad"

