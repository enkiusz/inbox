{ stdenv, pkgs, ... }: stdenv.mkDerivation rec {
  version = "0.91";
  name = "inbox-${version}";

  src = ./.;

  inputs = with pkgs; [ img2pdf colord tesseract ];

  propagatedBuildInputs = with pkgs; [
    libinsane
    qpdf
    nettools
    ( python3.withPackages(ps: with ps; [
      opencv4
      pygobject3
      pillow
      structlog
      pytesseract

      (buildPythonPackage rec {
          pname = "pylcddc";
          version = "0.4.0";
          src = fetchPypi {
            inherit pname version;
            sha256 = "1qyzq3vinlj0c3p4i7b06kh519bvhichh45r4j4nakc70qdk54x6";
          };
      })

    ]) )

  ];

  buildPhase = "";

  installPhase = ''
    mkdir -p $out/bin
    for script in bin/*; do
        install $script -m 0755 $out/bin/$(basename "$script")
    done
  '';

  }
