{
  description = ''An extended "Standard Library" for Rocq'';

  inputs = {
    rocq-nix.url = "github:mbrcknl/rocq-nix";

    stdpp.url = "gitlab:iris/stdpp?host=gitlab.mpi-sws.org";
    stdpp.flake = false;
  };

  outputs =
    inputs:
    inputs.rocq-nix.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      {
        treefmt.programs.nixfmt.enable = true;

        rocq.versions = [
          "9.1.0"
          "9.0.1"
        ];

        rocq.eachVersion =
          {
            pkgs,
            rocq,
            ...
          }:
          let
            inherit (rocq) coqPackages rocqPackages;
            inherit (coqPackages) coq;
            inherit (rocqPackages) stdlib;

            mkIrisProjDerivation = lib.makeOverridable (
              args@{ subdir, ... }:
              let
                coqProject = "_CoqProject.${subdir}";
                makefile = "Makefile.package.${subdir}";

                meta = {
                  inherit (coq.meta) platforms;
                  homepage = "https://iris-project.org/";
                  license = lib.licenses.bsd3;
                };

                defaultArgs = {
                  name = "rocq${coq.coq-version}-" + lib.replaceStrings [ "_" ] [ "-" ] subdir;

                  buildInputs = [ coq ] ++ args.buildInputs or [ ];
                  meta = meta // args.meta or { };

                  COQLIBINSTALL = "$(out)/lib/coq/${coq.coq-version}/user-contrib";
                  enableParallelBuilding = true;
                  inherit makefile;

                  configurePhase = ''
                    (
                      exec > "${coqProject}"
                      grep "^${subdir} " config/paths | sed "s/^/-Q /"
                      grep "^[^#]" config/flags | sed "s/^/-arg /"
                      grep "^${subdir}/" config/source-list
                    )

                    "coq_makefile" -f "${coqProject}" -o "${makefile}"
                  '';
                };

                passthruArgs = lib.removeAttrs args [
                  "buildInputs"
                  "meta"
                  "subdir"
                ];
              in
              pkgs.stdenv.mkDerivation (defaultArgs // passthruArgs)
            );

            mkIrisTestDerivation = lib.makeOverridable (
              args@{ name, paths, ... }:
              let
                coqProject = "_CoqProject";
                makefile = "Makefile.coq";

                emitPath = physical: logical: ''echo "-Q ${physical} ${logical}"'';

                defaultArgs = {
                  name = "rocq${coq.coq-version}-${name}";

                  buildInputs = [ coq ] ++ args.buildInputs or [ ];

                  enableParallelBuilding = true;
                  inherit makefile;

                  configurePhase = ''
                    (
                      exec > "${coqProject}"
                      ${lib.concatStringsSep "\n" (lib.mapAttrsToList emitPath paths)}
                      grep "^[^#]" config/flags | sed "s/^/-arg /"
                    )

                    "coq_makefile" -f "${coqProject}" -o "${makefile}"
                  '';
                };

                passthruArgs = lib.removeAttrs args [
                  "buildInputs"
                  "name"
                  "paths"
                ];
              in
              pkgs.stdenv.mkDerivation (defaultArgs // passthruArgs)
            );

            mkStdppDerivation =
              { subdir, buildInputs }:
              mkIrisProjDerivation {
                src = inputs.stdpp;
                inherit subdir buildInputs;
                meta.description = ''An extended "Standard Library" for Rocq'';
              };

            stdpp = mkStdppDerivation {
              subdir = "stdpp";
              buildInputs = [ stdlib ];
            };

            stdpp-bitvector = mkStdppDerivation {
              subdir = "stdpp_bitvector";
              buildInputs = [
                stdlib
                stdpp
              ];
            };

            stdpp-unstable = mkStdppDerivation {
              subdir = "stdpp_unstable";
              buildInputs = [
                stdlib
                stdpp
                stdpp-bitvector
              ];
            };

            stdpp-test = mkIrisTestDerivation {
              name = "stdpp-test";
              src = inputs.stdpp;
              paths = {
                docs = "stdpp.docs";
                tests = "stdpp.tests";
              };
              buildInputs = [
                stdlib
                stdpp
                stdpp-bitvector
                stdpp-unstable
              ];
            };
          in
          {
            packages = {
              inherit
                stdpp
                stdpp-bitvector
                stdpp-unstable
                ;
            };

            checks = {
              inherit stdpp-test;
            };

            lib = {
              inherit mkIrisProjDerivation mkIrisTestDerivation;
            };

            dev.sources.inputs = [ "stdpp" ];
            dev.env.lib = [ stdlib ];
          };
      }
    );
}
