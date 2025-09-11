return {
  "saghen/blink.cmp",
  -- optional: provides snippets for the snippet source
  dependencies = { "rafamadriz/friendly-snippets" },

  -- use a release tag to download pre-built binaries
  version = "1.*",

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    -- 'default' (recommended) for mappings similar to built-in completions (C-y to accept)
    -- 'super-tab' for mappings similar to vscode (tab to accept)
    -- 'enter' for enter to accept
    -- 'none' for no mappings
    --
    -- All presets have the following mappings:
    -- C-space: Open menu or open docs if already open
    -- C-n/C-p or Up/Down: Select next/previous item
    -- C-e: Hide menu
    -- C-k: Toggle signature help (if signature.enabled = true)
    --
    -- See :h blink-cmp-config-keymap for defining your own keymap
    keymap = {
      preset = "default",
      ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
    },

    appearance = {
      -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = "normal",
    },

    -- (Default) Only show the documentation popup when manually triggered
    completion = {
      documentation = {
        auto_show = true,
        window = {
          border = "rounded",
        },
      },
      menu = {
        border = "rounded",
        draw = { gap = 2 },
      },
      list = {
        selection = {
          preselect = function(ctx)
            return not require("blink.cmp").snippet_active({ direction = 1 })
          end,
        },
      },
    },
    -- display signature while completing
    signature = { enabled = true },
  },
}
