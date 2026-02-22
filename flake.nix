{
  description = "openXC7 FPGA toolchain + LiteX SoC builder for Xilinx 7-series";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-litex = {
      url = "github:Quantum-Serendipity/nix-litex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-litex }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in
    {
      overlays.default = nixpkgs.lib.composeManyExtensions [
        nix-litex.overlays.default
        (final: prev:
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
          })
      ];

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
              # openXC7 FPGA toolchain
              nextpnr-xilinx
              chipdb-artix7
              prjxray
              pkgs.yosys

              # LiteX SoC builder
              pkgs.python3Packages.litex
              pkgs.python3Packages.litex-boards
              pkgs.python3Packages.litedram
              pkgs.python3Packages.liteeth
              pkgs.python3Packages.liteiclink
              pkgs.python3Packages.litescope
              pkgs.python3Packages.litespi
              pkgs.python3Packages.litepcie
              pkgs.python3Packages.litehyperbus
              pkgs.python3Packages.litesdcard
              pkgs.python3Packages.litevideo
              pkgs.python3Packages.litesata
              pkgs.python3Packages.litejesd204b
              pkgs.python3Packages.litei2c

              # Build tools (LiteX calls make/gcc via subprocess)
              pkgs.gnumake
              pkgs.gcc

              # Simulation (litex_sim)
              pkgs.verilator
              pkgs.libevent
              pkgs.json_c
              pkgs.zlib
              pkgs.zeromq

              # RISC-V cross-compiler for SoC BIOS/firmware
              pkgs.pkgsCross.riscv64.buildPackages.gcc
            ];

            shellHook = ''
              # Set up openxc7 chipdb with symlinks for industrial temp variants
              export CHIPDB="$HOME/.cache/openxc7-chipdb/artix7"
              mkdir -p "$CHIPDB"
              for f in ${chipdb-artix7}/*.bin; do
                ln -sf "$f" "$CHIPDB/"
                # Create industrial variant symlinks (xc7a35tcsg324 -> xc7a35ticsg324)
                base=$(basename "$f" .bin)
                i_name=$(echo "$base" | sed 's/\(xc7[a-z]*[0-9]*t\)\([a-z]\)/\1i\2/')
                if [ "$i_name" != "$base" ] && [ ! -e "$CHIPDB/''${i_name}.bin" ]; then
                  ln -sf "$f" "$CHIPDB/''${i_name}.bin"
                fi
              done

              export PRJXRAY_DB_DIR="${nextpnr-xilinx}/share/nextpnr/external/prjxray-db"
              export NEXTPNR_XILINX_PYTHON_DIR="${nextpnr-xilinx}/share/nextpnr/python"

              echo "openXC7 + LiteX development environment loaded"
            '';
          };
        });
    };
}
