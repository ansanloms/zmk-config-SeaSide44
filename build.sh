#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
DOCKER_IMAGE="zmkfirmware/zmk-build-arm:3.5"

mkdir -p "${DIST_DIR}"

# build.yaml から各ビルドターゲットを読み取る。
# 各 include エントリを (board, shield, snippet) の組として処理する。
builds=()
current_board=""
current_shield=""
current_snippet=""

while IFS= read -r line; do
  if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]*board:[[:space:]]*(.*) ]]; then
    if [[ -n "${current_board}" ]]; then
      builds+=("${current_board}|${current_shield}|${current_snippet}")
    fi
    current_board="${BASH_REMATCH[1]}"
    current_shield=""
    current_snippet=""
  elif [[ "${line}" =~ ^[[:space:]]*shield:[[:space:]]*(.*) ]]; then
    current_shield="${BASH_REMATCH[1]}"
  elif [[ "${line}" =~ ^[[:space:]]*snippet:[[:space:]]*(.*) ]]; then
    current_snippet="${BASH_REMATCH[1]}"
  fi
done < "${SCRIPT_DIR}/build.yaml"

if [[ -n "${current_board}" ]]; then
  builds+=("${current_board}|${current_shield}|${current_snippet}")
fi

echo "=== ZMK ローカルビルド ==="
echo "ビルドターゲット数: ${#builds[@]}"
echo ""

for entry in "${builds[@]}"; do
  IFS='|' read -r board shield snippet <<< "${entry}"

  if [[ -n "${shield}" ]]; then
    artifact_name="${shield// /-}-${board}"
  else
    artifact_name="${board}"
  fi

  echo "--- ビルド: ${artifact_name} ---"
  echo "  board:   ${board}"
  echo "  shield:  ${shield:-（なし）}"
  echo "  snippet: ${snippet:-（なし）}"

  # west build コマンドを組み立てる
  build_cmd="west build -s zmk/app -d /tmp/build -p always -b ${board}"

  if [[ -n "${snippet}" ]]; then
    build_cmd="${build_cmd} -S ${snippet}"
  fi

  # CI の build-user-config.yml と同様の構成:
  # - config を一時ディレクトリにコピーして Zephyr クローンとの衝突を回避
  # - -DZMK_EXTRA_MODULES で元リポジトリの zephyr/module.yml を参照
  cmake_args="-DZMK_CONFIG=/tmp/zmk-config/config"
  cmake_args="${cmake_args} -DZMK_EXTRA_MODULES=/workspace"
  if [[ -n "${shield}" ]]; then
    cmake_args="${cmake_args} -DSHIELD=\"${shield}\""
  fi

  build_cmd="${build_cmd} -- ${cmake_args}"

  docker run --rm \
    -v "${SCRIPT_DIR}:/workspace:ro" \
    -v "${DIST_DIR}:/dist" \
    "${DOCKER_IMAGE}" \
    /bin/bash -c "
      git config --global --add safe.directory '*'

      mkdir -p /tmp/zmk-config/config
      cp -R /workspace/config/* /tmp/zmk-config/config/

      cd /tmp/zmk-config
      west init -l config 2>/dev/null || true
      west update
      west zephyr-export
      ${build_cmd}

      if [ -f /tmp/build/zephyr/zmk.uf2 ]; then
        cp /tmp/build/zephyr/zmk.uf2 /dist/${artifact_name}.uf2
        echo '==> ビルド成功: ${artifact_name}.uf2'
      else
        echo '==> 警告: .uf2 ファイルが生成されなかった'
        exit 1
      fi
    "

  echo ""
done

echo "=== ビルド完了 ==="
ls -lh "${DIST_DIR}"/*.uf2 2>/dev/null || echo "出力ファイルなし"
