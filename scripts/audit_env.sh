#!/usr/bin/env bash
set -euo pipefail

# === 設定 ===
TS="$(date +%Y%m%d-%H%M%S)"
OUTDIR="${HOME}/analysis/audit/${TS}"
mkdir -p "${OUTDIR}"

# 作業ディレクトリ（ホストごと）
MAC_DIR="${HOME}/analysis"
SCHOOL_DIR="/megraid01/users/takatsu_t/teto"
NAS_DIR="/home/teto/mirror"

HOSTS=("local" "school" "nas-lan")

# === 共通関数 ===
run_local() { bash -lc "$1"; }
run_remote() { local host="$1"; ssh -o BatchMode=yes "$host" "bash -lc '$2'"; }

audit_block='
set -euo pipefail

echo "=== BASIC ==="
echo "DATE: $(date)"
echo "HOST: $(hostname)"
echo "USER: $(id -un)"
echo "SHELL: $SHELL"
echo

echo "=== OS ==="
uname -a || true
if command -v sw_vers >/dev/null 2>&1; then
  sw_vers || true
fi
if [ -r /etc/os-release ]; then
  cat /etc/os-release || true
fi
echo

echo "=== CPU/MEM ==="
if command -v sysctl >/dev/null 2>&1; then
  sysctl -n machdep.cpu.brand_string 2>/dev/null || true
  echo "NCores: $(sysctl -n hw.ncpu 2>/dev/null || echo NA)"
fi
if command -v lscpu >/dev/null 2>&1; then
  lscpu | egrep "Model name|CPU\\(s\\)|Thread|Core" || true
else
  nproc --all 2>/dev/null && echo "nproc above" || true
fi
free -h 2>/dev/null || vm_stat 2>/dev/null || true
echo

echo "=== DISK ==="
df -h || true
echo

echo "=== ENV (ROOT/PATH) ==="
env | egrep "^(ROOT|LD_LIBRARY_PATH|DYLD_LIBRARY_PATH|PATH)=" || true
echo

echo "=== TOOLS (versions) ==="
for cmd in gcc g++ clang clang++ cmake ninja make root-config git git-lfs rsync tmux ccache clang-format clang-tidy clangd python3 pip3; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "%-12s: " "$cmd"
    "$cmd" --version 2>/dev/null | head -n 1 || "$cmd" -V 2>/dev/null | head -n 1 || true
  else
    printf "%-12s: NOT FOUND\n" "$cmd"
  fi
done
echo

echo "=== ROOT ==="
if command -v root-config >/dev/null 2>&1; then
  echo "root-config --version: $(root-config --version)"
  echo "root-config --features: $(root-config --features || true)"
  echo "CFLAGS: $(root-config --cflags)"
  echo "LIBS  : $(root-config --libs)"
fi
echo

echo "=== PYTHON PACKAGES ==="
if command -v python3 >/dev/null 2>&1; then
python3 - <<PY
pkgs = ["uproot","awkward","pandas","numpy","matplotlib"]
import importlib, sys
for p in pkgs:
    try:
        m = importlib.import_module(p)
        v = getattr(m, "__version__", "unknown")
        print(f"{p:12s}: OK ({v})")
    except Exception as e:
        print(f"{p:12s}: MISSING")
PY
fi
echo
'

# === ホスト別追加: 作業ディレクトリ確認 & 簡易書込みテスト ===
audit_dir_check() {
  cat <<'EOS'
echo "=== WORKDIR CHECK ==="
echo "WDIR: ${WDIR}"
if [ -d "${WDIR}" ]; then
  echo "exists: YES"
  if [ -w "${WDIR}" ]; then
    echo "writable: YES"
    touch "${WDIR}/.__audit_write_test__" && echo "touch: OK" || echo "touch: FAIL"
    rm -f "${WDIR}/.__audit_write_test__" || true
  else
    echo "writable: NO"
  fi
else
  echo "exists: NO"
fi
echo
EOS
}
# === （任意）簡易 ROOT リンクテスト ===
root_link_test='
if command -v root-config >/dev/null 2>&1 && command -v g++ >/dev/null 2>&1; then
  echo "=== QUICK ROOT LINK TEST ==="
  td="$(mktemp -d)"
  cat > "${td}/check_root.cpp" <<CPP
#include <iostream>
#include <TROOT.h>
int main(){
  std::cout << "ROOT version from TROOT: " << gROOT->GetVersion() << std::endl;
  return 0;
}
CPP
  g++ $(root-config --cflags) "${td}/check_root.cpp" -o "${td}/check_root" $(root-config --libs) && echo "BUILD: OK" || echo "BUILD: FAIL"
  if [ -x "${td}/check_root" ]; then
    "${td}/check_root" || true
  fi
  rm -rf "${td}"
  echo
fi
'
# === 実行 ===
for host in "${HOSTS[@]}"; do
  case "$host" in
    local)
      echo "[*] Auditing: local (Mac)" | tee "${OUTDIR}/local.log"
      {
        # ← ここで「子シェルに渡すスクリプト」を組み立てる
        printf 'WDIR=%q\n' "${MAC_DIR}"
        printf '%s\n' "$audit_block"
        audit_dir_check "${MAC_DIR}"        # ★ evalは使わない（そのまま展開して渡す）
        printf '%s\n' "$root_link_test"
      } | bash -l 2>&1 | tee -a "${OUTDIR}/local.log"   # ★ 「-lc」ではなく「-l」で標準入力を実行
      ;;

    school)
      echo "[*] Auditing: school" | tee "${OUTDIR}/school.log"
      # ★ リモートは「bash -lc '<文字列>'」で実行させるので、コマンド文字列を組み立てる
      REMOTE_CMD="$(printf "WDIR=%q\n%s\n%s\n%s\n" \
        "${SCHOOL_DIR}" \
        "$audit_block" \
        "$(audit_dir_check "${SCHOOL_DIR}")" \
        "$root_link_test")"
      run_remote school "$REMOTE_CMD" 2>&1 | tee -a "${OUTDIR}/school.log"
      ;;

    nas-lan)
      echo "[*] Auditing: nas-lan" | tee "${OUTDIR}/nas-lan.log"
      REMOTE_CMD="$(printf "WDIR=%q\n%s\n%s\n" \
        "${NAS_DIR}" \
        "$audit_block" \
        "$(audit_dir_check "${NAS_DIR}")")"
      run_remote nas-lan "$REMOTE_CMD" 2>&1 | tee -a "${OUTDIR}/nas-lan.log"
      ;;
  esac
done

echo
echo "===> Reports saved to: ${OUTDIR}"
