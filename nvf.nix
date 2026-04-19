{
  vim = {
    theme = {
      enable = true;
      name = "gruvbox";
      style = "dark";
    };
    options = {
      tabstop = 2;
      shiftwidth = 2;
    };
    statusline.lualine.enable = true;
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
    binds.whichKey.enable = true;
    utility = {
      motion.hop.enable = true;
      yazi-nvim.enable = true;
    };

    lsp.enable = true;
    languages = {
      # enableTreesitter = true;

      nix.enable = true;
    };
  };
}
