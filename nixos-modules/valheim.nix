{
  config,
  lib,
  valheim-server,
  ...
}: let
  cfg = config.services.valheim;
in {
  options.services.valheim = {
    enable = lib.mkEnableOption (lib.mdDoc "enable");

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "Some Cozy Server";
      description = lib.mdDoc "The name listed in the server browser.";
    };

    worldName = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "Midgard";
      description = lib.mdDoc ''
        The name of the world file to use, without the extension.
        If unset, then the server will use a default name.
        In either case, if the world does not exist, then the server will
        generate a world from a random seed.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2456;
      description = lib.mdDoc ''
        The port on which to listen for incoming connections.

        Note that the port just above this one will be used for the Steam server browser service.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to open ports in the firewall.";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = lib.mdDoc ''
        The server password.

        This can only be passed as a commandline argument to the server, so it
        can be viewed by any user on the system able to list processes.
      '';
    };
  };

  config = {
    users = {
      users.valheim = {
        isSystemUser = true;
        group = "valheim";
        home = "/var/lib/valheim";
      };
      groups.valheim = {};
    };

    systemd.services.valheim = {
      description = "Valheim dedicated server";
      requires = ["network.target"];
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "exec";
        User = "valheim";
        ExecStart = lib.strings.concatStringsSep " " ([
            "${valheim-server}/valheim_server"
            "-name \"${cfg.serverName}\""
          ]
          ++ (lib.lists.optional (cfg.worldName != null) "-world \"${cfg.worldName}\"")
          ++ [
            "-port \"${builtins.toString cfg.port}\""
            "-password \"${cfg.password}\""
          ]);
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.port
        (cfg.port + 1) # Steam server browser
      ];
    };

    assertions = [
      {
        assertion = cfg.serverName != "";
        message = "The server name must not be empty.";
      }
      {
        assertion = cfg.worldName != null -> (cfg.worldName != "");
        message = "The world name is set but empty.";
      }
      {
        assertion = cfg.password != "";
        message = "The password must not be empty.";
      }
    ];
  };
}
