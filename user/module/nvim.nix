{
  lib,
  pkgs,
  ...
}:
{
  config = {
    programs.nvf = {
      enable = true;
      settings = {
        vim = {
          viAlias = true;
          vimAlias = true;
          keymaps = [
            {
              desc = "LSP Hover";
              key = "<K>";
              mode = "n";
              action = "vim.lsp.buf.hover";
              lua = true;
            }
            {
              desc = "LSP Go To Definition";
              key = "<gd>";
              mode = "n";
              action = "vim.lsp.buf.definition";
              lua = true;
            }
            {
              desc = "LSP Code Actions";
              key = "<leader>ca";
              mode = [ "n" "v" ];
              action = "vim.lsp.buf.code_action";
              lua = true;
            }
            {
              desc = "LSP Format";
              key = "<leader>gf";
              mode = "n";
              action = "vim.lsp.buf.format";
              lua = true;
            }
          ];
          opts = {
            expandtab = true;
            list = true;
            listchars = "tab:» ,lead:•,trail:•";
            relativenumber = true;
            shiftwidth = 2;
            softtabstop = 2;
            tabstop = 2;
          };

          /*
          autocomplete.nvim-cmp = {
            enable = true;
            format = lib.mkLuaInline ''
              function(args)
                require('luasnip').lsp_expand(args.body)
              end
            '';
            sources = {
              nvim_lsp = null;
              luasnip = null;
              path = "[Path]";
              buffer = "[Buffer]";
            };
          };
          */

          autocomplete.blink-cmp.enable = true;
          #snippets.luasnip = {
          #  enable = true;
          #  providers = [ "friendly-snippets" ];
          #};
          languages = {
            enableFormat = true;
            enableTreesitter = true;
            bash.enable = true;
            nix = {
              enable = true;
              format.type = [ "nixfmt-rs" ];
            };
            lua.enable = true;
            typescript.enable = true;
          };
          lsp = {
            enable = true;
            inlayHints.enable = true;
            lspconfig.enable = true;
            trouble.enable = true;
          };
          statusline.lualine.enable = true;
          #filetree.neo-tree.enable = true;
          /*
          telescope = {
            enable = true;
            mappings = {
              findFiles = "<C-p>";
              liveGrep = "<leader>fg";
            };
          };
          */
          treesitter = {
            enable = true;
            highlight.enable = true;
            indent.enable = true;
          };
          visuals.nvim-web-devicons.enable = true;
        };
      };
    };
  };
}
