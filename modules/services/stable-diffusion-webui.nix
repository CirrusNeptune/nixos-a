{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.stable-diffusion-webui;

  # FHS environment with all system dependencies needed by the webui's venv
  fhs = pkgs.buildFHSEnv {
    name = "stable-diffusion-webui-fhs";
    targetPkgs = pkgs: with pkgs; [
      # Python
      python310
      python310Packages.pip
      python310Packages.virtualenv

      # Build tools
      gcc
      gnumake
      cmake
      pkg-config
      git
      wget

      # Core libraries
      stdenv.cc.cc.lib
      zlib
      libffi
      openssl

      # Image processing
      libpng
      libjpeg
      openjpeg

      # GPU / ROCm
      rocmPackages.clr
      rocmPackages.rocm-runtime
      rocmPackages.rocblas
      rocmPackages.rocsolver
      rocmPackages.hipblas
      rocmPackages.rocfft
      rocmPackages.miopen
      rocmPackages.rocm-smi

      # For CPU fallback / math
      openblas
    ];
    runScript = "bash";
  };
in {
  options.a.services.stable-diffusion-webui = {
    enable = lib.mkEnableOption "Enable stable-diffusion-webui service";
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/stable-diffusion-webui";
      description = "Directory for webui installation and data";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Host to bind on";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 7860;
      description = "Port to listen on";
    };
    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra arguments to pass to webui.sh";
    };
    useGpu = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use AMD ROCm GPU acceleration. Set to false for CPU-only.";
    };
    srcDir = lib.mkOption {
      type = lib.types.path;
      description = "Path to stable-diffusion-webui source directory on the NixOS machine";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.stable-diffusion-webui = {
      description = "Stable Diffusion WebUI (AUTOMATIC1111)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = lib.mkMerge [
        {
          HOME = cfg.dataDir;
          COMMANDLINE_ARGS = lib.concatStringsSep " " ([
            "--listen"
            "--port" (toString cfg.port)
            "--api"
            "--skip-torch-cuda-test"
          ] ++ (lib.optionals (!cfg.useGpu) [ "--use-cpu" "all" "--no-half" ])
            ++ cfg.extraArgs);
        }
        (lib.mkIf cfg.useGpu {
          HSA_OVERRIDE_GFX_VERSION = "10.3.0"; # RDNA2 — RX 6800 XT
          PYTORCH_ROCM_ARCH = "gfx1030"; # RDNA2 — RX 6800 XT
          HIP_VISIBLE_DEVICES = "0";
        })
      ];

      serviceConfig = {
        Type = "simple";
        User = "sdwebui";
        Group = "sdwebui";
        WorkingDirectory = cfg.dataDir;
        ExecStartPre = pkgs.writeShellScript "sd-webui-setup" ''
          # Symlink the source into the data dir if not already there
          if [ ! -e "${cfg.dataDir}/webui.sh" ]; then
            cp -rs "${cfg.srcDir}/"* "${cfg.dataDir}/" 2>/dev/null || true
            cp -rs "${cfg.srcDir}/."* "${cfg.dataDir}/" 2>/dev/null || true
            # Ensure writable dirs exist for runtime data
            for dir in models outputs log venv repositories; do
              mkdir -p "${cfg.dataDir}/$dir"
            done
            # Remove symlinks for dirs that need to be writable
            for dir in models outputs log venv repositories; do
              if [ -L "${cfg.dataDir}/$dir" ]; then
                rm "${cfg.dataDir}/$dir"
                mkdir -p "${cfg.dataDir}/$dir"
              fi
            done
          fi
        '';
        ExecStart = "${fhs}/bin/stable-diffusion-webui-fhs -c 'cd ${cfg.dataDir} && bash webui.sh'";
        Restart = "on-failure";
        RestartSec = 10;

        # Hardening
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        StateDirectory = "stable-diffusion-webui";

        # GPU access
        SupplementaryGroups = lib.optionals cfg.useGpu [ "video" "render" ];
      };
    };

    users.users.sdwebui = {
      isSystemUser = true;
      group = "sdwebui";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.sdwebui = {};
  };
}
