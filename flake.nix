{
  description = "openXC7 FPGA toolchain for Xilinx 7-series";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = final: prev:
        let
          nextpnr-xilinx = final.callPackage ./pkgs/nextpnr-xilinx.nix {};
          fasm = final.python3Packages.callPackage ./pkgs/fasm.nix {};
          mkChipdb = backend: final.callPackage ./pkgs/nextpnr-xilinx-chipdb.nix {
            inherit backend nextpnr-xilinx;
          };
        in {
          openxc7 = {
            inherit nextpnr-xilinx fasm;
            chipdb-artix7   = mkChipdb "artix7";
            chipdb-kintex7  = mkChipdb "kintex7";
            chipdb-spartan7 = mkChipdb "spartan7";
            chipdb-zynq7    = mkChipdb "zynq7";
            prjxray = final.callPackage ./pkgs/prjxray.nix { inherit fasm; };
          };
        };

      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          inherit (pkgs.openxc7)
            nextpnr-xilinx chipdb-artix7 chipdb-kintex7 chipdb-spartan7
            chipdb-zynq7 fasm prjxray;
        });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          inherit (pkgs.openxc7) nextpnr-xilinx chipdb-artix7 prjxray;
        in {
          default = pkgs.mkShell {
            packages = [
              nextpnr-xilinx
              chipdb-artix7
              prjxray
              pkgs.yosys
            ];

            shellHook = ''
              # Set up openxc7 chipdb with symlinks for industrial temp variants
              export CHIPDB="$HOME/.cache/openxc7-chipdb/artix7"
              mkdir -p "$CHIPDB"
              for f in ${chipdb-artix7}/*.bin; do
                ln -sf "$f" "$CHIPDB/"
                base=$(basename "$f" .bin)
                i_name=$(echo "$base" | sed 's/\(xc7[a-z]*[0-9]*t\)\([a-z]\)/\1i\2/')
                if [ "$i_name" != "$base" ] && [ ! -e "$CHIPDB/''${i_name}.bin" ]; then
                  ln -sf "$f" "$CHIPDB/''${i_name}.bin"
                fi
              done

              export PRJXRAY_DB_DIR="${nextpnr-xilinx}/share/nextpnr/external/prjxray-db"
              export NEXTPNR_XILINX_PYTHON_DIR="${nextpnr-xilinx}/share/nextpnr/python"

              echo "openXC7 toolchain loaded"
            '';
          };
        });
    };
}
