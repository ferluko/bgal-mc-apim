#!/usr/bin/env bash
# push-to-quay.sh — Sube a quay.io/redhat_dti dos sets de imágenes particionados (≤7GB):
#   Set 1: vLLM (imagen local exportada a tar, partida en chunks) → multus-cni (tags v0.35..v0.45)
#   Set 2: Modelo GLM-4.7-Flash en partes → ovn-cni (tags v0.35..v0.45)
# Libera espacio: borra tar/chunks y partes locales conforme se suben a Quay.
# Uso: ./push-to-quay.sh [--vllm-image IMAGE] [--model-dir DIR|--download-model] [--parts-dir DIR] [--push-vllm-only|--push-model-only]
set -euo pipefail

QUAY_REGISTRY="quay.io/redhat_dti"
VLLM_IMAGE_NAME="multus-cni"
MODEL_IMAGE_NAME="ovn-cni"
TAG_MIN=35
TAG_MAX=45
MAX_TAGS=$((TAG_MAX - TAG_MIN + 1))
MAX_PART_BYTES=$((7000 * 1024 * 1024))
DEFAULT_MODEL_REPO="zai-org/GLM-4.7-Flash"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARTS_DIR=""
MODEL_DIR=""
MODEL_REPO="$DEFAULT_MODEL_REPO"
VLLM_SOURCE_IMAGE=""
PUSH_VLLM=true
PUSH_MODEL=true
DOWNLOAD_MODEL=false
DOWNLOADED_MODEL_DIR=""

CONTAINER_CMD=""
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Se necesita 'podman' o 'docker'." >&2
  exit 1
fi

# Tag para índice de parte (1-based): v0.35, v0.36, ... v0.45
tag_for_index() {
  local i="$1"
  if [[ "$i" -lt 1 ]] || [[ "$i" -gt MAX_TAGS ]]; then
    echo "ERROR: Solo se admiten entre 1 y $MAX_TAGS partes (tags v0.${TAG_MIN} a v0.${TAG_MAX})." >&2
    return 1
  fi
  echo "v0.$((TAG_MIN + i - 1))"
}

usage() {
  cat << EOF
Uso: $0 [OPCIONES]

  --vllm-image IMAGE   Imagen vLLM local; se exporta a tar, se parte en chunks de 7GB y se sube como ${VLLM_IMAGE_NAME}:v0.35..v0.45
  --model-dir DIR      Directorio del modelo (ej. ./glm-4-7-flash). Se parte en bloques de 7GB si no se usa --parts-dir.
  --download-model     Descargar el modelo desde Hugging Face (binario hf) antes de particionar y subir. Por defecto: $DEFAULT_MODEL_REPO
  --model-repo REPO    Repo Hugging Face si se usa --download-model (por defecto: $DEFAULT_MODEL_REPO).
  --parts-dir DIR      Directorio con subdirs part-1, part-2, ... (modelo ya partido). Máx $MAX_TAGS partes.
  --push-vllm-only     Solo subir el set vLLM (multus-cni).
  --push-model-only    Solo subir el set del modelo (ovn-cni).
  -h, --help           Esta ayuda.

Se libera espacio: el tar de vLLM y cada chunk se borran tras subir; cada parte del modelo se borra tras subir.
Tags para ambos sets: v0.${TAG_MIN} a v0.${TAG_MAX} (una por parte/chunk; máximo $MAX_TAGS partes por set).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vllm-image)      VLLM_SOURCE_IMAGE="$2"; shift 2 ;;
    --model-dir)       MODEL_DIR="$2"; shift 2 ;;
    --download-model)  DOWNLOAD_MODEL=true; shift ;;
    --model-repo)      MODEL_REPO="$2"; shift 2 ;;
    --parts-dir)       PARTS_DIR="$2"; shift 2 ;;
    --push-vllm-only)  PUSH_MODEL=false; shift ;;
    --push-model-only) PUSH_VLLM=false; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$DOWNLOAD_MODEL" == true ]] && [[ -n "${MODEL_DIR:-}" ]]; then
  echo "ERROR: No se puede usar --download-model junto con --model-dir." >&2
  exit 1
fi

quay_login() {
  echo "Login en $QUAY_REGISTRY (se pedirá contraseña de forma interactiva)."
  $CONTAINER_CMD login "$QUAY_REGISTRY" -u redhat_dti
}

# Descarga el modelo desde Hugging Face con el binario hf
download_model() {
  if ! command -v hf &>/dev/null; then
    echo "ERROR: Para --download-model se necesita el binario 'hf' (Hugging Face CLI)." >&2
    return 1
  fi
  DOWNLOADED_MODEL_DIR="${SCRIPT_DIR}/.model-download-$$"
  trap "rm -rf '${DOWNLOADED_MODEL_DIR}'" EXIT
  mkdir -p "$DOWNLOADED_MODEL_DIR"
  echo "[Modelo] Descargando $MODEL_REPO a $DOWNLOADED_MODEL_DIR ..."
  hf download "$MODEL_REPO" --local-dir "$DOWNLOADED_MODEL_DIR"
  MODEL_DIR="$DOWNLOADED_MODEL_DIR"
  echo "[Modelo] Descarga completada."
}

# ----- Set 1: vLLM — exportar imagen a tar, partir en chunks ≤7GB, subir como multus-cni:v0.35..v0.45 -----
push_vllm_set() {
  if [[ -z "$VLLM_SOURCE_IMAGE" ]]; then
    echo "Para subir el set vLLM indique --vllm-image." >&2
    return 1
  fi
  local work_dir="${SCRIPT_DIR}/.vllm-chunks"
  trap "rm -rf '${work_dir}'" EXIT
  rm -rf "$work_dir"
  mkdir -p "$work_dir"
  local tar_path="${work_dir}/vllm.tar"

  echo "[Set 1] Exportando imagen a tar: $VLLM_SOURCE_IMAGE"
  $CONTAINER_CMD save -o "$tar_path" "$VLLM_SOURCE_IMAGE"
  echo "[Set 1] Partiendo tar en chunks de 7GB..."
  (cd "$work_dir" && split -b "$MAX_PART_BYTES" -a 2 vllm.tar vllm-chunk-)
  rm -f "$tar_path"
  echo "[Set 1] Tar eliminado para liberar espacio."

  local chunks
  chunks=("$work_dir"/vllm-chunk-*)
  local n=${#chunks[@]}
  if [[ "$n" -gt "$MAX_TAGS" ]]; then
    echo "ERROR: vLLM genera $n chunks; solo hay tags v0.${TAG_MIN}-v0.${TAG_MAX} ($MAX_TAGS)." >&2
    return 1
  fi
  if [[ "$n" -eq 0 ]]; then
    echo "ERROR: No se generaron chunks." >&2
    return 1
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
    echo "[Set 1] Build y push chunk $i/$n -> $dest"
    cp "$chunk_path" "$build_dir/"
    cat > "$build_dir/Dockerfile" << EOF
FROM scratch
COPY $chunk_name /image/
EOF
    $CONTAINER_CMD build -f "$build_dir/Dockerfile" -t "$dest" "$build_dir"
    $CONTAINER_CMD push "$dest"
    rm -f "$build_dir/$chunk_name"
    rm -f "$chunk_path"
    echo "[Set 1] Chunk $i eliminado (espacio liberado)."
    i=$((i + 1))
  done
  rm -rf "$work_dir"
  trap - EXIT
  echo "[Set 1] Listo: ${QUAY_REGISTRY}/${VLLM_IMAGE_NAME}:v0.${TAG_MIN} .. v0.$((TAG_MIN + n - 1))"
}

# ----- Partir modelo en bloques de 7GB -----
MAX_PART_MB=7000
partition_model() {
  local src="$1"
  local out="$2"
  if [[ ! -d "$src" ]]; then
    echo "No existe directorio de modelo: $src" >&2
    return 1
  fi
  rm -rf "$out"
  mkdir -p "$out"
  local part=1
  local current=0
  for f in "$src"/*; do
    [[ -e "$f" ]] || continue
    local size_mb
    size_mb=$(du -m "$f" | cut -f1)
    if [[ $current -gt 0 ]] && [[ $((current + size_mb)) -gt $MAX_PART_MB ]]; then
      part=$((part + 1))
      current=0
    fi
    if [[ $part -gt $MAX_TAGS ]]; then
      echo "ERROR: Más de $MAX_TAGS partes; solo hay tags v0.${TAG_MIN}-v0.${TAG_MAX}." >&2
      return 1
    fi
    local current_dir="$out/part-$part"
    mkdir -p "$current_dir"
    cp -a "$f" "$current_dir/"
    current=$((current + size_mb))
  done
  echo "Modelo partido en $out (part-1 .. part-$part)."
  PARTS_DIR="$out"
}

# ----- Set 2: modelo en partes → ovn-cni:v0.35..v0.45 -----
push_model_set() {
  if [[ -z "$PARTS_DIR" ]]; then
    if [[ "$DOWNLOAD_MODEL" == true ]]; then
      download_model
    fi
    if [[ -n "${MODEL_DIR:-}" ]]; then
      echo "[Set 2] Partiendo modelo en $MODEL_DIR (máx ${MAX_PART_MB}MB por parte)..."
      partition_model "$MODEL_DIR" "${SCRIPT_DIR}/.model-parts"
      PARTS_DIR="${SCRIPT_DIR}/.model-parts"
      if [[ -n "${DOWNLOADED_MODEL_DIR:-}" ]]; then
        echo "[Set 2] Eliminando descarga del modelo para liberar espacio."
        rm -rf "$DOWNLOADED_MODEL_DIR"
        trap - EXIT 2>/dev/null || true
        unset -v DOWNLOADED_MODEL_DIR
      fi
    else
      echo "Para subir el set modelo indique --model-dir, --parts-dir o --download-model." >&2
      return 1
    fi
  fi
  if [[ ! -d "$PARTS_DIR" ]]; then
    echo "No existe directorio de partes: $PARTS_DIR" >&2
    return 1
  fi

  local part_dirs
  part_dirs=("$PARTS_DIR"/part-*)
  if [[ ! -d "${part_dirs[0]:-}" ]]; then
    echo "No se encontraron directorios part-* en $PARTS_DIR" >&2
    return 1
  fi
  local n=${#part_dirs[@]}
  if [[ "$n" -gt "$MAX_TAGS" ]]; then
    echo "ERROR: $n partes; solo hay tags v0.${TAG_MIN}-v0.${TAG_MAX} ($MAX_TAGS)." >&2
    return 1
  fi

  local build_dir="${SCRIPT_DIR}/.build-model"
  trap "rm -rf '${build_dir}'" EXIT
  mkdir -p "$build_dir"

  local i=1
  for part_path in "${part_dirs[@]}"; do
    [[ -d "$part_path" ]] || continue
    local part_name
    part_name=$(basename "$part_path")
    local tag
    tag=$(tag_for_index "$i")
    local dest="${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:${tag}"
    echo "[Set 2] Build y push $part_name -> $dest"
    cp -r "$part_path" "$build_dir/"
    cat > "$build_dir/Dockerfile" << EOF
FROM scratch
COPY $part_name /model/
EOF
    $CONTAINER_CMD build -f "$build_dir/Dockerfile" -t "$dest" "$build_dir"
    $CONTAINER_CMD push "$dest"
    rm -rf "$build_dir/$part_name"
    rm -rf "$part_path"
    echo "[Set 2] Parte $part_name subida y eliminada (espacio liberado)."
    i=$((i + 1))
  done
  rm -rf "$build_dir"
  if [[ -d "${PARTS_DIR:-}" ]]; then
    rmdir "$PARTS_DIR" 2>/dev/null || rm -rf "$PARTS_DIR"
  fi
  trap - EXIT
  echo "[Set 2] Listo: ${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:v0.${TAG_MIN} .. v0.$((TAG_MIN + n - 1))"
}

main() {
  quay_login

  if [[ "$PUSH_VLLM" == true ]]; then
    push_vllm_set
  fi

  if [[ "$PUSH_MODEL" == true ]]; then
    push_model_set
  fi

  echo "Resumen:"
  echo "  Set 1 (vLLM):  ${QUAY_REGISTRY}/${VLLM_IMAGE_NAME}:v0.${TAG_MIN}..v0.${TAG_MAX}"
  echo "  Set 2 (modelo): ${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:v0.${TAG_MIN}..v0.${TAG_MAX}"
}

main