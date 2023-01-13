#!/bin/bash

set -euo pipefail

build_dir="build"

iosevka_ver="v15.6.3"
inter_ver="v3.19"
crimson_ver="f21e0a4"

iosevka_build_dir="$build_dir/iosevka-$iosevka_ver"
inter_build_dir="$build_dir/inter-$inter_ver"
crimson_build_dir="$build_dir/crimson-$crimson_ver"

iosevka_install_dir="iosevka-extended"
inter_install_dir="inter-display"
crimson_install_dir="crimson-pro"

venv_dir="$build_dir/.venv"
subset_requirements="subset-requirements.txt"
subset_range="0-24F,259,2BB-2BC,2C6,2DA,2DC,1E00-1EFF,2000-206F,2074,20A0-20CF,2113,2122,2191,2193,2212,2215,2C60-2C7F,A720-A7FF,FEFF,FFFD"

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
  cp "$dir/LICENSE.md" "$iosevka_install_dir/LICENSE.md"
}

build_inter() {
  local dir="$1"
  (
    cd $dir
    # Update version so build doesn't fail without Python2
    sed -i 's/skia-pathops==0\.6\.0\.post2/skia-pathops==0.7.*/' requirements.txt
    sed -i 's/cu2qu==1\.6\.7$/cu2qu==1.6.7.post1/' requirements.txt
    ./init.sh
    make all_web_hinted_display -j
  )
  mkdir -p "$inter_install_dir"
  cp "$dir"/build/fonts/const-hinted/InterDisplay-Regular.woff2 "$inter_install_dir/inter-display-regular.woff2"
  cp "$dir"/build/fonts/const-hinted/InterDisplay-Italic.woff2 "$inter_install_dir/inter-display-italic.woff2"
  cp "$dir"/build/fonts/const-hinted/InterDisplay-Bold.woff2 "$inter_install_dir/inter-display-bold.woff2"
  cp "$dir"/build/fonts/const-hinted/InterDisplay-BoldItalic.woff2 "$inter_install_dir/inter-display-bolditalic.woff2"
  cp "$dir/LICENSE.txt" "$inter_install_dir/LICENSE.txt"
}

build_crimson() {
  local dir="$1"
  (
    cd $dir
    make build -j
  )
  mkdir -p "$crimson_install_dir"
  cp "$dir"/fonts/webfonts/CrimsonPro-Light.woff2 "$crimson_install_dir/crimson-pro-regular.woff2"
  cp "$dir"/fonts/webfonts/CrimsonPro-LightItalic.woff2 "$crimson_install_dir/crimson-pro-italic.woff2"
  cp "$dir"/fonts/webfonts/CrimsonPro-Medium.woff2 "$crimson_install_dir/crimson-pro-bold.woff2"
  cp "$dir"/fonts/webfonts/CrimsonPro-MediumItalic.woff2 "$crimson_install_dir/crimson-pro-bolditalic.woff2"
  cp "$dir/OFL.txt" "$crimson_install_dir/LICENSE.txt"
}

create_subset_venv () {
  local dir="$1"
  test -f "$dir/bin/activate" || python3 -m virtualenv "$dir"
  source "$dir/bin/activate"
  trap deactivate EXIT
  python3 -m pip install -r "$subset_requirements"
}

subset() {
  local dir="$1"
  for f in "$dir"/*.woff2; do
    pyftsubset "$f" --unicodes="$subset_range" --flavor=woff2
    rm "$f"
    mv "${f%.woff2}.subset.woff2" "$f"
  done
}

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p "$build_dir"
echo '*' > "$build_dir/.gitignore"

# Test for dependencies

[ "$(major_version $(node --version))" -gt "14" ] || \
  { echo "NodeJS 14.0 or later is required for Iosevka"; exit 1; }
command -v ttfautohint > /dev/null || { echo "ttfautohint is required for Iosevka"; exit 1; }
command -v python3 > /dev/null || { echo "python3 is required for Crimson Pro and Inter"; exit 1; }
command -v yq > /dev/null || { echo "yq is required for Crimson Pro"; exit 1; }

# Download fonts

echo "Downloading Iosevka..."
download "https://github.com/be5invis/Iosevka/archive/refs/tags/$iosevka_ver.tar.gz" "$iosevka_build_dir"

echo "Downloading Inter..."
download "https://github.com/rsms/inter/archive/refs/tags/$inter_ver.tar.gz" "$inter_build_dir"

echo "Downloading Crimson Pro..."
# download "https://github.com/Fonthausen/CrimsonPro/archive/refs/tags/$crimson_ver.tar.gz" "$crimson_build_dir"
download "https://github.com/Fonthausen/CrimsonPro/tarball/$crimson_ver" "$crimson_build_dir"

# Build fonts

echo "Building Iosevka..."
build_iosevka "$iosevka_build_dir"

echo "Building Inter..."
build_inter "$inter_build_dir"

echo "Building Crimson Pro..."
build_crimson "$crimson_build_dir"

# Compress fonts

echo "Downloading pyftsubset..."
create_subset_venv "$venv_dir"

echo "Minimising Iosevka..."
subset "$iosevka_install_dir"

echo "Minimising Inter..."
subset "$inter_install_dir"

echo "Minimising Crimson Pro..."
subset "$crimson_install_dir"
