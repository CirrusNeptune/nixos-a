{ lib, fetchFromGitHub, rustPlatform, ... }:
rustPlatform.buildRustPackage {
  pname = "mowbark-rf";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "CirrusNeptune";
    repo = "nexus-revo-io";
    rev = "802340ccc01e0960ba6d338d3bf8e16d3058c5f5";
    hash = "sha256-Vz/YMNSK3ay0xTVT3ic6d4/h61IDl2yUUJ17lsHpoNU=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "libftd2xx-cc1101-0.1.0" = "sha256-M8Ok4uzbaOdFywjlndqSPaHBTpURFbGnLhZGymBuPfE=";
    };
  };
}
#{
  #systemd.services.mowbark-rf = {
  #  description = "Mowbark RF";
  #  wantedBy = [ "podman-homeassistant.service" ];
  #  serviceConfig = {
  #    Type = "simple";
  #    ExecStart = "${lib.getBin mowbark-rf}/bin/nexus-revo-io";
  #  };
  #};
#}
