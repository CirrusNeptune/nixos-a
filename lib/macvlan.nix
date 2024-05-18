{ lib }:

{
  makeMacvlanProfile =
    interface:
    name:
    hostname:
      lib.attrsets.nameValuePair "macvlan-${interface}.${name}" {
        connection = {
          id = "macvlan-${interface}.${name}";
          type = "macvlan";
          interface-name = "${interface}.${name}";
        };
        macvlan = {
          mode = "1";
          parent = "${interface}";
        };
        ipv4 = {
          dhcp-hostname = "${hostname}";
          method = "auto";
        };
        ipv6 = {
          addr-gen-mode = "default";
          method = "auto";
        };
      };
}
