(
  (preproc_call
    directive: (_) @_dir_1
    argument: (_) @_arg_begin
    (#match? @_arg_begin "^region.*$")
    (#eq? @_dir_1 "#pragma")
    ) @_beg_region
  (_)*  @inner
  (preproc_call
    directive: (_) @_dir_2
    argument: (_) @_arg_end
    (#match? @_arg_end "^endregion.*$")
    (#eq? @_dir_2 "#pragma")
    ) @_end_region
  (#make-range! "fold" @_beg_region @_end_region)
)
