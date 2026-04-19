{ pkgs, config, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "alfred@omj.dk";
    certs."shlambert.top" = {
      group = config.services.caddy.group;

      domain = "shlambert.top";
      extraDomainNames = [ "*.shlambert.top" ];
      dnsProvider = "spaceship";
      dnsResolver = "1.1.1.1";
      dnsPropagationCheck = true;
      environmentFile = config.age.secrets.spaceship.path;
    };
  };
}
