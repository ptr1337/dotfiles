#! /usr/bin/env bash

set -euo pipefail

# General vars
jobs="$(echo $(( $(nproc) * 3/4 )) | cut -d '.' -f1)"
git_dir="${HOME:?}/git"
install_prefix_root="${HOME:?}/.tools"
download_dir="${HOME:?}/Downloads"

# GCC vars
source_dir="${git_dir:?}/gcc"
build_dir="${git_dir:?}/gcc-build"
first_stage_install_prefix="${install_prefix_root:?}/gcc-stage1"
install_prefix="${install_prefix_root:?}/gcc"
release_branch="releases/gcc-11"
target_arch="native"

error() {
  echo "${*:?}" > /dev/stderr
  exit 1
}

check_gcc_executable() {
  local -r binary_path="${1:?}"
  if [ ! -x "$(readlink -m "${binary_path}")" ]; then
    error "\"${binary_path}\" is not an executable"
  fi

  if ! "${binary_path}" --version >& /dev/null; then
    error "Cannot run \"${binary_path}\" - invalid output binary"
  fi
}

check_requirements() {
  local -r build_dependencies=(
    git git-lfs base-devel wget m4 flex bison
  )
  local dependencies_to_install=()
  for dependency in "${build_dependencies[@]}"; do
    if ! paru -Qs "${dependency}" | cut -d ' ' -f1 | grep "ii" >& /dev/null; then
      dependencies_to_install=(${dependencies_to_install[@]} "${dependency}")
    fi
  done

  if [ "${#dependencies_to_install[@]}" -gt 0 ]; then
    echo "Installing GCC build dependencies:"
    sudo pacman -S --noconfirm ${dependencies_to_install[@]}
  fi

  if [ ! -d "${git_dir:?}" ]; then
    mkdir -p "${git_dir}" || error "Could not create the git dir: ${git_dir}"
  fi

  if [ ! -d "${source_dir:?}/.git" ]; then
    git clone git://gcc.gnu.org/git/gcc.git "${source_dir}" -b "${release_branch:?}" || error "Failed to clone GCC"
  fi

  if [ ! -d "${install_prefix_root:?}" ]; then
    mkdir -p "${install_prefix_root}" || error "Could not create the install root dir: ${install_prefix_root}"
  fi

  local -r git_dir_expected_space=$(( 15 * 1024 )) # 15GB
  local -r install_dir_expected_space=500 # 500MB

  local git_dir_available_space_bytes
  git_dir_available_space_bytes=$(df --output=avail "${git_dir:?}" | tail -1)
  local -r git_dir_available_space=$(( git_dir_available_space_bytes / 1024 ))

  local install_dir_available_space_bytes
  install_dir_available_space_bytes=$(df --output=avail "${install_prefix_root:?}" | tail -1)
  local -r install_dir_available_space=$(( install_dir_available_space_bytes / 1024 ))

  not_enough_space_error() {
    error "Not enough disk space inside \"${1:?}\" dir: ${2:?}MB. Required at least: ${3:?}MB"
  }

  # If it is the same partition, we need to sum up the expected space
  if [ "$(df --output=source "${git_dir:?}" | tail -1)" = "$(df --output=source "${install_prefix_root:?}" | tail -1)" ]; then
    local -r expected_space=$(( git_dir_expected_space + install_dir_expected_space ))
    if [ "${git_dir_available_space}" -lt "${expected_space}" ]; then
      not_enough_space_error "${git_dir}" ${git_dir_available_space} ${expected_space}
    fi
  else
    if [ "${git_dir_available_space}" -lt "${git_dir_expected_space}" ]; then
      not_enough_space_error "${git_dir}" ${git_dir_available_space} ${git_dir_expected_space}
    fi

    if [ "${install_dir_available_space}" -lt "${install_dir_expected_space}" ]; then
      not_enough_space_error "${install_prefix_root}" ${install_dir_available_space} ${install_dir_expected_space}
    fi
  fi
}

update_project() {
  local -r dir="${1:?}"
  local -r branch="${2:?}"
  (
    cd "${dir}" || error "Failed to change dir to: ${dir}"
    git fetch origin "${branch}"
    git clean -fdx
    git reset --hard origin/"${branch}"
  )
}

install_gcc() {
  mkdir -p "${build_dir:?}"
  cd "${build_dir}"

  rm -rf ./*
  if [ -n "${GCC_FIRST_RUN}" ]; then
    "${source_dir}/configure" \
      --prefix="${first_stage_install_prefix:?}" \
      --enable-shared \
      --enable-threads=posix \
      --enable-__cxa_atexit \
      --enable-clocale=gnu \
      --enable-languages=c,c++ \
      --enable-lto \
      --enable-plugin \
      --enable-ld=default \
      --enable-linker-build-id \
      --with-system-zlib \
      --with-gnu-ld \
      --with-ppl=yes \
      --disable-multilib \
      --disable-werror \
      --with-arch=${target_arch} \
      --with-tune=${target_arch} \
      --with-glibc-version=2.33

    make -j${jobs:?}
  else
    export PATH="${first_stage_install_prefix:?}/bin:${PATH}"
    export cflags="-O3 -DNDEBUG -fomit-frame-pointer -fno-asynchronous-unwind-tables -ftree-vectorize -floop-strip-mine -floop-block -fgraphite-identity -m64 -mavx -march=${target_arch} -mtune=${target_arch} -Wno-error=unused-variable"

    "${source_dir}/configure" \
      --prefix="${install_prefix:?}" \
      --enable-shared \
      --enable-threads=posix \
      --enable-__cxa_atexit \
      --enable-clocale=gnu \
      --enable-languages=c,c++ \
      --enable-lto \
      --enable-plugin \
      --enable-ld=default \
      --enable-linker-build-id \
      --with-system-zlib \
      --with-gnu-ld \
      --with-ppl=yes \
      --disable-multilib \
      --disable-werror \
      --with-arch=${target_arch} \
      --with-tune=${target_arch} \
      --with-glibc-version=2.33

    make -j${jobs:?} \
      CFLAGS_FOR_BUILD="${cflags}" \
      CXXFLAGS_FOR_BUILD="-fuse-cxa-atexit ${cflags}" \
      CFLAGS_FOR_TARGET="${cflags}" \
      CXXFLAGS_FOR_TARGET="-fuse-cxa-atexit ${cflags}" \
      FLAGS_FOR_TARGET="${cflags}" \
      LDFLAGS_FOR_BUILD="${cflags}" \
      BOOT_CFLAGS="${cflags}" \
      BOOT_LDFLAGS="${cflags}" \
      profiledbootstrap
  fi

  make -j${jobs:?} install-strip && rm -rf "${build_dir:?}"

  if [ -n "${GCC_FIRST_RUN}" ]; then
    check_gcc_executable "${first_stage_install_prefix:?}/bin/gcc"
    check_gcc_executable "${first_stage_install_prefix:?}/bin/g++"
  else
    check_gcc_executable "${install_prefix:?}/bin/gcc"
    check_gcc_executable "${install_prefix:?}/bin/g++"

    rm -rf "${first_stage_install_prefix:?}"
  fi
}

get_dependency() {
  local -r folder_name="${1:?}"
  local -r file_name="${2:?}"
  local -r file_name_sha256="${3:?}"
  local -r link_prefix="${4:?}"

  (
    local -r download_path="${download_dir:?}/${file_name}"
    if [ ! -f "${download_path}" ]; then
      cd "${download_dir}"
      wget "${link_prefix}${file_name}"
    fi

    local calculated_hash
    calculated_hash="$(sha256sum "${download_path}" | cut -d ' ' -f1)"
    if [ "${calculated_hash}" != "${file_name_sha256}" ]; then
      error "File: \"${download_path}\", expected hash: ${file_name_sha256}, calculated hash: ${calculated_hash}"
    fi

    cd "${source_dir}"
    rm -rf "${folder_name:?}" && mkdir -p "${folder_name}"
    cd "${folder_name}"
    tar xf "${download_path}" --strip 1 --no-same-owner
  )
}

build_gcc() {
  (
    update_project "${source_dir:?}" "${release_branch:?}"
    get_dependency "gmp"  "gmp-6.2.1.tar.xz"  "fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2" "https://gmplib.org/download/gmp/"
    get_dependency "isl"  "isl-0.24.tar.xz"   "043105cc544f416b48736fff8caf077fb0663a717d06b1113f16e391ac99ebad" "https://libisl.sourceforge.io/"
    get_dependency "mpfr" "mpfr-4.1.0.tar.xz" "0c98a3f1732ff6ca4ea690552079da9c597872d30e96ec28414ee23c95558a7f" "http://www.mpfr.org/mpfr-current/"
    get_dependency "mpc"  "mpc-1.2.1.tar.gz"  "17503d2c395dfcf106b622dc142683c1199431d095367c6aacba6eec30340459" "https://ftp.gnu.org/gnu/mpc/"

    install_gcc
  )
}

main() {
  check_requirements

  GCC_FIRST_RUN=1  build_gcc
  GCC_FIRST_RUN='' build_gcc

  echo
  echo "Finished building:"
  "${install_prefix:?}/bin/g++" --version
  echo "InstalledDir: ${install_prefix:?}/bin"
}

main "$@"
