#!/usr/bin/env bash
# reconstruct-model-airgapped.sh — Ejecutar en servidor airgapped para reconstruir una
# carpeta de archivos del modelo (config + .safetensors) a partir de las imágenes.
# No crea ni sube imágenes Docker: solo extrae el contenido de /model/ de cada imagen
# y lo vuelca en un único directorio en disco.
#
# Flujos:
#   --load-dir DIR: directorio con .tar por imagen (ej. ovn-cni-v0.tar, ovn-cni-v1.tar...).
#                   Carga cada .tar, extrae /model/ a la carpeta de salida, borra la imagen.
#   --pull IMAGE:   hace pull de IMAGE:v0, IMAGE:v1, ... IMAGE:vN, extrae /model/ de cada una.
#
# Crear bundle para --load-dir (en máquina con red, tras push-model-to-quay.sh):
#   for t in v0 v1 v2 ... v48; do podman save -o ovn-cni-$t.tar quay.io/redhat_dti/ovn-cni:$t; done
# Copiar los .tar al airgapped y ejecutar este script con --load-dir.
# Requiere: jq (para leer manifest.json del export de podman/docker save).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_OUTPUT_DIR="${SCRIPT_DIR}/model-reconstructed"
IMAGE_NAME="${IMAGE_NAME:-quay.io/redhat_dti/ovn-cni}"
DEFAULT_NUM_SHARDS=48

LOAD_DIR=""
PULL_IMAGE=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
NUM_SHARDS="$DEFAULT_NUM_SHARDS"

CONTAINER_CMD=""
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Se necesita 'podman' o 'docker'." >&2
  exit 1
fi

usage() {
  cat << EOF
Uso: $0 [OPCIONES]

  Reconstruir una carpeta de archivos del modelo en el servidor airgapped.
  Extrae el contenido de /model/ de cada imagen (tras load o pull) a un único directorio.
  No construye ni sube imágenes Docker.
  Requiere: jq (para leer el export de podman/docker save).

  --load-dir DIR      Directorio con tarballs de imágenes (.tar), uno por tag (ej. ovn-cni-v0.tar).
                      Carga cada .tar, extrae /model/ a la carpeta de salida.
  --pull IMAGE        En lugar de load-dir: hacer pull de IMAGE:v0, IMAGE:v1, ... y extraer /model/.
  --output-dir DIR    Carpeta donde reconstruir los archivos (default: $DEFAULT_OUTPUT_DIR).
  --num-shards N      Si usas --pull, número de tags v1..vN además de v0 (default: $DEFAULT_NUM_SHARDS).
  -h, --help          Esta ayuda.

Ejemplos:
  # Desde tarballs copiados al airgapped (ej. USB)
  $0 --load-dir /mnt/usb/model-images --output-dir ./modelo-glm

  # Pull desde registry interno y extraer a carpeta
  $0 --pull registry.internal:5000/ovn-cni --output-dir ./modelo-glm --num-shards 48
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --load-dir)     LOAD_DIR="$2"; shift 2 ;;
    --pull)         PULL_IMAGE="$2"; shift 2 ;;
    --output-dir)   OUTPUT_DIR="$2"; shift 2 ;;
    --num-shards)   NUM_SHARDS="$2"; shift 2 ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
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

# Extrae el contenido de /model/ de la imagen al directorio de salida.
# Las imágenes del modelo son FROM scratch (sin CMD/ENTRYPOINT), por lo que podman create falla.
# Se usa podman/docker save para exportar a tar; el formato tiene manifest.json y capas como layer.tar.
# Uso: extract_model_from_image "image:tag"
# Extrae la lista de Layers del manifest.json (formato podman/docker save).
# Usa jq si está disponible; si no, parsea con sed/grep.
get_layers_from_manifest() {
  local manifest="$1"
  if command -v jq &>/dev/null; then
    jq -r '.[0].Layers[]?' "$manifest" 2>/dev/null | tr -d '\n\r'
    return
  fi
  local line
  line=$(sed -n 's/.*"Layers":\[\([^]]*\)\].*/\1/p' "$manifest" 2>/dev/null)
  [[ -z "$line" ]] && return
  # line = "layer1/layer.tar","layer2/layer.tar" -> una por línea sin comillas
  echo "$line" | sed 's/","/\n/g; s/^"//; s/"$//; s/^"//; s/"$//'
}

extract_model_from_image() {
  local image="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  local save_tar="${tmpdir}/image.tar"
  local export_dir="${tmpdir}/export"
  mkdir -p "$export_dir"
  $CONTAINER_CMD save -o "$save_tar" "$image" 2>/dev/null || {
    echo "ERROR: No se pudo exportar $image (save)" >&2
    return 1
  }
  tar -xf "$save_tar" -C "$export_dir" 2>/dev/null || {
    echo "ERROR: No se pudo extraer el tar de la imagen" >&2
    return 1
  }
  rm -f "$save_tar"
  # Formato podman/docker save: manifest.json con .[0].Layers = ["<id>/layer.tar", ...]
  local manifest="${export_dir}/manifest.json"
  [[ -f "$manifest" ]] || {
    echo "ERROR: manifest.json no encontrado en el export" >&2
    return 1
  }
  local layer_tars
  layer_tars=$(get_layers_from_manifest "$manifest")
  local layer_extract="${tmpdir}/rootfs"
  mkdir -p "$layer_extract"
  while IFS= read -r layer_rel; do
    [[ -z "$layer_rel" ]] && continue
    local layer_path="${export_dir}/${layer_rel}"
    [[ -f "$layer_path" ]] || continue
    if file -b "$layer_path" 2>/dev/null | grep -q gzip; then
      tar -xzf "$layer_path" -C "$layer_extract" 2>/dev/null || true
    else
      tar -xf "$layer_path" -C "$layer_extract" 2>/dev/null || true
    fi
  done <<< "$layer_tars"
  if [[ -d "${layer_extract}/model" ]]; then
    cp -a "${layer_extract}/model/." "$OUTPUT_DIR/"
  else
    echo "ERROR: No existe /model en la imagen $image" >&2
    return 1
  fi
  $CONTAINER_CMD rmi "$image" 2>/dev/null || true
}

# --- Modo: cargar tarballs y extraer a carpeta ---
reconstruct_from_load_dir() {
  local load_dir="$LOAD_DIR"
  if [[ ! -d "$load_dir" ]]; then
    echo "ERROR: No existe el directorio: $load_dir" >&2
    exit 1
  fi

  local tar_files=()
  local f
  for f in "$load_dir"/*.tar; do
    [[ -e "$f" ]] || continue
    tar_files+=("$f")
  done
  if [[ ${#tar_files[@]} -eq 0 ]]; then
    echo "ERROR: No se encontraron archivos .tar en $load_dir." >&2
    exit 1
  fi

  local sorted=()
  while IFS= read -r line; do sorted+=("$line"); done < <(printf '%s\n' "${tar_files[@]}" | sort -V)
  tar_files=("${sorted[@]}")

  mkdir -p "$OUTPUT_DIR"
  echo "[Airgapped] Reconstruyendo carpeta de modelo en: $OUTPUT_DIR (desde ${#tar_files[@]} imágenes)"

  local i=0
  for tf in "${tar_files[@]}"; do
    echo "[Airgapped] Load $(basename "$tf") y extracción de /model/ ..."
    local load_out
    load_out=$($CONTAINER_CMD load -i "$tf" 2>&1) || true
    local img_to_use=""
    if [[ "$load_out" =~ Loaded\ image.*:\ ([^[:space:]]+) ]]; then
      img_to_use="${BASH_REMATCH[1]}"
    fi
    if [[ -z "$img_to_use" ]]; then
      img_to_use=$($CONTAINER_CMD images --format "{{.Repository}}:{{.Tag}}" | head -n 1)
    fi
    if [[ -n "$img_to_use" ]]; then
      extract_model_from_image "$img_to_use"
    fi
    i=$((i + 1))
  done

  $CONTAINER_CMD image prune -f 2>/dev/null || true
  echo "[Airgapped] Listo. Modelo reconstruido en: $OUTPUT_DIR"
  echo "  Contenido: $(ls -la "$OUTPUT_DIR" 2>/dev/null | wc -l) entradas"
}

# --- Modo: pull por tag y extraer a carpeta ---
reconstruct_from_pull() {
  local image_base="$PULL_IMAGE"
  mkdir -p "$OUTPUT_DIR"
  echo "[Airgapped] Pull de ${image_base}:v0 .. v${NUM_SHARDS} y extracción a: $OUTPUT_DIR"

  local tag
  local i=0
  while [[ "$i" -le "$NUM_SHARDS" ]]; do
    tag="v${i}"
    echo "[Airgapped] Pull ${image_base}:${tag} y extracción de /model/ ..."
    $CONTAINER_CMD pull "${image_base}:${tag}"
    extract_model_from_image "${image_base}:${tag}"
    i=$((i + 1))
  done

  $CONTAINER_CMD image prune -f 2>/dev/null || true
  echo "[Airgapped] Listo. Modelo reconstruido en: $OUTPUT_DIR"
  echo "  Contenido: $(ls -la "$OUTPUT_DIR" 2>/dev/null | wc -l) entradas"
}

if [[ -n "$LOAD_DIR" ]]; then
  reconstruct_from_load_dir
else
  reconstruct_from_pull
fi
