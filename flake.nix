{
  description = "OpenAPI generator nix flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        version =
          let
            pomContent = builtins.readFile "${self}/pom.xml";
            versionMatch = builtins.match ".*<!-- RELEASE_VERSION -->[\n\t ]*<version>([^<]+)</version>[\n\t ]*<!-- /RELEASE_VERSION -->.*" pomContent;
          in
          if versionMatch != null then builtins.head versionMatch
          else throw "Could not parse version from pom.xml";

        openapi-generator-cli = pkgs.stdenv.mkDerivation rec {
          pname = "openapi-generator-cli";
          inherit version;

          src = self;

          nativeBuildInputs = with pkgs; [
            maven
            jdk11
            makeWrapper
            git
          ];

          buildPhase = ''
            export MAVEN_OPTS="-Dmaven.repo.local=$TMPDIR/.m2/repository"
            echo "${version}" > VERSION
            rm -rf .mvn || true
            mvn -pl modules/openapi-generator-cli -am clean package \
              -DskipTests \
              -Dspotbugs.skip=true \
              -Dcheckstyle.skip=true \
              -Dmaven.build.cache.enabled=false \
              -Ddevelocity.build-scan.enabled=false \
              -Dmaven.ext.class.path= \
              --no-transfer-progress
          '';

          installPhase = ''
            runHook preInstall
            CLI_JAR=$(find modules/openapi-generator-cli/target -name "openapi-generator-cli.jar" -type f)
            
            if [ ! -f "$CLI_JAR" ]; then
              echo "Error: Could not find openapi-generator-cli.jar"
              find modules/openapi-generator-cli/target -name "*.jar" -type f
              exit 1
            fi
            
            mkdir -p "$out/share/java"
            cp "$CLI_JAR" "$out/share/java/openapi-generator-cli-${version}.jar"
            
            mkdir -p "$out/bin"
            makeWrapper ${pkgs.jdk11}/bin/java $out/bin/openapi-generator-cli \
              --add-flags "-jar $out/share/java/openapi-generator-cli-${version}.jar"
            
            runHook postInstall
          '';

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Allows generation of API client libraries (SDK generation), server stubs and documentation automatically given an OpenAPI Spec";
            homepage = "https://github.com/OpenAPITools/openapi-generator";
            license = licenses.asl20;
            maintainers = with maintainers; [ ];
            mainProgram = "openapi-generator-cli";
            platforms = platforms.unix;
          };
        };

      in
      {
        packages = {
          openapi-generator-cli = openapi-generator-cli;
          default = openapi-generator-cli;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            jdk11
            maven
            git
          ];
        };

        apps = {
          openapi-generator-cli = {
            type = "app";
            program = "${openapi-generator-cli}/bin/openapi-generator-cli";
          };
          default = {
            type = "app";
            program = "${openapi-generator-cli}/bin/openapi-generator-cli";
          };
        };
      }
    );
}
