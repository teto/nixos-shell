# TODO pass lib
with import <nixpkgs> {};

let

    # TODO we can pass the nixos-shell,nix ?
    buildVMs = import <nixpkgs/nixos/lib/build-vms.nix> { inherit system pkgs;
    minimal = false;
    # extraConfigurations;
  };

# { pkgs, lib, ... }:
# with pkgs;
in
rec {

  # import nixos-shell.nix
  # import vm.nix

  testDriver = pkgs.nixosTesting.testDriver;

  # TODO choper ceux de vm.nix
  # vlans = [ 1 2 ];


  # results in /nix/store/pg6ylfi07igw98xgqjc5ag90gr0dkbs7-nixos-vm
  myVmConfig = (import <nixpkgs/nixos> {

    # unexpected argument
    # le pb c que la on ne passe pas le vm.nix ? il est contenu dedans
    # configuration = ./share/nixos-shell/nixos-shell.nix;
    # export QEMU_NIXOS_CONFIG="$(readlink -f "$nixos_config")"
    # will import the config defined by QEMU_NIXOS_CONFIG
    configuration = ./nixos-shell.nix;
  });

  myVm = myVmConfig.vm;

# nix-build '<nixpkgs/nixos>' -A vm -k \
#   -I "nixos-config=${script_dir}/../share/nixos-shell/nixos-shell.nix" \
  tempNodes = {
    toto = myVmConfig;
  };


  nodes = buildVMs.buildVirtualNetwork (
        t.nodes or (if t ? machine then { machine = t.machine; } else { }));

  # vm = vmConfig.system.build.vm;

  # my network of nodes
  testMatt = driver nodes;

  output = pkgs.nixosTesting.runInMachine {
    drv = pkgs.hello;
    machine =  { ... }: { /* services.sshd.enable = true; */ };
    # myVmConfig.config;
    preBuild = ''
      $client->succeed("env -i ${bash}/bin/bash");
    '';

    # This is the original testScript
        # startAll;
        # $client->waitForUnit("multi-user.target");
        # ${preBuild}
        # $client->succeed("env -i ${bash}/bin/bash ${buildrunner} /tmp/xchg/saved-env >&2");
        # ${postBuild}
        # $client->succeed("sync"); # flush all data before pulling the plug
  };

  # copied and adapted from nixos/lib/testing.nix
  # il attend des vmConfig comme decrit dans nixos/default.nix
  driver = nodes:
  # vms=($(for i in ${toString vms}; do echo $i/bin/run-*-vm; done))
    let
      vms = map (m: m.config.system.build.vm) (lib.attrValues nodes);

      vlans = map (m: m.config.virtualisation.vlans) (lib.attrValues nodes);
    in
      pkgs.runCommand "zozo"
    { buildInputs = [ pkgs.makeWrapper];
      preferLocalBuild = true;
      testName = "matt";
    }
    # got rid of --set tests 'startAll; joinAll;' \
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
