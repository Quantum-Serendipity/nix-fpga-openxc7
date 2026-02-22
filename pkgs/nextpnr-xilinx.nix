{ lib, stdenv, fetchFromGitHub, cmake, git, python3, boost, eigen, llvmPackages }:

let
  boostPython = boost.override {
    python = python3;
    enablePython = true;
  };
in
stdenv.mkDerivation {
  pname = "nextpnr-xilinx";
  version = "0.8.2-unstable-2026-02-09";

  src = fetchFromGitHub {
    owner = "openXC7";
    repo = "nextpnr-xilinx";
    rev = "bd56820e1094a3bac2922fd462444a9808a593f4";
    hash = "sha256-JnR0jLb34fBauw1MO48AUiDIGg8IbhOgRbLWykmjy4U=";
    fetchSubmodules = true;
  };

  patches = [
    ../patches/nextpnr-xilinx-scopeinfo.patch
  ];

  nativeBuildInputs = [ cmake git ];
  buildInputs = [ boostPython python3 eigen ]
    ++ (lib.optionals stdenv.cc.isClang [ llvmPackages.openmp ]);

  cmakeFlags = [
    "-DCURRENT_GIT_VERSION=bd56820"
    "-DARCH=xilinx"
    "-DBUILD_GUI=OFF"
    "-DBUILD_TESTS=OFF"
    "-DUSE_OPENMP=ON"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    # Boost split outputs: headers in dev, libraries in out.
    # FindBoost only searches relative to headers; point it at the lib dir.
    "-DBOOST_LIBRARYDIR=${boostPython}/lib"
    "-Wno-deprecated"
  ];

  # GCC 15 requires explicit <cstdint> for uint8_t etc.
  env.CXXFLAGS = "-include cstdint";

  postPatch = ''
    # The hardcoded Boost.Python search list only goes up to python312.
    # Add python313 for Python 3.13 compatibility.
    substituteInPlace CMakeLists.txt \
      --replace-fail "foreach (PyVer 3 36 37 38 39 310 311 312)" \
                     "foreach (PyVer 3 36 37 38 39 310 311 312 313)"

    # Don't use #embed macro - causes spurious type narrowing errors with newer compilers.
    # See: https://github.com/llvm/llvm-project/issues/119256
    if grep -q "check_cxx_compiler_hash_embed" CMakeLists.txt; then
      substituteInPlace CMakeLists.txt \
        --replace-fail "check_cxx_compiler_hash_embed(HAS_HASH_EMBED CXX_FLAGS_HASH_EMBED)" ""
    fi
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp nextpnr-xilinx bbasm $out/bin/
    mkdir -p $out/share/nextpnr/external
    cp -rv ../xilinx/external/prjxray-db $out/share/nextpnr/external/
    cp -rv ../xilinx/external/nextpnr-xilinx-meta $out/share/nextpnr/external/
    cp -rv ../xilinx/python/ $out/share/nextpnr/python/
    cp ../xilinx/constids.inc $out/share/nextpnr
  '';

  meta = with lib; {
    description = "Place and route tool for Xilinx 7-series FPGAs";
    homepage = "https://github.com/openXC7/nextpnr-xilinx";
    license = licenses.isc;
    platforms = platforms.all;
  };
}
