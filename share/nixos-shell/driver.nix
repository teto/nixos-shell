# TODO pass lib
# { pkgs, ... }:

let
  vm_config = builtins.getEnv "QEMU_NIXOS_CONFIG";

  pkgs = import <nixpkgs> {};

  # TODO we can pass the nixos-shell,nix ?
  buildVMs = import <nixpkgs/nixos/lib/build-vms.nix> {
      inherit (pkgs) system pkgs;
      minimal = false;
      instrument = false;
    extraConfigurations = [./nixos-shell.nix];
  };

  # results in /nix/store/pg6ylfi07igw98xgqjc5ag90gr0dkbs7-nixos-vm
  # myVmConfig = (import <nixpkgs/nixos> {

  #   # unexpected argument
  #   # export QEMU_NIXOS_CONFIG="$(readlink -f "$nixos_config")"
  #   # will import the config defined by QEMU_NIXOS_CONFIG
  #   # can be a module
  #   configuration = ./nixos-shell.nix;

  # });

  # format expected by the testing infra
  # builtins.trace myVmConfig.config.virtualisation.qemu.networkingOptions
  tempNodes = {
    main = import vm_config { inherit (pkgs) pkgs lib;};
  };

in
rec {

  testDriver = pkgs.nixosTesting.testDriver;

  nodes2 = let res = buildVMs.buildVirtualNetwork ( tempNodes ); in  res;


  testMatt = driver nodes2;

  # copied and adapted from nixos/lib/testing.nix
  # expects a set of vmConfig as described in nixos/default.nix

  # vlans = map (m: m.config.virtualisation.vlans) (lib.attrValues nodes);
  # vms = map (m: m.config.system.build.vm) (lib.attrValues nodes);
  driver = nodes:
    let
      lib = pkgs.lib;
      vms = map (m: m.config.system.build.vm) (lib.attrValues nodes);

      vlans = map (m: lib.debug.traceValSeq m.config.virtualisation.vlans) (lib.attrValues nodes);
    in
      pkgs.runCommand "zozo"
    { buildInputs = [ pkgs.makeWrapper];
      preferLocalBuild = true;
      testName = "matt";
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
        --set VLANS '${toString vlans}' \
        --set tests 'startAll; joinAll;' \
        ${lib.optionalString (builtins.length vms == 1) "--set USE_SERIAL 1"}
    ''; # "
}
