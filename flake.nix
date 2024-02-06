{
  outputs = { self, nixpkgs }:
    let
      version = "0.3.6";
      chartVersion = "0.1.6";
      vendorSha256 = "sha256-e3AUY+qKnLEugLviQxTK1Dj6mIuo2oCu8pmjuLqrbio=";
      dockerPackageTag = "st8ed/opencost-exporter:${version}";

      src = with lib; builtins.path {
        name = "opencost-exporter-src";
        path = sources.cleanSourceWith rec {
          filter = name: type:
            let baseName = baseNameOf (toString name); in
              !(
                (baseName == ".github") ||
                (hasSuffix ".nix" baseName) ||
                (hasSuffix ".md" baseName) ||
                (hasPrefix "${src}/deployments" name)
              );
          src = lib.cleanSource ./.;
        };
      };

      src-chart = with lib; builtins.path {
        name = "opencost-exporter-chart-src";
        path = lib.cleanSource ./deployments/chart;
      };

      package = { go_1_17, buildGo117Module }: buildGo117Module {
        pname = "opencost-exporter";
        inherit version vendorSha256 src;

        ldflags =
          let
            t = "github.com/prometheus/common";
          in
          [
            "-s"
            "-X ${t}.Revision=unknown"
            "-X ${t}.Version=${version}"
            "-X ${t}.Branch=unknown"
            "-X ${t}.BuildUser=nix@nixpkgs"
            "-X ${t}.BuildDate=unknown"
            "-X ${t}.GoVersion=${lib.getVersion go_1_17}"
          ];

        preInstall = ''
          mkdir -p $out/share/opencost-exporter/queries
          cp $src/configs/queries/* $out/share/opencost-exporter/queries/
        '';

        meta = with lib; {
          homepage = "https://github.com/st8ed/opencost-exporter";
          license = licenses.asl20;
          platforms = platforms.unix;
        };
      };

      dockerPackage = { pkgs, opencost-exporter, dockerTools, cacert, skopeo, moreutils, runCommandNoCC }:
        let
          # We compress image layers so the digest
          # will be reproducible when pushing to registry
          buildCompressedImage = stream: runCommandNoCC "opencost-exporter-dockerImage"
            {
              buildInputs = [ skopeo moreutils ];
            } ''
            # Piping archive stream to skopeo isn't working correctly
            ${stream} > archive.tar

            skopeo --insecure-policy copy docker-archive:./archive.tar dir:$out \
              --format v2s2 \
              --dest-compress
          '';

        in
        buildCompressedImage (dockerTools.streamLayeredImage {
          name = "st8ed/opencost-exporter";
          tag = "${version}";

          contents = [
            opencost-exporter
          ];

          fakeRootCommands = ''
            install -dm750 -o 1000 -g 1000  \
              ./etc/opencost-exporter       \
              ./var/lib/opencost-exporter

            cp -r \
              ${opencost-exporter}/share/opencost-exporter/* \
              ./etc/opencost-exporter
          '';

          config = {
            Entrypoint = [ "/bin/opencost-exporter" ];
            Cmd = [ ];
            User = "1000:1000";
            WorkingDir = "/var/lib/opencost-exporter";

            Env = [
              "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
            ];

            ExposedPorts = {
              "9100/tcp" = { };
            };

            Volumes = {
              "/var/lib/opencost-exporter" = { };
            };
          };
        });

      helmChart = { pkgs, opencost-exporter-dockerImage, kubernetes-helm, jq, gnused }: pkgs.runCommand "opencost-exporter-chart-${chartVersion}.tgz"
        {
          src = src-chart;
          buildInputs = [ kubernetes-helm jq gnused ];
        } ''
        cp -r $src ./chart
        chmod -R a+w ./chart

        sed -i \
          -e 's/^version: 0\.0\.0$/version: ${chartVersion}/' \
          -e 's/^appVersion: "0\.0\.0"$/appVersion: "${version}"/' \
          ./chart/Chart.yaml

        digest="sha256:$(sha256sum "${opencost-exporter-dockerImage}/manifest.json" | cut -d' ' -f1)"
        echo "Digest: $digest"

        sed -i \
          -e 's|^image:.*$|image: "${dockerPackageTag}@'$digest'"|' \
          ./chart/values.yaml

        mkdir -p ./package
        helm package --destination ./package ./chart

        mv ./package/*.tgz $out
      '';

      inherit (nixpkgs) lib;
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = lib.genAttrs supportedSystems;
      nixpkgsFor = lib.genAttrs supportedSystems (system: import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      });

    in
    {
      overlay = pkgs: _: {
        opencost-exporter = pkgs.callPackage package { };
        opencost-exporter-dockerImage = pkgs.callPackage dockerPackage { };
        opencost-exporter-helmChart = pkgs.callPackage helmChart { };
      };

      defaultPackage = forAllSystems (system: nixpkgsFor."${system}".opencost-exporter);
      packages = forAllSystems (system: {
        package = nixpkgsFor."${system}".opencost-exporter;
        dockerImage = nixpkgsFor."${system}".opencost-exporter-dockerImage;
        helmChart = nixpkgsFor."${system}".opencost-exporter-helmChart;

        inherit src src-chart;
      });
    };
}
