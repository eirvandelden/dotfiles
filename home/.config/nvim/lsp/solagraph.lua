return {
  cmd = { "solargraph", "stdio" },
  filetypes = { "ruby" },
  init_options = {
    formatting = true,
  },
  -- root_dir = function(startpath)
  -- return M.search_ancestors(startpath, matcher)
  -- end
  settings = {
    solargraph = {
      autoformat = true,
      diagnostics = true,
      formatting = true,
    },
  },
}
