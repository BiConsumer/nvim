return {
	"rmagatti/auto-session",
	lazy = false,
	opts = {
		suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },

		post_save_cmds = {
			"ScopeSaveState"
		},

		post_restore_cmds = {
			"ScopeLoadState"
		}
	}
}
