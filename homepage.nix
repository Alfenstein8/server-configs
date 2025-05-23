{
  services.homepage-dashboard = {
    enable = true;
    allowedHosts = "home.shlambert.top";
    services = [
      {
        "Hosting" = [
	  {
            "Immich" = {
              discription = "Image hosting";
	      href = "http://immich.shlambert.top";
	    };
	  }
	  {
            "Paperless" = {
              discription = "Document hosting";
	      href = "http://paper.shlambert.top";
	    };
	  }
	  {
            "Radicale" = {
              discription = "calendar and contacts hosting";
	      href = "http://radicale.shlambert.top";
	    };
	  }
	];
	"Monitoring" = [
	  {
            "uptime kuma" = {
              discription = "Service uptime";
	      href = "http://uptime.shlambert.top";
	    };
	  }
	];
      }
    ];
  };
}
