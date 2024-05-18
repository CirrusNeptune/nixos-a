{ lib, fetchFromGitHub, rustPlatform, ... }:
rustPlatform.buildRustPackage {
  pname = "mowbark-rf";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "CirrusNeptune";
    repo = "nexus-revo-io";
    rev = "656b040afb38c7a2bf2680f34fa1d727bb94f2ee";
    hash = "sha256-zlKu7lHeBzX9kUIRDDFaZuNo3CKjSg7s0kmViUUy6Wo=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "libftd2xx-cc1101-0.1.0" = "sha256-M8Ok4uzbaOdFywjlndqSPaHBTpURFbGnLhZGymBuPfE=";
    };
  };
}
