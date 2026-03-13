#!/usr/bin/env bash
# reconstruct-vllm-airgapped.sh — Ejecutar en servidor airgapped para reconstruir la imagen
# vLLM completa a partir de los chunks (imágenes con un fragmento del tar) y subirla al registry.
# Coincide con push-vllm-to-quay.sh: los chunks son imágenes scratch con un archivo en /image/
# (vllm-chunk-aa, vllm-chunk-ab, ...). Se extraen, se concatenan en orden y se hace load del tar
# resultante; la imagen completa se etiqueta y se hace push al registry destino.
#
# Crear bundle en máquina con red (tras push-vllm-to-quay.sh):
#   for t in v0.35 v0.36 ... v0.45; do podman save -o multus-cni-$t.tar quay.io/redhat_dti/multus-cni:$t; done
# Copiar los .tar al airgapped y ejecutar con --load-dir. Opcionalmente --pull desde registry interno.
set -euo pipefail

QUAY_REGISTRY="${QUAY_REGISTRY:-quay.io/redhat_dti}"
VLLM_IMAGE_NAME="${VLLM_IMAGE_NAME:-multus-cni}"
TAG_MIN=35
TAG_MAX=45
MAX_TAGS_VLLM=$((TAG_MAX - TAG_MIN + 1))
DEFAULT_REGISTRY="localhost:5000"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOAD_DIR=""
PULL_IMAGE=""
REGISTRY="$DEFAULT_REGISTRY"
OUTPUT_TAG="${OUTPUT_TAG:-latest}"
REGISTRY_LOGIN=false

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
Uso: $0 [OPCIONES]

  Reconstruir la imagen vLLM completa desde los chunks y subirla al registry.
  Los chunks son las imágenes generadas por push-vllm-to-quay.sh (v0.${TAG_MIN}..v0.${TAG_MAX}).

  --load-dir DIR      Directorio con tarballs de imágenes chunk (.tar), una por tag.
  --pull IMAGE         En lugar de load-dir: pull de IMAGE:v0.${TAG_MIN}..v0.${TAG_MAX} y reconstruir.
  --registry REGISTRY  Registry donde subir la imagen reconstruida (default: $DEFAULT_REGISTRY).
  --image-name NAME    Nombre de la imagen en el registry (default: $VLLM_IMAGE_NAME).
  --tag TAG            Tag de la imagen reconstruida (default: $OUTPUT_TAG).
  --registry-login     Hacer login en el registry antes del push.
  -h, --help           Esta ayuda.

Ejemplos:
  $0 --load-dir /mnt/usb/vllm-chunks --registry registry.internal:5000 --registry-login
  $0 --pull quay.io/redhat_dti/multus-cni --registry registry.internal:5000 --tag v1.0
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --load-dir)       LOAD_DIR="$2"; shift 2 ;;
    --pull)           PULL_IMAGE="$2"; shift 2 ;;
    --registry)       REGISTRY="$2"; shift 2 ;;
    --image-name)     VLLM_IMAGE_NAME="$2"; shift 2 ;;
    --tag)            OUTPUT_TAG="$2"; shift 2 ;;
    --registry-login) REGISTRY_LOGIN=true; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$LOAD_DIR" ]] && [[ -z "$PULL_IMAGE" ]]; then
  echo "ERROR: Indique --load-dir o --pull." >&2
  usage >&2
  exit 1
fi
if [[ -n "$LOAD_DIR" ]] && [[ -n "$PULL_IMAGE" ]]; then
  echo "ERROR: Use solo uno de --load-dir o --pull." >&2
  usage >&2
  exit 1
fi

TARGET_IMAGE="${REGISTRY}/${VLLM_IMAGE_NAME}:${OUTPUT_TAG}"

registry_login() {
  if [[ "$REGISTRY_LOGIN" != true ]]; then
    return 0
  fi
  echo "Login en $REGISTRY (se pedirá usuario y contraseña)."
  $CONTAINER_CMD login "$REGISTRY"
}

# Extrae el contenido de /image/ de la imagen al directorio indicado.
extract_chunk_from_image() {
  local image="$1"
  local dest_dir="$2"
  local cid
  cid=$($CONTAINER_CMD create "$image" 2>/dev/null) || {
    echo "ERROR: No se pudo crear contenedor desde $image" >&2
    return 1
  }
  $CONTAINER_CMD cp "${cid}/image/." "$dest_dir/"
  $CONTAINER_CMD rm "$cid" >/dev/null
  $CONTAINER_CMD rmi "$image" 2>/dev/null || true
}

# Obtiene la referencia de imagen cargada desde la salida de podman/docker load.
get_loaded_image_ref() {
  local load_out="$1"
  local img=""
  if [[ "$load_out" =~ Loaded\ image.*:\ ([^[:space:]]+) ]]; then
    img="${BASH_REMATCH[1]}"
  fi
  if [[ -z "$img" ]]; then
    img=$($CONTAINER_CMD images --format "{{.Repository}}:{{.Tag}}" | head -n 1)
  fi
  echo "$img"
}

reconstruct_and_push() {
  local work_dir="${SCRIPT_DIR}/.vllm-reconstruct-$$"
  trap "rm -rf '${work_dir}'" EXIT
  mkdir -p "$work_dir"
  local chunks_dir="${work_dir}/chunks"
  mkdir -p "$chunks_dir"

  local i=1
  local expected=$MAX_TAGS_VLLM

  if [[ -n "$LOAD_DIR" ]]; then
    if [[ ! -d "$LOAD_DIR" ]]; then
      echo "ERROR: No existe el directorio: $LOAD_DIR" >&2
      exit 1
    fi
    local tar_files=()
    local f
    for f in "$LOAD_DIR"/*.tar; do
      [[ -e "$f" ]] || continue
      tar_files+=("$f")
    done
    if [[ ${#tar_files[@]} -eq 0 ]]; then
      echo "ERROR: No se encontraron archivos .tar en $LOAD_DIR." >&2
      exit 1
    fi
    local sorted=()
    while IFS= read -r line; do sorted+=("$line"); done < <(printf '%s\n' "${tar_files[@]}" | sort -V)
    tar_files=("${sorted[@]}")
    expected=${#tar_files[@]}

    echo "[vLLM] Cargando $expected chunks desde $LOAD_DIR y extrayendo /image/ ..."
    for tf in "${tar_files[@]}"; do
      local load_out
      load_out=$($CONTAINER_CMD load -i "$tf" 2>&1) || true
      local img
      img=$(get_loaded_image_ref "$load_out")
      if [[ -n "$img" ]]; then
        echo "[vLLM] Chunk $i/$expected: $(basename "$tf") -> extracción"
        extract_chunk_from_image "$img" "$chunks_dir"
      fi
      i=$((i + 1))
    done
  else
    echo "[vLLM] Pull de ${PULL_IMAGE}:v0.${TAG_MIN}..v0.${TAG_MAX} y extracción de /image/ ..."
    i=1
    while [[ "$i" -le "$MAX_TAGS_VLLM" ]]; do
      local tag
      tag=$(tag_for_index "$i")
      echo "[vLLM] Chunk $i/$MAX_TAGS_VLLM: pull ${PULL_IMAGE}:${tag}"
      $CONTAINER_CMD pull "${PULL_IMAGE}:${tag}"
      extract_chunk_from_image "${PULL_IMAGE}:${tag}" "$chunks_dir"
      i=$((i + 1))
    done
    expected=$MAX_TAGS_VLLM
  fi

  local chunk_files
  chunk_files=("$chunks_dir"/vllm-chunk-*)
  if [[ ${#chunk_files[@]} -eq 0 ]] || [[ ! -f "${chunk_files[0]}" ]]; then
    echo "ERROR: No se encontraron archivos vllm-chunk-* en $chunks_dir." >&2
    exit 1
  fi

  local full_tar="${work_dir}/vllm-full.tar"
  echo "[vLLM] Concatenando ${#chunk_files[@]} chunks en orden -> vllm-full.tar"
  cat "${chunks_dir}"/vllm-chunk-* > "$full_tar"
  rm -rf "$chunks_dir"

  echo "[vLLM] Cargando imagen completa desde vllm-full.tar ..."
  local load_out
  load_out=$($CONTAINER_CMD load -i "$full_tar" 2>&1) || true
  rm -f "$full_tar"
  local full_img
  full_img=$(get_loaded_image_ref "$load_out")
  if [[ -z "$full_img" ]]; then
    echo "ERROR: No se pudo cargar la imagen desde el tar reconstruido." >&2
    exit 1
  fi

  registry_login
  $CONTAINER_CMD tag "$full_img" "$TARGET_IMAGE"
  echo "[vLLM] Push $TARGET_IMAGE"
  $CONTAINER_CMD push "$TARGET_IMAGE"
  $CONTAINER_CMD rmi "$TARGET_IMAGE" 2>/dev/null || true
  $CONTAINER_CMD rmi "$full_img" 2>/dev/null || true

  rm -rf "$work_dir"
  trap - EXIT
  $CONTAINER_CMD image prune -f 2>/dev/null || true
  echo "[vLLM] Listo: imagen reconstruida y subida a $TARGET_IMAGE"
}

reconstruct_and_push
