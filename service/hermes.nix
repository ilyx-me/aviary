{
  config,
  inputs,
  pkgs,
  ...
}:

{
  config = {
    systemd.tmpfiles.rules = [
      "d /home/nixos-containers 0755 root root - - "
      "L /var/lib/nixos-containers - - - - /home/nixos-containers"
    ];

    containers.hermes = {
      autoStart = true;

      allowedDevices = [
        { node = "/dev/dri";              modifier = "rw"; }
        { node = "/dev/shm";              modifier = "rw"; }
        { node = "/dev/nvidia0";          modifier = "rw"; }
        { node = "/dev/nvidiactl";        modifier = "rw"; }
        { node = "/dev/nvidia-modeset";   modifier = "rw"; }
        { node = "/dev/nvidia-uvm";       modifier = "rw"; }
        { node = "/dev/nvidia-uvm-tools"; modifier = "rw"; }
      ];

      bindMounts = {
        "/run/opengl-driver" = { };
        "/dev/dri" = { };
        "/dev/shm" = { };
        "/dev/nvidia0" = { };
        "/dev/nvidiactl" = { };
        "/dev/nvidia-modeset" = { };
        "/dev/nvidia-uvm" = { };
        "/dev/nvidia-uvm-tools" = { };
        "/sys/module/nvidia" = { };
        "/sys/module/nvidia_drm" = { };
        "/sys/module/nvidia_modeset" = { };
        "/sys/module/nvidia_uvm" = { };
      };

      config = { ... }: {

        _module.args = { inherit inputs; };
        imports = [
          inputs.hermes-agent.nixosModules.default
        ];

        nixpkgs.overlays = [ inputs.hermes-agent.overlays.default ];

        system.stateVersion = "26.05";

        hardware.nvidia = {
          open = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
        };

        environment.enableAllTerminfo = true;

        environment.systemPackages = with pkgs; [
          git
          mcp-nixos
        ];

        users.users."user" = {
          isNormalUser = true;
          password = "password";
        };

        services = {

          openssh = {
            enable = true;
            ports = [ 2224 ];
          };

          ollama = {
            enable = true;
            package = pkgs.ollama-cuda;
            user = "ollama";
            environmentVariables = {
              OLLAMA_CONTEXT_LENGTH = "97280";
              OLLAMA_KV_CACHE_TYPE = "q4_0";
              OLLAMA_FLASH_ATTENTION = "1";
            };
          };

          hermes-agent = {
            enable = true;
            addToSystemPackages = true;
            #package = pkgs.hermes-agent.override {
            #  extraPythonPackages = [ pkgs.python312Packages.ddgs ];
            #};
            settings = {
              model ={
                default = "qwen3.6:27b";
                provider = "custom";
                base_url = "http://localhost:11434/v1";
                context_length = "97280";
              };
              web.backend = "ddgs";
            };
            mcpServers = {
              mcp-nixos = {
                command = "mcp-nixos";
              };
            };
            extraPythonPackages = [
              /*
              (pkgs.python312Packages.buildPythonPackage {
                pname = "ddgs";
                version = "9.15.0";
                src = pkgs.fetchFromGithub {
                  owner = "deedy5";
                  repo = "ddgs";
                  rev = "v9.15.0";
                  hash = "0cxz4ppcala5kzwkhfqc0ng7nqjg26lv9aflcfsgvk19pcyx80aa";
                };
                format = "pyproject";
                #build-system = [ pkgs.python312Packages.setuptools ];
              })
              */
            ];
          };
        };
      };
    };
  };
}
