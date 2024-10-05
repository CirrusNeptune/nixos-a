{ lib, fetchFromGitHub, rustPlatform, ... }:
rustPlatform.buildRustPackage {
  pname = "mowbark-rf";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "CirrusNeptune";
    repo = "nexus-revo-io";
    rev = "cfdbae6f16543b2512aa22d090cd74b89c5c5546";
    hash = "sha256-CVyeXY/bzkd88vEfOUHhypFpea+hT5tVelUoSU2PWWc=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "libftd2xx-cc1101-0.1.0" = "sha256-QOxsE12kFKqgmOU5N+oPpJKeN61CLdovy8B24it2xc8=";
    };
  };
}
