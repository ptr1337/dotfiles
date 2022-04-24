#! /usr/bin/env bash

set -euo pipefail

# Vars set by getopts
self_pgo=false
manual_pgo_build_script_path=""

# General vars
jobs="$(echo $(( $(nproc) * 4/4 )) | cut -d '.' -f1)"
git_dir="${HOME:?}/git"
install_prefix_root="${HOME:?}/.tools"

# LLVM vars
LLVM_BRANCH=release/14.x # temporary, can comment out
llvm_source_dir="${git_dir}/llvm"
llvm_build_dir="${git_dir}/llvm-build"
llvm_branch="${LLVM_BRANCH:-release/14.x}"
first_stage_install_prefix="${install_prefix_root:?}/llvm-stage1"
second_stage_install_prefix="${install_prefix_root:?}/llvm-stage2" # instrumented build
bolt_stage_install_prefix="${install_prefix_root:?}/llvm-stage2-bolt" # bolt llvm with and without branch sampling
install_prefix="${install_prefix_root:?}/llvm"


error() {
  echo "${*:?}" > /dev/stderr
  exit 1
}

check_llvm_executable() {
  local -r binary_path="${1:?}"
  if [ ! -x "$(readlink -m "${binary_path}")" ]; then
    error "\"${binary_path}\" is not an executable"
  fi

  if ! "${binary_path}" --version >& /dev/null; then
    error "Cannot run \"${binary_path}\" - invalid output binary"
  fi
}

install_ubuntu_dep() {
  local -r build_dependencies=(
    git git-lfs gcc g++ build-essential cmake ninja-build
    libpython3-dev libxml2-dev liblzma-dev libedit-dev python3-sphinx swig
  )

  local dependencies_to_install=()
  for dependency in "${build_dependencies[@]}"; do
    if ! dpkg -l "${dependency}" | cut -d ' ' -f1 | grep "ii" >& /dev/null; then
      # shellcheck disable=SC2206
      dependencies_to_install=(${dependencies_to_install[@]} "${dependency}")
    fi
  done

  if [ "${#dependencies_to_install[@]}" -gt 0 ]; then
    echo "Installing LLVM build dependencies:"
    # shellcheck disable=SC2068
    sudo apt install ${dependencies_to_install[@]} -yqq # intentional word splitting
  fi
}

install_fedora_dep() {
  local -r build_dependencies=(
    git git-lfs gcc cmake ninja-build
    python3-devel libxml2-devel xz-devel libedit-devel python3-sphinx swig
  )

  local dependencies_to_install=()
  for dependency in "${build_dependencies[@]}"; do
    local installed_pkg="$(dnf list installed "${dependency}" -q | cut -d' ' -f1 | grep "${dependency}")"
    if [ "${installed_pkg}" = "" ]; then
      # shellcheck disable=SC2206
      dependencies_to_install=(${dependencies_to_install[@]} "${dependency}")
    fi
  done

  if [ "${#dependencies_to_install[@]}" -gt 0 ]; then
    echo "Installing LLVM build dependencies:"
    # shellcheck disable=SC2068
    sudo dnf install ${dependencies_to_install[@]} -y # intentional word splitting
  fi
}

install_cachyos_dep() {
  local -r build_dependencies=(
    git git-lfs cmake ninja python-sphinx swig
  )

  local dependencies_to_install=()
  for dependency in "${build_dependencies[@]}"; do
    if ! paru -Qs "${dependency}" | cut -d ' ' -f1 | grep "ii" >& /dev/null; then
      # shellcheck disable=SC2206
      dependencies_to_install=(${dependencies_to_install[@]} "${dependency}")
    fi
  done

  if [ "${#dependencies_to_install[@]}" -gt 0 ]; then
    echo "Installing LLVM build dependencies:"
    # shellcheck disable=SC2068
    sudo pacman -S --noconfirm ${dependencies_to_install[@]}  # intentional word splitting
  fi
}

check_requirements() {
  local -r distro="$(cat /etc/os-release | grep "^ID=" | cut -d'=' -f2-)"

  # Ubuntu dependencies
  if [ "$(echo "${distro}" | grep -i ubuntu)" != "" ]; then
    install_ubuntu_dep
  fi

  # Fedora dependencies
  if [ "$(echo "${distro}" | grep -i fedora)" != "" ]; then
    install_fedora_dep
  fi

  # CachyOS dependencies
  if [ "$(echo "${distro}" | grep -i cachyos)" != "" ]; then
    install_cachyos_dep
  fi

  # CachyOS dependencies
  if [ "$(echo "${distro}" | grep -i archlinux)" != "" ]; then
    install_cachyos_dep
  fi

  if [ ! -d "${git_dir:?}" ]; then
    mkdir -p "${git_dir}" || error "Could not create the git dir: ${git_dir}"
  fi

  if [ ! -d "${llvm_source_dir:?}/.git" ]; then
    git clone https://github.com/llvm/llvm-project.git "${llvm_source_dir}" -b "${llvm_branch:?}" || error "Failed to clone LLVM"
  fi

  if [ ! -d "${install_prefix_root:?}" ]; then
    mkdir -p "${install_prefix_root}" || error "Could not create the install root dir: ${install_prefix_root}"
  fi

  local -r git_dir_expected_space=$(( 15 * 1024 )) # 15GB
  local -r install_dir_expected_space=$(( 4 * 1024 )) # 4GB

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
    #    git revert --no-edit 2edb89c746848c52964537268bf03e7906bf2542 # temp fix for Clang 14 Lexer regression
  )
}

install_llvm() {
  mkdir -p "${llvm_build_dir:?}" || error "Failed to create the build dir: ${llvm_build_dir}"
  cd "${llvm_build_dir}" || error "Failed to change dir to: ${llvm_build_dir}"

  rm -rf ./*
  if [ ${LLVM_BUILD_STAGE} = 1 ]; then
    cmake "${llvm_source_dir:?}/llvm" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS:STRING="clang;lld;compiler-rt;bolt" \
      -DCMAKE_C_COMPILER=/usr/bin/gcc \
      -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
      -DCMAKE_RANLIB=/usr/bin/ranlib \
      -DCMAKE_AR=/usr/bin/ar \
      -DLLVM_TARGETS_TO_BUILD:STRING=Native \
      -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
      -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
      -DCOMPILER_RT_BUILD_XRAY=OFF \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_ENABLE_BACKTRACES=OFF \
      -DLLVM_ENABLE_WARNINGS=OFF \
      -DLLVM_BUILD_EXAMPLES=OFF \
      -DCMAKE_INSTALL_PREFIX="${first_stage_install_prefix:?}" \
      -G Ninja
  fi

  if [ ${LLVM_BUILD_STAGE} = 2 ]; then
    cmake "${llvm_source_dir:?}/llvm" \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PROJECTS:STRING="clang;clang-tools-extra;compiler-rt;lld;lldb;bolt;polly" \
      -DCMAKE_C_COMPILER="${first_stage_install_prefix:?}/bin/clang" \
      -DCMAKE_CXX_COMPILER="${first_stage_install_prefix:?}/bin/clang++" \
      -DCMAKE_RANLIB="${first_stage_install_prefix:?}/bin/llvm-ranlib" \
      -DCMAKE_AR="${first_stage_install_prefix:?}/bin/llvm-ar" \
      -DCMAKE_CXX_FLAGS="-O3 -march=native -m64 -mavx -fomit-frame-pointer" \
      -DCMAKE_C_FLAGS="-O3 -march=native -m64 -mavx -fomit-frame-pointer" \
      -DCMAKE_EXE_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1 -Wl,--emit-relocs" \
      -DCMAKE_MODULE_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1 -Wl,--emit-relocs" \
      -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1 -Wl,--emit-relocs" \
      -DLLVM_TARGETS_TO_BUILD:STRING=Native \
      -DENABLE_LINKER_BUILD_ID=ON \
      -DLLVM_BUILD_LLVM_DYLIB=ON \
      -DLLVM_ENABLE_LLD=ON \
      -DLLVM_ENABLE_PIC=ON \
      -DLLVM_ENABLE_RTTI=ON \
      -DLLVM_BINUTILS_INCDIR=/usr/include \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
      -DLLVM_ENABLE_WARNINGS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_BUILD_EXAMPLES=OFF \
      -DLLVM_INSTALL_UTILS=ON \
      -DCMAKE_INSTALL_PREFIX="${install_prefix:?}" \
      -C "${llvm_source_dir}/clang/cmake/caches/PGO.cmake" \
      -G Ninja

    ninja -j${jobs} stage2
  fi

  ninja -j${jobs} install && rm -rf "${llvm_build_dir:?}"


  if [ ${LLVM_BUILD_STAGE} = 3 ]; then

    perf record -e cycles:u -j any,u -- sleep 1 &>/dev/null;
    if [[ $? == "0" ]]; then
      echo "BOLTING with Profile!"
      ./build_stage3-bolt.bash || (echo "Optimizing Stage2-Toolchain further with llvm-bolt failed!"; exit 1)

      cmake "${llvm_source_dir:?}/llvm" \
        -DLLVM_BINUTILS_INCDIR=/usr/include \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="${install_prefix:?}/bin/clang" \
        -DCMAKE_CXX_COMPILER="${install_prefix:?}/bin/clang++" \
        -DCMAKE_RANLIB="${install_prefix:?}/bin/llvm-ranlib" \
        -DCMAKE_AR="${install_prefix:?}/bin/llvm-ar" \
        -DLLVM_ENABLE_PROJECTS="clang" \
        -DCMAKE_CXX_FLAGS="-O3 -march=native -m64 -mavx -fomit-frame-pointer" \
        -DCMAKE_C_FLAGS="-O3 -march=native -m64 -mavx -fomit-frame-pointer" \
        -DLLVM_TARGETS_TO_BUILD:STRING=Native \
        -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
        -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
        -DCOMPILER_RT_BUILD_XRAY=OFF \
        -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_ENABLE_WARNINGS=OFF \
        -DLLVM_BUILD_EXAMPLES=OFF \
        -DCMAKE_INSTALL_PREFIX="${bolt_stage_install_prefix:?}" \
        -G ninja

      perf record -o ${TOPLEV}/perf.data --max-size=10G -F 1500 -e cycles:u -j any,u -- ninja clang

      ${first_stage_install_prefix:?}/perf2bolt ${CPATH}/clang-15 \
        -p ${install_prefix_root:?}/perf.data \
        -o ${install_prefix_root:?}/clang-15.fdata || (echo "Could not convert perf-data to bolt for clang-15"; exit 1)

      echo "Optimizing Clang with the generated profile"

      ${first_stage_install_prefix:?}/llvm-bolt ${install_prefix:?}/clang-15 \
        -o ${install_prefix:?}/clang-15.bolt \
        --data ${install_prefix_root:?}/clang-15.fdata \
        -reorder-blocks=cache+ \
        -reorder-functions=hfsort+ \
        -split-functions=3 \
        -split-all-cold \
        -dyno-stats \
        -icf=1 \
        -use-gnu-stack
    else

      echo "Optimizing Stage2-Toolchain with instrumenting"
      echo "Instrument clang with llvm-bolt"

      mkdir ${bolt_stage_install_prefix:?}/intrumentdata

      ${first_stage_install_prefix:?}/llvm-bolt \
        --instrument \
        --instrumentation-file-append-pid \
        --instrumentation-file=${bolt_stage_install_prefix:?}/intrumentdata/clang-15.fdata \
        ${install_prefix:?}/clang-15 \
        -o ${install_prefix:?}/clang-15.inst

      mv ${install_prefix:?}/clang-15 ${install_prefix:?}/clang-15.org
      mv ${install_prefix:?}/clang-15.inst ${install_prefix:?}/clang-15

      cmake "${llvm_source_dir:?}/llvm" \
        -DLLVM_BINUTILS_INCDIR=/usr/include \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="${install_prefix:?}/bin/clang" \
        -DCMAKE_CXX_COMPILER="${install_prefix:?}/bin/clang++" \
        -DCMAKE_RANLIB="${install_prefix:?}/bin/llvm-ranlib" \
        -DCMAKE_AR="${install_prefix:?}/bin/llvm-ar" \
        -DLLVM_ENABLE_PROJECTS="clang" \
        -DCMAKE_CXX_FLAGS="-O3 -march=native -m64 -mavx -fomit-frame-pointer" \
        -DCMAKE_C_FLAGS="-O3 -march=native -m64 -mavx -fomit-frame-pointer" \
        -DLLVM_TARGETS_TO_BUILD:STRING=Native \
        -DCMAKE_POLICY_DEFAULT_CMP0069=NEW \
        -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
        -DCOMPILER_RT_BUILD_XRAY=OFF \
        -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
        -DLLVM_ENABLE_RTTI=ON \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_ENABLE_WARNINGS=OFF \
        -DLLVM_BUILD_EXAMPLES=OFF \
        -DCMAKE_INSTALL_PREFIX="${bolt_stage_install_prefix:?}" \
        -G ninja

      echo "== Start Training Build"
      ninja & read -t 180 || kill $!

      echo "Merging generated profiles"
      cd ${TOPLEV}/build/llvm/stage3-without-sampling/intrumentdata
      ${first_stage_install_prefix:?}/merge-fdata ${bolt_stage_install_prefix:?}/intrumentdata/*.fdata > ${install_prefix_root:?}/combined.fdata
      echo "Optimizing Clang with the generated profile"

      ${TOPLEV}/build/llvm/stage1/bin/llvm-bolt ${CPATH}/clang-15.org \
        --data ${install_prefix_root:?}/combined.fdata \
        -o ${install_prefix:?}/clang-15 \
        -reorder-blocks=cache+ \
        -reorder-functions=hfsort+ \
        -split-functions=3 \
        -split-all-cold \
        -dyno-stats \
        -icf=1 \
        -use-gnu-stack || (echo "Could not optimize binary for clang-15"; exit 1)
    fi
  fi

  if [ -n "${LLVM_BUILD_STAGE}" ]; then
    check_llvm_executable "${first_stage_install_prefix:?}/bin/clang"
    check_llvm_executable "${first_stage_install_prefix:?}/bin/clang++"
  else
    check_llvm_executable "${install_prefix:?}/bin/clang"
    check_llvm_executable "${install_prefix:?}/bin/clang++"

    rm -rf "${first_stage_install_prefix:?}"
  fi
}


build_llvm() {
  (
    install_llvm
  )
}

main() {
  check_requirements
  update_project "${llvm_source_dir:?}" "${llvm_branch:?}"
  LLVM_BUILD_STAGE=1  build_llvm "$@"
  LLVM_BUILD_STAGE=2 build_llvm "$@"
  LLVM_BUILD_STAGE=2 build_llvm "$@"

  echo
  echo "Finished building:"
  "${install_prefix:?}/bin/clang++" --version
}

usage() {
  printf "%s <option>\n\n" "$(basename "${0}")"
  printf "option:\n"
  printf "\t-s\n\t  Self PGO. Optimize Clang by compiling Clang itself with the instrumented code\n\n"
  printf "\t-m\n\t  Manual PGO. Pass a project build script that uses env variables CC/CXX to be used to optimize Clang\n\n"
}

if getopts ":sm:" opt; then
  case $opt in
    s)
      self_pgo=true
      ;;
    m)
      manual_pgo_build_script_path="$(readlink -m "$OPTARG")"
      if [ ! -x "${manual_pgo_build_script_path}" ]; then
        error "\"${manual_pgo_build_script_path}\" is not an executable file/script"
      fi

      error "Manual PGO is not supported yet"
      ;;
    :)
      error "-$OPTARG requires a path to a build script"
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
fi

if [ $OPTIND -eq 1 ]; then
  usage
  exit 1
fi

main "$@"
