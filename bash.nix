{
  programs.bash.shellAliases = {
    lg = "lazygit";
    ageGen = "EDITOR=nvim nix run github:ryantm/agenix -- -e";
    gs = "git status";
    ga = "git add";
    gc = "git commit -m";
    conf = "cd /etc/nixos";
  };
}
