# How To
## How To Update MowBark Home Assistant Image
1. Build a new image at [homeassistant-mowbark](https://github.com/CirrusNeptune/homeassistant-mowbark).
2. View the new built image [at the registry](https://github.com/cirrusneptune/homeassistant-mowbark/pkgs/container/homeassistant-mowbark)
3. Update `imageDigest` which is the name - the string needed should be derivable for the information present on the registry page
4. Make the `sha256` an empty string to force a cache miss
5. Commit and build nixos - it will fail and tell you what the checksum sha should be
5. Update the checksum sha `sha256`
    1. note - you may have to make the `sha256` an empty string for this to work

```nix
  haImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/cirrusneptune/homeassistant-mowbark";
    imageDigest = "sha256:b87e765fb5586477659b5ba24d9e372e97f555d549bc81e386261158fac48a7d"; 
    sha256 = ""; <- empty, then place the new SHA here
    finalImageTag = "a";
    finalImageName = "localhost/homeassistant-a";
  };
```
example [pr](https://github.com/CirrusNeptune/nixos-a/pull/15)
see [dockertools](https://ryantm.github.io/nixpkgs/builders/images/dockertools/) doc for more information