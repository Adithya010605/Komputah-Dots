-- LazyVim's markdown extra (lazyvim.json) already adds render-markdown.nvim,
-- markdown-preview.nvim and marksman. Here we just enable Obsidian-style
-- checkbox rendering, which the extra ships disabled by default.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      checkbox = {
        enabled = true,
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰱒 " },
      },
    },
  },

  -- markdownlint-cli2 is too strict for freeform notes (flags every trailing
  -- space, hard tab, missing blank line around headings/lists). Turn off its
  -- diagnostics; formatting-on-save (prettier) still applies.
  -- (opts must be a function: lazy.nvim deep-merges opts tables, so a plain
  -- `{}` here would not clear the list the markdown extra already set.)
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft.markdown = {}
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft["markdown"] = { "prettier" }
      opts.formatters_by_ft["markdown.mdx"] = { "prettier" }
    end,
  },
}
