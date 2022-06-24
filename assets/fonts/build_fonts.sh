#!/bin/bash

set -euo pipefail

build_dir="build"

iosevka_ver="v15.5.1"
inter_ver="v3.19"
crimson_ver="fonts-october2014"

iosevka_build_dir="$build_dir/iosevka-$iosevka_ver"
inter_build_dir="$build_dir/inter-$inter_ver"
crimson_build_dir="$build_dir/crimson-$crimson_ver"

iosevka_install_dir="iosevka-extended"
inter_install_dir="inter-display"
crimson_install_dir="crimson-pro"

download() {
  local url="$1"
  local dir="$2"

  if [ ! -d "$dir" ]; then
    mkdir -p "$dir-tmp"
    curl -fsSL "$url" | tar -xzC "$dir-tmp" --strip-components=1
    mv "$dir-tmp" "$dir"
  fi
}

major_version() {
  local str="$1"
  echo "$(cut -d. -f1 <<< ${str#v})"
}

build_iosevka() {
  local dir="$1"
  cp "private-build-plans.toml" "$dir/private-build-plans.toml"
  ( cd $dir && npm install )
  ( cd $dir && ( npm run build -- webfont::iosevka-extended; echo ) )
  mkdir -p "$iosevka_install_dir"
  cp "$dir"/dist/iosevka-extended/woff2/iosevka-extended-*.woff2 "$iosevka_install_dir"
  cp "$dir/LICENSE.md" "$iosevka_install_dir"
}

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p "$build_dir"
echo '*' > "$build_dir/.gitignore"

# Test for dependencies

[ "$(major_version $(node --version))" -gt "14" ] || \
  { echo "NodeJS 14.0 or later is required for Iosevka"; exit 1; }
command -v ttfautohint > /dev/null || { echo "ttfautohint is required for Iosevka"; exit 1; }

# Download fonts

echo "Downloading Iosevka..."
download "https://github.com/be5invis/Iosevka/archive/refs/tags/$iosevka_ver.tar.gz" "$iosevka_build_dir"

echo "Downloading Inter..."
download "https://github.com/rsms/inter/archive/refs/tags/$inter_ver.tar.gz" "$inter_build_dir"

echo "Downloading Crimson Pro..."
download "https://github.com/Fonthausen/CrimsonPro/archive/refs/tags/$crimson_ver.tar.gz" "$crimson_build_dir"

# Build Iosevka
echo "Building Iosevka..."
build_iosevka "$iosevka_build_dir"
