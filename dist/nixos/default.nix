{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
, pkg-config
, openssl
, jsoncpp
, git
}:

stdenv.mkDerivation rec {
  pname = "seatuya";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "MAINTAINER";
    repo = "seatuya";
    rev = "v${version}";
    hash = "sha256-PLACEHOLDER";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    git
  ];

  buildInputs = [
    openssl
    jsoncpp
  ];

  preConfigure = ''
    ./fetch-deps.sh
  '';

  doCheck = true;

  meta = with lib; {
    description = "C wrapper library for tuyapp Tuya device communication";
    longDescription = ''
      seatuya is a C wrapper library for tuyapp, providing a pure C API
      for local Tuya smart-device communication.  Supports protocol
      versions 3.1, 3.3, 3.4, and 3.5.
    '';
    homepage = "https://github.com/MAINTAINER/seatuya";
    license = with licenses; [ bsd2 gpl3Plus mit ];
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
