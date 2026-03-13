#!/usr/bin/env bash
# run-on-ocp-node-podman.sh — Ejecutar DENTRO de un nodo de OpenShift con podman.
#
# Uso típico:
#   oc debug node/<NOMBRE_NODO> -- chroot /host /bin/bash -c 'curl -sL <URL_SCRIPT> | bash -s -- serve --model-dir /mnt/model-reconstructed'
#   o copiar el script al nodo (ej. vía ConfigMap/secret o scp) y ejecutar:
#   podman run ...  # según el subcomando
#
# Subcomandos:
#   reconstruct  — Reconstruir carpeta del modelo desde imágenes (--load-dir o --pull).
#   serve        — Servir el modelo con vLLM en un contenedor (GPU o CPU).
#   serve-cpu    — Alias de serve con variante CPU.
#
# Requiere: podman, jq (solo para reconstruct). En RHCOS podman viene por defecto.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_CMD=""
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Se necesita 'podman' o 'docker' en el nodo." >&2
  exit 1
fi

# --- Defaults alineados con manifests (deployment-vllm-glm-47-flash*.yaml, deployment-model-reconstruct.yaml) ---
VLLM_IMAGE="${VLLM_IMAGE:-docker.io/vllm/vllm-openai:latest}"
VLLM_IMAGE_CPU="${VLLM_IMAGE_CPU:-${VLLM_IMAGE}}"
MODEL_IMAGE_BASE="${MODEL_IMAGE_BASE:-quay.io/redhat_dti/ovn-cni}"
DEFAULT_NUM_SHARDS=48
DEFAULT_MODEL_DIR="${SCRIPT_DIR}/model-reconstructed"
DEFAULT_PORT=8095

usage() {
  cat << 'EOF'
Uso: run-on-ocp-node-podman.sh <subcomando> [opciones]

Subcomandos:

  reconstruct [OPCIONES]
    Reconstruir carpeta del modelo desde imágenes (igual que el job model-reconstruct).
    Requiere jq en el nodo para --load-dir.
    Opciones:
      --load-dir DIR    Directorio con .tar de imágenes (podman save). Cargar y extraer /model/.
      --pull IMAGE      Hacer pull de IMAGE:v0..vN y extraer /model/ a --output-dir.
      --output-dir DIR  Destino (default: ./model-reconstructed).
      --num-shards N    Con --pull: número de shards v1..vN (default: 48).

  serve [OPCIONES]
    Ejecutar vLLM sirviendo el modelo (equivalente al deployment vllm-glm-47-flash).
    Opciones:
      --model-dir DIR   Directorio con el modelo reconstruido (default: ./model-reconstructed).
      --port PORT       Puerto HTTP (default: 8000).
      --cpu             Usar variante CPU (VLLM_TARGET_DEVICE=cpu, sin GPU).
      --image IMAGE     Imagen vLLM (default: docker.io/vllm/vllm-openai:latest).

  serve-cpu [OPCIONES]
    Alias de "serve --cpu".

Ejemplos (en el nodo):

  # Reconstruir modelo desde tarballs en /mnt/usb/images
  ./run-on-ocp-node-podman.sh reconstruct --load-dir /mnt/usb/images --output-dir /var/lib/model

  # Reconstruir desde registry interno
  ./run-on-ocp-node-podman.sh reconstruct --pull registry.internal:5000/ovn-cni --output-dir /var/lib/model

  # Servir con GPU (path donde está el modelo en el nodo)
  ./run-on-ocp-node-podman.sh serve --model-dir /var/lib/model-reconstructed --port 8000

  # Servir solo CPU (nodo sin GPU)
  ./run-on-ocp-node-podman.sh serve-cpu --model-dir /var/lib/model-reconstructed
EOF
}

# ---------------------------------------------------------------------------
# Reconstruct: extrae /model/ de imágenes a un directorio (misma lógica que ConfigMap)
# ---------------------------------------------------------------------------
get_layers_from_manifest() {
  local manifest="$1"
  if command -v jq &>/dev/null; then
    jq -r '.[0].Layers[]?' "$manifest" 2>/dev/null | tr -d '\n\r'
    return
  fi
  local line
  line=$(sed -n 's/.*"Layers":\[\([^]]*\)\].*/\1/p' "$manifest" 2>/dev/null)
  [[ -z "$line" ]] && return
  echo "$line" | sed 's/","/\n/g; s/^"//; s/"$//; s/^"//; s/"$//'
}

extract_model_from_image() {
  local image="$1"
  local output_dir="$2"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  local save_tar="${tmpdir}/image.tar"
  local export_dir="${tmpdir}/export"
  mkdir -p "$export_dir"
  $CONTAINER_CMD save -o "$save_tar" "$image" 2>/dev/null || {
    echo "ERROR: No se pudo exportar $image" >&2
    return 1
  }
  tar -xf "$save_tar" -C "$export_dir" 2>/dev/null || {
    echo "ERROR: No se pudo extraer el tar" >&2
    return 1
  }
  rm -f "$save_tar"
  local manifest="${export_dir}/manifest.json"
  [[ -f "$manifest" ]] || {
    echo "ERROR: manifest.json no encontrado" >&2
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
    cp -a "${layer_extract}/model/." "$output_dir/"
  else
    echo "ERROR: No existe /model en la imagen $image" >&2
    return 1
  fi
  $CONTAINER_CMD rmi "$image" 2>/dev/null || true
}

cmd_reconstruct() {
  local LOAD_DIR="" PULL_IMAGE="" OUTPUT_DIR="$DEFAULT_MODEL_DIR" NUM_SHARDS="$DEFAULT_NUM_SHARDS"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --load-dir)   LOAD_DIR="$2";   shift 2 ;;
      --pull)       PULL_IMAGE="$2"; shift 2 ;;
      --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
      --num-shards) NUM_SHARDS="$2"; shift 2 ;;
      -h|--help)    usage; exit 0 ;;
      *)            echo "Opción desconocida: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$LOAD_DIR" ]] && [[ -z "$PULL_IMAGE" ]]; then
    echo "ERROR: Indique --load-dir o --pull." >&2
    exit 1
  fi
  if [[ -n "$LOAD_DIR" ]] && [[ -n "$PULL_IMAGE" ]]; then
    echo "ERROR: Use solo uno de --load-dir o --pull." >&2
    exit 1
  fi

  mkdir -p "$OUTPUT_DIR"

  if [[ -n "$LOAD_DIR" ]]; then
    [[ -d "$LOAD_DIR" ]] || { echo "ERROR: No existe: $LOAD_DIR" >&2; exit 1; }
    local tar_files=()
    local f
    for f in "$LOAD_DIR"/*.tar; do
      [[ -e "$f" ]] || continue
      tar_files+=("$f")
    done
    [[ ${#tar_files[@]} -gt 0 ]] || { echo "ERROR: No hay .tar en $LOAD_DIR" >&2; exit 1; }
    local sorted=()
    while IFS= read -r line; do sorted+=("$line"); done < <(printf '%s\n' "${tar_files[@]}" | sort -V)
    tar_files=("${sorted[@]}")
    for tf in "${tar_files[@]}"; do
      echo "[node] Load $(basename "$tf") y extracción de /model/ ..."
      local load_out img_to_use
      load_out=$($CONTAINER_CMD load -i "$tf" 2>&1) || true
      if [[ "$load_out" =~ Loaded\ image.*:\ ([^[:space:]]+) ]]; then
        img_to_use="${BASH_REMATCH[1]}"
      fi
      [[ -n "$img_to_use" ]] || img_to_use=$($CONTAINER_CMD images --format "{{.Repository}}:{{.Tag}}" | head -n 1)
      [[ -n "$img_to_use" ]] && extract_model_from_image "$img_to_use" "$OUTPUT_DIR"
    done
  else
    local i=0 tag
    while [[ "$i" -le "$NUM_SHARDS" ]]; do
      tag="v${i}"
      echo "[node] Pull ${PULL_IMAGE}:${tag} y extracción ..."
      $CONTAINER_CMD pull "${PULL_IMAGE}:${tag}"
      extract_model_from_image "${PULL_IMAGE}:${tag}" "$OUTPUT_DIR"
      i=$((i + 1))
    done
  fi

  $CONTAINER_CMD image prune -f 2>/dev/null || true
  echo "[node] Modelo reconstruido en: $OUTPUT_DIR"
}

# ---------------------------------------------------------------------------
# Serve: corre vLLM en un contenedor (GPU o CPU), montando el directorio del modelo
# ---------------------------------------------------------------------------
cmd_serve() {
  local MODEL_DIR="$DEFAULT_MODEL_DIR" PORT="$DEFAULT_PORT" USE_CPU=false IMAGE="$VLLM_IMAGE"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model-dir) MODEL_DIR="$2"; shift 2 ;;
      --port)      PORT="$2";      shift 2 ;;
      --cpu)       USE_CPU=true;   shift 1 ;;
      --image)     IMAGE="$2";     shift 2 ;;
      -h|--help)   usage; exit 0 ;;
      *)           echo "Opción desconocida: $1" >&2; exit 1 ;;
    esac
  done

  if [[ ! -d "$MODEL_DIR" ]]; then
    echo "ERROR: No existe el directorio del modelo: $MODEL_DIR" >&2
    exit 1
  fi

  if [[ "$USE_CPU" == true ]]; then
    IMAGE="${VLLM_IMAGE_CPU}"
  fi

  # El deployment monta el PVC en /models; el contenido está en model-reconstructed dentro del PVC.
  # En nodo montamos MODEL_DIR en /models. Si hay subdir model-reconstructed, servir ese path.
  local MOUNT_SRC="$MODEL_DIR"
  local SERVE_PATH="/models"
  if [[ -d "${MODEL_DIR}/model-reconstructed" ]]; then
    SERVE_PATH="/models/model-reconstructed"
  fi

  local ENV_ARGS=(
    -e "VLLM_LOGGING_LEVEL=DEBUG"
  )
  if [[ "$USE_CPU" == true ]]; then
    ENV_ARGS+=( -e "VLLM_TARGET_DEVICE=cpu" )
  fi

  # Construir comando vLLM: GPU (más memoria, prefix-caching) vs CPU
  local VLLM_CMD
  if [[ "$USE_CPU" == true ]]; then
    VLLM_CMD="vllm serve ${SERVE_PATH} --served-model-name glm-4-7-flash --host 0.0.0.0 --port 8000 --tensor-parallel-size 1 --max-model-len 8192 --max-num-batched-tokens 2048 --dtype auto --trust-remote-code --tool-call-parser glm47 --reasoning-parser glm47"
  else
    VLLM_CMD="vllm serve ${SERVE_PATH} --served-model-name glm-4-7-flash --host 0.0.0.0 --port 8000 --tensor-parallel-size 1 --gpu-memory-utilization 0.94 --max-model-len 131072 --max-num-batched-tokens 16384 --enable-chunked-prefill --enable-prefix-caching --dtype auto --trust-remote-code --tool-call-parser glm47 --reasoning-parser glm47"
  fi

  local SHM_SIZE="4g"
  [[ "$USE_CPU" != true ]] && SHM_SIZE="16g"

  echo "[node] Sirviendo modelo desde $MODEL_DIR (path en contenedor: $SERVE_PATH), puerto $PORT"
  echo "[node] Imagen: $IMAGE"
  $CONTAINER_CMD run -d --rm \
    --name vllm-glm-47-flash \
    -p "${PORT}:8000" \
    "${ENV_ARGS[@]}" \
    -v "${MOUNT_SRC}:/models:ro" \
    --shm-size="$SHM_SIZE" \
    "$IMAGE" \
    /bin/sh -c "$VLLM_CMD"
  echo "[node] Contenedor iniciado. Health: http://<nodo>:${PORT}/health"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
SUBCMD="${1:-}"
shift 2>/dev/null || true
case "${SUBCMD}" in
  reconstruct)  cmd_reconstruct "$@" ;;
  serve)        cmd_serve "$@" ;;
  serve-cpu)   cmd_serve --cpu "$@" ;;
  -h|--help|"") usage; exit 0 ;;
  *)           echo "Subcomando desconocido: $SUBCMD" >&2; usage >&2; exit 1 ;;
esac
