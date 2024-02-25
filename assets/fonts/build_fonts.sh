#!/bin/bash

set -euo pipefail

build_dir="build"

inter_ver="v4.0"
jetbrains_ver="v2.304"

inter_build_dir="$build_dir/inter-$inter_ver"
jetbrains_build_dir="$build_dir/jetbrains-$jetbrains_ver"

inter_install_dir="inter"
jetbrains_install_dir="jetbrains-mono"

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

build_inter() {
  local dir="$1"
  (
    cd $dir
    # Make a hinted web font
    sed -i '' '/^STATIC_FONTS_WEB/ s$/static/$/static-hinted/$' Makefile
    make static_web -j
  )
  mkdir -p "$inter_install_dir"
  cp "$dir"/build/fonts/static-hinted/Inter-Regular.woff2 "$inter_install_dir/inter-regular.woff2"
  cp "$dir"/build/fonts/static-hinted/Inter-Italic.woff2 "$inter_install_dir/inter-italic.woff2"
  cp "$dir"/build/fonts/static-hinted/Inter-Bold.woff2 "$inter_install_dir/inter-bold.woff2"
  cp "$dir"/build/fonts/static-hinted/Inter-BoldItalic.woff2 "$inter_install_dir/inter-bolditalic.woff2"
  cp "$dir"/build/fonts/static-hinted/InterDisplay-Regular.woff2 "$inter_install_dir/inter-display-regular.woff2"
  cp "$dir"/build/fonts/static-hinted/InterDisplay-Italic.woff2 "$inter_install_dir/inter-display-italic.woff2"
  cp "$dir"/build/fonts/static-hinted/InterDisplay-Bold.woff2 "$inter_install_dir/inter-display-bold.woff2"
  cp "$dir"/build/fonts/static-hinted/InterDisplay-BoldItalic.woff2 "$inter_install_dir/inter-display-bolditalic.woff2"
  cp "$dir/LICENSE.txt" "$inter_install_dir/LICENSE.txt"
}

build_jetbrains() {
  local dir="$1"
  # Jetbrains is already prebuilt in the GitHub repo
  mkdir -p "$jetbrains_install_dir"
  cp "$dir"/fonts/webfonts/JetBrainsMono-Regular.woff2 "$jetbrains_install_dir/jetbrains-mono-regular.woff2"
  cp "$dir"/fonts/webfonts/JetBrainsMono-Italic.woff2 "$jetbrains_install_dir/jetbrains-mono-italic.woff2"
  cp "$dir"/fonts/webfonts/JetBrainsMono-Bold.woff2 "$jetbrains_install_dir/jetbrains-mono-bold.woff2"
  cp "$dir"/fonts/webfonts/JetBrainsMono-BoldItalic.woff2 "$jetbrains_install_dir/jetbrains-mono-bolditalic.woff2"
  cp "$dir/OFL.txt" "$jetbrains_install_dir/LICENSE.txt"
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

command -v python3 > /dev/null || { echo "python3 is required to build Inter"; exit 1; }

# Download fonts

echo "Downloading Inter..."
download "https://github.com/rsms/inter/archive/refs/tags/$inter_ver.tar.gz" "$inter_build_dir"

echo "Downloading JetBrains Mono..."
download "https://github.com/JetBrains/JetBrainsMono/archive/refs/tags/$jetbrains_ver.tar.gz" "$jetbrains_build_dir"

# Build fonts

echo "Building Inter..."
build_inter "$inter_build_dir"

echo "Building JetBrains Mono..."
build_jetbrains "$jetbrains_build_dir"

# Compress fonts

echo "Downloading pyftsubset..."
create_subset_venv "$venv_dir"

echo "Minimising Inter..."
subset "$inter_install_dir"

echo "Minimising JetBrains Mono..."
subset "$jetbrains_install_dir"
