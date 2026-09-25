let
  pins = import ./npins;
  pkgs = import pins.nixpkgs-unstable { };
  inherit (pkgs) lib;

  # Kept out of the repo on purpose: the deploy config is part of the build,
  # not something to hand-edit next to the cards.
  wrangler = pkgs.writeText "wrangler.jsonc" (
    builtins.toJSON {
      name = "dashboard";
      compatibility_date = "2026-09-25";
      # no "main": assets-only, so requests never start an isolate
      assets = {
        directory = "./public";
        not_found_handling = "404-page";
      };
      routes = [
        {
          pattern = "dashboard.toniogela.dev";
          custom_domain = true;
        }
      ];
    }
  );

  # Applied by Cloudflare to every static asset response. HSTS is not here:
  # the zone-level setting already sends it, on redirects too.
  #
  # Everything the page loads is first-party, so 'self' everywhere is enough.
  headers = pkgs.writeText "_headers" ''
    /*
      Content-Security-Policy: default-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'self'
      X-Content-Type-Options: nosniff
      Referrer-Policy: strict-origin-when-cross-origin
      X-Frame-Options: SAMEORIGIN
      Permissions-Policy: accelerometer=(), camera=(), geolocation=(), gyroscope=(), microphone=(), payment=(), usb=()
  '';
in
pkgs.stdenvNoCC.mkDerivation {
  name = "dashboard";
  # only what zola reads, so README/CI edits don't rebuild the site
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./config.toml
      ./content
      ./sass
      ./static
      ./templates
    ];
  };
  nativeBuildInputs = [ pkgs.zola ];
  buildPhase = "zola build --output-dir public";
  installPhase = ''
    mkdir -p $out
    cp -r public $out/public
    cp ${headers} $out/public/_headers
    cp ${wrangler} $out/wrangler.jsonc
  '';
}
