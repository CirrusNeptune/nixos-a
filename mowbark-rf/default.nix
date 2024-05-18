{ lib, fetchFromGitHub, rustPlatform, ... }:
rustPlatform.buildRustPackage {
  pname = "mowbark-rf";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "CirrusNeptune";
    repo = "nexus-revo-io";
    rev = "268462f0dcef45cb30417d58d796e4832ba423e1";
    hash = "sha256-AQ8AS5drLahClzhZT1VULxNkd5NVKmQ7poztQEb9K9Y=";
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
