{
  description = "persistent-evdev-rs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;

    # Format generator for JSON
    jsonFormat = pkgs.formats.json {};

    # JSON Config - this is customizable
    defaultJsonConfig = {
      cache = "/opt/persistent-evdev-rs/cache";
      devices = {
        "persist-mouse0" = "/dev/input/by-id/usb-Logitech_G403_Prodigy_Gaming_Mouse_078738533531-event-if01";
        "persist-mouse1" = "/dev/input/by-id/usb-Logitech_G403_Prodigy_Gaming_Mouse_078738533531-event-mouse";
        "persist-mouse2" = "/dev/input/by-id/usb-Logitech_G403_Prodigy_Gaming_Mouse_078738533531-if01-event-kbd";
        "persist-keyboard0" = "/dev/input/by-id/usb-Microsoft_Natural®_Ergonomic_Keyboard_4000-event-kbd";
        "persist-keyboard1" = "/dev/input/by-id/usb-Microsoft_Natural®_Ergonomic_Keyboard_4000-if01-event-kbd";
      };
      default_udev_interval = 50;
    };

    # Build the Rust binary
    persistent-evdev-rs-package = pkgs.rustPlatform.buildRustPackage {
      pname = "persistent-evdev-rs";
      version = "0.1.0";
      src = ./.;
      cargoLock.lockFile = ./Cargo.lock;
      cargoLock.outputHashes = {
        "evdev-0.12.1" = "sha256-5G8If61GqTmcEwWqUtpcf/T20AzLiGBg+8R7kROwURo=";
      };
      nativeBuildInputs = [
          pkgs.pkg-config
      ];

      buildInputs = [
          pkgs.systemd.dev  # includes libudev
      ];

      meta = {
        description = "evdev keymapper with persistent device paths and JSON config";
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };
    };

    # NixOS Module
    persistent-evdev-rs-service = { config, lib, pkgs, ... }: let
      cfg = config.services.persistent-evdev-rs;
      jsonConf = jsonFormat.generate "persistent-evdev-rs.json" cfg.settings;
    in {
      options.services.persistent-evdev-rs = {
        enable = lib.mkEnableOption "Enable persistent-evdev-rs service";

        package = lib.mkOption {
          type = lib.types.package;
          default = persistent-evdev-rs-package;
          description = "The persistent-evdev-rs binary package.";
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = defaultJsonConfig;
          description = "Configuration for the persistent-evdev-rs in JSON format.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.persistent-evdev-rs = {
          description = "persistent-evdev-rs: remap keys with evdev via JSON config";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${cfg.package}/bin/persistent-evdev-rs ${jsonConf}";
            Restart = "always";
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ReadOnlyPaths = [ "${jsonConf}" ];
          };
        };

        services.udev.extraRules = ''
          KERNEL=="event*", ATTRS{phys}=="rs-evdev-uinput", ATTRS{name}=="?*", SYMLINK+="input/by-id/uinput-$attr{name}"
        '';
      };
    };
  in {
    packages.${system}.default = persistent-evdev-rs-package;
    overlays.default = final: prev: {
      persistent-evdev-rs = persistent-evdev-rs-package;
    };
    nixosModules.default = persistent-evdev-rs-service;
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        pkgs.rustc
        pkgs.cargo
        pkgs.gnumake
      ];
      shellHook = ''
        echo "Dev shell for persistent-evdev-rs ready"
      '';
    };
  };
}
