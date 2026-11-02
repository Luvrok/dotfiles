-- only for indent/nix.vim: nvim ships no nix indent, so smartindent kicked in
-- and threw every new "# comment" line to column 0. highlighting stays treesitter
return {
	"LnL7/vim-nix",
	ft = "nix",
}
