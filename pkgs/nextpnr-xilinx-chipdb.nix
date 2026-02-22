{ stdenv, lib, backend, nextpnr-xilinx, pypy310, coreutils, findutils, gnused
, gnugrep }:

let
  prjxray-db = "${nextpnr-xilinx}/share/nextpnr/external/prjxray-db";
in
stdenv.mkDerivation {
  pname = "nextpnr-xilinx-chipdb-${backend}";
  version = nextpnr-xilinx.version;

  src = prjxray-db;
  dontUnpack = true;

  nativeBuildInputs = [ nextpnr-xilinx pypy310 coreutils findutils gnused gnugrep ];

  buildPhase = ''
    mkdir -p $out
    find ${prjxray-db}/ -type d -name "*-*" -mindepth 1 -maxdepth 2 |\
      sed -e 's,.*/\(.*\)-.*$,\1,g' -e 's,\./,,g' |\
      sort |\
      uniq >\
    $out/footprints.txt

    touch $out/built-footprints.txt

    for i in `cat $out/footprints.txt`
    do
        if   [[ $i = xc7a* ]]; then ARCH=artix7
        elif [[ $i = xc7k* ]]; then ARCH=kintex7
        elif [[ $i = xc7s* ]]; then ARCH=spartan7
        elif [[ $i = xc7z* ]]; then ARCH=zynq7
        else
          echo "unsupported architecture for footprint $i"
          exit 1
        fi

        if [[ $ARCH != "${backend}" ]]; then
          continue
        fi

        FIRST_SPEEDGRADE_DIR=`ls -d ${prjxray-db}/$ARCH/$i-* | sort -n | head -1`
        FIRST_SPEEDGRADE=`echo $FIRST_SPEEDGRADE_DIR | tr '/' '\n' | tail -1`
        pypy3.10 ${nextpnr-xilinx}/share/nextpnr/python/bbaexport.py --device $FIRST_SPEEDGRADE --bba $i.bba 2>&1
        bbasm -l $i.bba $out/$i.bin
        echo $i >> $out/built-footprints.txt
    done

    mv -f $out/built-footprints.txt $out/footprints.txt
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Chip database for nextpnr-xilinx (${backend})";
    license = licenses.isc;
    platforms = platforms.all;
  };
}
