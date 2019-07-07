{ pkgs, lib, ... }:
# with pkgs;
rec {

  # import nixos-shell.nix
  # import vm.nix

  testDriver = pkgs.nixosTesting;

  # TODO choper ceux de vm.nix
  vlans = [ 1 2 ];

  # copied and adapted from nixos/lib/testing.nix
  driver = nodes:
    let
      vms = map (m: m.config.system.build.vm) (lib.attrValues nodes);
    in
      pkgs.runCommand "toto"
    { buildInputs = [ pkgs.makeWrapper];
      preferLocalBuild = true;
    }
    ''
      mkdir -p $out/bin
      ln -s ${testDriver}/bin/nixos-test-driver $out/bin/
      vms=($(for i in ${toString vms}; do echo $i/bin/run-*-vm; done))
      wrapProgram $out/bin/nixos-test-driver \
        --add-flags "''${vms[*]}" \
        --set VLANS '${toString vlans}'
      ln -s ${testDriver}/bin/nixos-test-driver $out/bin/nixos-run-vms
      wrapProgram $out/bin/nixos-run-vms \
        --add-flags "''${vms[*]}" \
        --set tests 'startAll; joinAll;' \
        --set VLANS '${toString vlans}' \
        ${lib.optionalString (builtins.length vms == 1) "--set USE_SERIAL 1"}
    ''; # "
}
