return {
  cmd = { "steep", "langserver" },
  filetypes = { "ruby" },
  -- Start only in a project that has a Steepfile, not in every Ruby project.
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, { "Steepfile" })
    if root then
      on_dir(root)
    end
  end,
}
