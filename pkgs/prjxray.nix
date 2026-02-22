{ lib, stdenv, fetchFromGitHub, cmake, git, makeWrapper, python3
, python3Packages, eigen, fasm }:

let
  prjxray-python = python3.withPackages (ps: [
    fasm
    ps.pyyaml
    ps.simplejson
    ps.intervaltree
    ps.numpy
    ps.pyjson5
    ps.progressbar
  ]);
in
stdenv.mkDerivation {
  pname = "prjxray";
  version = "unstable-2024-01-15";

  src = fetchFromGitHub {
    owner = "f4pga";
    repo = "prjxray";
    rev = "bdbc665852b82f589ff775a8f6498542dbec0a07";
    fetchSubmodules = true;
    hash = "sha256-lV4o62lS7CMG0EYPhp9bTB4fg0hOixy8CC8yGxKhGQE=";
  };

  nativeBuildInputs = [ cmake git makeWrapper ];
  buildInputs = [ python3Packages.boost python3 eigen ];

  cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];

  # GCC 15 requires explicit <cstdint> for uint8_t/uint16_t/uint32_t;
  # prjxray and its bundled third-party deps are missing these includes.
  env.CXXFLAGS = "-include cstdint -Wno-error=free-nonheap-object";

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail "cmake " "cmake -Wno-deprecated "
    # Insert compile option at line 29 of lib/CMakeLists.txt (positional insert)
    sed -i '29 itarget_compile_options(libprjxray PUBLIC "-Wno-deprecated")' lib/CMakeLists.txt
  '';

  installPhase = ''
    mkdir -p $out/bin $out/lib/prjxray-python $out/lib/prjxray-scripts

    # C++ bitstream tools
    cp -v tools/xc7frames2bit tools/bitread tools/xc7patch $out/bin

    # Python library module
    cp -rv $src/prjxray $out/lib/prjxray-python/

    # Python scripts (called via wrappers below)
    cp -v $src/utils/fasm2frames.py $out/lib/prjxray-scripts/
    cp -v $src/utils/bit2fasm.py $out/lib/prjxray-scripts/

    # Wrappers: use Python-with-fasm interpreter, add prjxray module to PYTHONPATH
    makeWrapper ${prjxray-python}/bin/python3 $out/bin/fasm2frames \
      --add-flags "$out/lib/prjxray-scripts/fasm2frames.py" \
      --prefix PYTHONPATH : "$out/lib/prjxray-python"

    makeWrapper ${prjxray-python}/bin/python3 $out/bin/bit2fasm \
      --add-flags "$out/lib/prjxray-scripts/bit2fasm.py" \
      --prefix PYTHONPATH : "$out/lib/prjxray-python"
  '';

  doCheck = false;

  meta = with lib; {
    description = "Xilinx 7-series bitstream documentation and tools";
    homepage = "https://github.com/f4pga/prjxray";
    license = licenses.isc;
    platforms = platforms.all;
  };
}
