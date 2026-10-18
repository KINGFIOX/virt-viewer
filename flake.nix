{
  description = "virt-viewer development toolchain";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # meson.build 中的必需库依赖
        requiredLibs = with pkgs; [
          glib    # glib-2.0 / gmodule-2.0 >= 2.48
          gtk3    # gtk+-3.0 >= 3.18
          libxml2 # libxml-2.0 >= 2.6.0
        ];

        # meson_options.txt 中的 auto 功能项，meson 找不到的会自动禁用对应功能。
        # nixpkgs 未打包 govirt，因此 oVirt 始终为禁用状态（nixpkgs 官方的
        # virt-viewer 包同样传 -Dovirt=disabled）。
        optionalLibs = with pkgs; [
          libvirt         # -Dlibvirt：libvirt >= 1.2.8
          libvirt-glib    # -Dlibvirt：libvirt-glib-1.0 >= 0.1.8
          gtk-vnc         # -Dvnc：gtk-vnc-2.0 >= 0.4.0
          spice-gtk       # -Dspice：spice-client-glib/gtk-3.0 >= 0.35
          spice-protocol  # -Dspice：spice-protocol >= 0.12.7
          librest         # -Dovirt：rest-1.0 >= 0.10.2（但缺 govirt，功能仍禁用）
          vte             # -Dvte：vte-2.91 >= 0.46
          bash-completion # -Dbash_completion >= 2.0
        ];

        # 平台上不可用的库会被剔除，meson 层面再自动禁用对应功能
        libs = nixpkgs.lib.filter
          (nixpkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform)
          (requiredLibs ++ optionalLibs);
      in
      {
        devShells.default = pkgs.mkShell {
          packages =
            (with pkgs; [
              meson    # >= 0.56
              ninja
              pkg-config
              gettext  # po/i18n：msgfmt、xgettext
              perl     # man/：pod2man
              python3  # 构建脚本、AUTHORS 生成
              git      # .git 存在时生成 AUTHORS / *.spec
            ])
            ++ libs
            ++ nixpkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              pkgs.libintl
            ];

          shellHook = ''
            echo "virt-viewer dev shell (${system})"
            echo "  meson setup build && ninja -C build"
          '' + nixpkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            # glib 头文件经 libintl.h 把 gettext 符号重命名为 libintl_*，
            # macOS 的 libc 不提供它们，链接时需显式加上 -lintl；
            # glibc 内置 gettext，Linux 无需处理。
            export LDFLAGS="-L${pkgs.libintl}/lib -Wl,-rpath,${pkgs.libintl}/lib -lintl"
          '';
        };
      });
}
