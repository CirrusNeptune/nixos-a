{ lib, fetchFromGitHub, rustPlatform, ... }:
rustPlatform.buildRustPackage {
  pname = "mowbark-rf";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "CirrusNeptune";
    repo = "nexus-revo-io";
    rev = "5765896935696eff17884aed46333acfbafe02c0";
    hash = "sha256-9xhjAlWMkA35t5UIy4gBhQ7pP6A9pUY0ApX34TGSXPA=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "libftd2xx-cc1101-0.1.0" = "sha256-M8Ok4uzbaOdFywjlndqSPaHBTpURFbGnLhZGymBuPfE=";
    };
  };
}
