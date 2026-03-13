#!/usr/bin/env bash
# push-vllm-to-quay.sh — Set 1: particionar imagen Docker vLLM en chunks ≤7GB y subir a Quay.
# Exporta la imagen a tar, la parte en chunks, construye una imagen por chunk y hace push.
# Libera espacio: borra el tar y cada chunk tras subirlo.
# Uso: ./push-vllm-to-quay.sh --vllm-image IMAGE
set -euo pipefail

QUAY_REGISTRY="quay.io/redhat_dti"
VLLM_IMAGE_NAME="multus-cni"
TAG_MIN=35
TAG_MAX=45
MAX_TAGS_VLLM=$((TAG_MAX - TAG_MIN + 1))
MAX_PART_BYTES=$((7000 * 1024 * 1024))

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VLLM_SOURCE_IMAGE=""

CONTAINER_CMD=""
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Se necesita 'podman' o 'docker'." >&2
  exit 1
fi

tag_for_index() {
  local i="$1"
  if [[ "$i" -lt 1 ]] || [[ "$i" -gt "$MAX_TAGS_VLLM" ]]; then
    echo "ERROR: Índice $i fuera de rango (1 a $MAX_TAGS_VLLM)." >&2
    return 1
  fi
  echo "v0.$((TAG_MIN + i - 1))"
}

usage() {
  cat << EOF
Uso: $0 --vllm-image IMAGE

  --vllm-image IMAGE   Imagen vLLM local; se exporta a tar, se parte en chunks de 7GB
                       y se sube como ${QUAY_REGISTRY}/${VLLM_IMAGE_NAME}:v0.${TAG_MIN}..v0.${TAG_MAX}
  -h, --help           Esta ayuda.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vllm-image)  VLLM_SOURCE_IMAGE="$2"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$VLLM_SOURCE_IMAGE" ]]; then
  echo "ERROR: Indique --vllm-image IMAGE." >&2
  usage >&2
  exit 1
fi

quay_login() {
  echo "Login en $QUAY_REGISTRY (se pedirá contraseña de forma interactiva)."
  $CONTAINER_CMD login "$QUAY_REGISTRY" -u redhat_dti
}

main() {
  quay_login

  local work_dir="${SCRIPT_DIR}/.vllm-chunks"
  trap "rm -rf '${work_dir}'" EXIT
  rm -rf "$work_dir"
  mkdir -p "$work_dir"
  local tar_path="${work_dir}/vllm.tar"

  echo "[vLLM] Exportando imagen a tar: $VLLM_SOURCE_IMAGE"
  $CONTAINER_CMD save -o "$tar_path" "$VLLM_SOURCE_IMAGE"
  echo "[vLLM] Partiendo tar en chunks de 7GB..."
  (cd "$work_dir" && split -b "$MAX_PART_BYTES" -a 2 vllm.tar vllm-chunk-)
  rm -f "$tar_path"
  echo "[vLLM] Tar eliminado para liberar espacio."

  local chunks
  chunks=("$work_dir"/vllm-chunk-*)
  local n=${#chunks[@]}
  if [[ "$n" -gt "$MAX_TAGS_VLLM" ]]; then
    echo "ERROR: vLLM genera $n chunks; solo hay tags v0.${TAG_MIN}-v0.${TAG_MAX} ($MAX_TAGS_VLLM)." >&2
    exit 1
  fi
  if [[ "$n" -eq 0 ]]; then
    echo "ERROR: No se generaron chunks." >&2
    exit 1
  fi

  local build_dir="${work_dir}/build"
  mkdir -p "$build_dir"
  local i=1
  for chunk_path in "${chunks[@]}"; do
    [[ -f "$chunk_path" ]] || continue
    local chunk_name
    chunk_name=$(basename "$chunk_path")
    local tag
    tag=$(tag_for_index "$i")
    local dest="${QUAY_REGISTRY}/${VLLM_IMAGE_NAME}:${tag}"
    echo "[vLLM] Build y push chunk $i/$n -> $dest"
    cp "$chunk_path" "$build_dir/"
    cat > "$build_dir/Dockerfile" << EOF
FROM scratch
COPY $chunk_name /image/
EOF
    $CONTAINER_CMD build -f "$build_dir/Dockerfile" -t "$dest" "$build_dir"
    $CONTAINER_CMD push "$dest"
    rm -f "$build_dir/$chunk_name"
    rm -f "$chunk_path"
    echo "[vLLM] Chunk $i eliminado (espacio liberado)."
    i=$((i + 1))
  done

  rm -rf "$work_dir"
  trap - EXIT
  echo "[vLLM] Listo: ${QUAY_REGISTRY}/${VLLM_IMAGE_NAME}:v0.${TAG_MIN} .. v0.$((TAG_MIN + n - 1))"
}

main
