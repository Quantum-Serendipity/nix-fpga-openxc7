{ buildPythonPackage, fetchFromGitHub, cmake, cython, textx }:

buildPythonPackage {
  pname = "fasm";
  version = "0.0.2.r98.g9a73d70";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "openxc7";
    repo = "fasm";
    rev = "2f57ccb1727a120e8cacbb95c578f3c71bdcc95a";
    hash = "sha256-ZytcNJvXs+GUSIrf4dtYl+Hc5kEQmeJP+3BQOmQImIw=";
  };

  nativeBuildInputs = [ cmake cython ];
  propagatedBuildInputs = [ textx ];

  dontUseCmakeConfigure = true;
  doCheck = false;
}
