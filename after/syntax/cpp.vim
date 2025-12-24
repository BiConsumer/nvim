syn match cppPointer "\*[[:space:]]*"
syn match cppReference "&[[:space:]]*"
syn match cppScope "::"
syn match cppDocComment "///.*$" containedin=.*Comment
syn match cppAttribute "\[\[[^][]\+\]\]"
