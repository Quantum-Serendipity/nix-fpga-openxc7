# nix-fpga-openxc7

A Nix flake providing the [openXC7](https://github.com/openXC7) FPGA toolchain for Xilinx 7-series devices. Build bitstreams for Artix-7, Kintex-7, Spartan-7, and Zynq-7 FPGAs using entirely open-source tools with fully reproducible Nix builds.

## What is openXC7?

openXC7 is an open-source alternative to Xilinx Vivado for synthesizing, placing, routing, and generating bitstreams for Xilinx 7-series FPGAs. The toolchain combines several projects:

- **[Yosys](https://github.com/YosysHQ/yosys)** -- RTL synthesis (Verilog/SystemVerilog to netlist)
- **[nextpnr-xilinx](https://github.com/openXC7/nextpnr-xilinx)** -- Place and route for Xilinx 7-series
- **[Project X-Ray](https://github.com/f4pga/prjxray)** -- Bitstream documentation and generation tools
- **[FASM](https://github.com/openxc7/fasm)** -- FPGA Assembly format, the intermediate representation between place-and-route and bitstream generation

### Build flow

```
Verilog / SystemVerilog
        |
        v
   yosys (synthesis)
        |
        v
 nextpnr-xilinx (place & route)
   uses: chipdb + XDC constraints
        |
        v
   FASM output
        |
        v
 fasm2frames (FASM -> frames)
   uses: prjxray-db
        |
        v
 xc7frames2bit (frames -> bitstream)
        |
        v
   .bit file
```

## Packages provided

All packages are exposed under the `openxc7` attribute set via the overlay:

| Package | Description |
|---------|-------------|
| `nextpnr-xilinx` | Place and route tool for Xilinx 7-series FPGAs |
| `prjxray` | Bitstream tools: `xc7frames2bit`, `bitread`, `xc7patch`, `fasm2frames`, `bit2fasm` |
| `fasm` | Python library for FASM parsing and manipulation |
| `chipdb-artix7` | Chip database for Artix-7 devices |
| `chipdb-kintex7` | Chip database for Kintex-7 devices |
| `chipdb-spartan7` | Chip database for Spartan-7 devices |
| `chipdb-zynq7` | Chip database for Zynq-7 devices |

Yosys is provided by nixpkgs and included in the devShell.

## Supported systems

- `x86_64-linux`
- `aarch64-linux`

## Quick start

### Using the devShell directly

```sh
nix develop github:Quantum-Serendipity/nix-fpga-openxc7
```

This drops you into a shell with `yosys`, `nextpnr-xilinx`, `prjxray` tools, and the Artix-7 chip database ready to use. Environment variables `CHIPDB`, `PRJXRAY_DB_DIR`, and `NEXTPNR_XILINX_PYTHON_DIR` are set automatically.

### Using as a flake input

Add the overlay to your project's `flake.nix` to access all openxc7 packages:

```nix
{
  description = "My FPGA project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-fpga-openxc7 = {
      url = "github:Quantum-Serendipity/nix-fpga-openxc7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-fpga-openxc7, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-fpga-openxc7.overlays.default ];
      };
      inherit (pkgs.openxc7) nextpnr-xilinx chipdb-artix7 prjxray;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          nextpnr-xilinx
          chipdb-artix7
          prjxray
          pkgs.yosys
        ];

        shellHook = ''
          export CHIPDB="$HOME/.cache/openxc7-chipdb/artix7"
          mkdir -p "$CHIPDB"
          for f in ${chipdb-artix7}/*.bin; do
            ln -sf "$f" "$CHIPDB/"
          done
          export PRJXRAY_DB_DIR="${nextpnr-xilinx}/share/nextpnr/external/prjxray-db"
          export NEXTPNR_XILINX_PYTHON_DIR="${nextpnr-xilinx}/share/nextpnr/python"
        '';
      };
    };
}
```

### Using with devenv

[devenv](https://devenv.sh) can consume Nix flakes as inputs. Create a `devenv.nix` and `flake.nix` at the root of your project:

**`flake.nix`**:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv.url = "github:cachix/devenv";
    nix-fpga-openxc7 = {
      url = "github:Quantum-Serendipity/nix-fpga-openxc7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, devenv, nix-fpga-openxc7, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-fpga-openxc7.overlays.default ];
      };
    in
    {
      devShells.${system}.default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [ ./devenv.nix ];
      };
    };
}
```

**`devenv.nix`**:

```nix
{ pkgs, ... }:

let
  inherit (pkgs.openxc7) nextpnr-xilinx chipdb-artix7 prjxray;
in
{
  packages = [
    nextpnr-xilinx
    chipdb-artix7
    prjxray
    pkgs.yosys
    pkgs.gnumake
  ];

  enterShell = ''
    export CHIPDB="$HOME/.cache/openxc7-chipdb/artix7"
    mkdir -p "$CHIPDB"
    for f in ${chipdb-artix7}/*.bin; do
      ln -sf "$f" "$CHIPDB/"
    done
    export PRJXRAY_DB_DIR="${nextpnr-xilinx}/share/nextpnr/external/prjxray-db"
    export NEXTPNR_XILINX_PYTHON_DIR="${nextpnr-xilinx}/share/nextpnr/python"
    echo "openXC7 toolchain ready"
  '';
}
```

Then activate with:

```sh
devenv shell
```

### Targeting a different device family

Replace `chipdb-artix7` with the appropriate chip database for your target. For example, to target a Zynq-7 device:

```nix
inherit (pkgs.openxc7) nextpnr-xilinx chipdb-zynq7 prjxray;

packages = [
  nextpnr-xilinx
  chipdb-zynq7
  prjxray
  pkgs.yosys
];

shellHook = ''
  export CHIPDB="$HOME/.cache/openxc7-chipdb/zynq7"
  mkdir -p "$CHIPDB"
  for f in ${chipdb-zynq7}/*.bin; do
    ln -sf "$f" "$CHIPDB/"
  done
  # ...
'';
```

## Building a bitstream

With the devShell active, a typical build flow looks like:

```sh
# 1. Synthesize Verilog to JSON netlist
yosys -p "synth_xilinx -flatten -abc9 -arch xc7 -top top" \
  -o design.json design.v

# 2. Place and route
nextpnr-xilinx --chipdb "$CHIPDB/xc7a35tcpg236.bin" \
  --xdc constraints.xdc \
  --netlist design.json \
  --write design_routed.fasm \
  --fasm design.fasm

# 3. Convert FASM to frames
fasm2frames --part xc7a35tcpg236-1 \
  --db-root "$PRJXRAY_DB_DIR/artix7" \
  design.fasm > design.frames

# 4. Generate bitstream
xc7frames2bit --part-file "$PRJXRAY_DB_DIR/artix7/xc7a35tcpg236-1/part.yaml" \
  --part-name xc7a35tcpg236-1 \
  --frm-file design.frames \
  --output-file design.bit
```

## Composing with other flakes

This flake is designed to compose cleanly with other Nix flakes. For example, combining with [nix-litex](https://github.com/Quantum-Serendipity/nix-litex) to build LiteX SoC gateware:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-fpga-openxc7 = {
      url = "github:Quantum-Serendipity/nix-fpga-openxc7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-litex = {
      url = "github:Quantum-Serendipity/nix-litex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-fpga-openxc7, nix-litex, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nix-fpga-openxc7.overlays.default
          nix-litex.overlays.default
        ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ nix-fpga-openxc7.devShells.${system}.default ];
        packages = [
          pkgs.python3Packages.litex
          pkgs.python3Packages.litex-boards
          pkgs.python3Packages.litedram
          pkgs.python3Packages.liteeth
          pkgs.python3Packages.litepcie
          pkgs.gnumake
          pkgs.gcc
        ];
      };
    };
}
```

## License

The packaging in this repository is licensed under ISC, matching the upstream openXC7 projects.
