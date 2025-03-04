{
  description = "C3 development environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    my-pkgs.url = "github:hucancode/nixpkgs";
  };

  outputs = { self, nixpkgs, my-pkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
        my-pkgs = import my-pkgs { inherit system; };
      });
    in
    {
      devShells = forEachSupportedSystem ({ pkgs, my-pkgs }: {
        default = pkgs.mkShell.override
          { }
          {
            packages = with pkgs; [
              glfw
              freetype
              vulkan-loader
              shaderc
              tracy
              my-pkgs.c3c
            ] ++ (if system == "x86_64-darwin" || system == "aarch64-darwin" then [ moltenvk ] else [ vulkan-validation-layers ]);
          };
      });
    };
}
