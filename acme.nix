{ pkgs, config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "alfred@omj.dk";
    # The base domain (see ./registry.nix). Its DNS is at Simply.com, so the
    # TXT record for the challenge goes in through their API: simply.age is an
    # environment file with SIMPLY_ACCOUNT_NAME (the account number, S123456)
    # and SIMPLY_API_KEY, both from Simply.com's control panel under Account ->
    # API.
    certs."zam.dk" = {
      group = config.services.caddy.group;

      domain = "zam.dk";
      extraDomainNames = [ "*.zam.dk" ];
      dnsProvider = "simply";
      dnsResolver = "1.1.1.1";
      dnsPropagationCheck = true;
      environmentFile = config.age.secrets.simply.path;
    };

    # The old base domain, still served during the move: every
    # service answers at its old name too, and headscale and Hyggr still live
    # here (see oldDomain in ./registry.nix).
    certs."shlambert.top" = {
      group = config.services.caddy.group;

      domain = "shlambert.top";
      extraDomainNames = [ "*.shlambert.top" ];
      dnsProvider = "spaceship";
      dnsResolver = "1.1.1.1";
      dnsPropagationCheck = true;
      environmentFile = config.age.secrets.spaceship.path;
    };

    certs."zehra.click" = {
      group = config.services.caddy.group;

      domain = "zehra.click";
      extraDomainNames = [ "*.zehra.click" ];
      dnsProvider = "spaceship";
      dnsResolver = "1.1.1.1";
      dnsPropagationCheck = true;
      environmentFile = config.age.secrets.spaceship.path;
    };
  };
}
