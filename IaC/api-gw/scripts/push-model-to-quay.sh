#!/usr/bin/env bash
# push-model-to-quay.sh — Set 2: descargar .safetensors de Hugging Face de a pares, una imagen por shard + config, subir a Quay.
# Tags: v0 = archivos de config, v1 = safetensor 1, v2 = safetensor 2, ... vN = safetensor N.
# Permite analizar lo ya subido y retomar desde el primer tag faltante.
# Uso: ./push-model-to-quay.sh [--model-repo REPO] [--num-shards N] [--analyze] [--no-resume]
set -euo pipefail

QUAY_REGISTRY="quay.io/redhat_dti"
MODEL_IMAGE_NAME="ovn-cni"
DEFAULT_MODEL_REPO="zai-org/GLM-4.7-Flash"
DEFAULT_NUM_SHARDS=48
DEFAULT_CONFIG_FILES="model.safetensors.index.json,config.json,tokenizer.json,tokenizer_config.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_REPO="$DEFAULT_MODEL_REPO"
NUM_SHARDS="$DEFAULT_NUM_SHARDS"
CONFIG_FILES_CSV="$DEFAULT_CONFIG_FILES"
BATCH_SIZE=2
MODEL_DIR=""
USE_HF_URLS=true
ANALYZE_ONLY=false
RESUME=true

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

  --model-repo REPO    Repo Hugging Face (default: $DEFAULT_MODEL_REPO)
  --num-shards N       Número de shards .safetensors (default: $DEFAULT_NUM_SHARDS)
  --config-files LIST   Archivos de config separados por coma (default: $DEFAULT_CONFIG_FILES)
  --batch-size N       Shards a descargar a la vez antes de build+push (default: 2)
  --model-dir DIR      Alternativa: modelo ya en disco; no descarga desde HF (sin resume)
  --analyze            Solo listar qué tags ya existen en Quay y cuáles faltan; no descarga ni sube
  --no-resume          Subir todo desde cero (ignorar tags ya existentes)
  -h, --help           Esta ayuda.

Tags: v0 = config/tokenizer, v1..vN = shard 1..N. Con --analyze se evalúa el estado; sin --no-resume se retoma desde el primer faltante.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model-repo)    MODEL_REPO="$2"; shift 2 ;;
    --num-shards)    NUM_SHARDS="$2"; shift 2 ;;
    --config-files)  CONFIG_FILES_CSV="$2"; shift 2 ;;
    --batch-size)    BATCH_SIZE="$2"; shift 2 ;;
    --model-dir)     MODEL_DIR="$2"; USE_HF_URLS=false; shift 2 ;;
    --analyze)       ANALYZE_ONLY=true; shift ;;
    --no-resume)     RESUME=false; shift ;;
    -h|--help)       usage; exit 0 ;;
    *)               echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ "$USE_HF_URLS" == true ]] && [[ -n "${MODEL_DIR:-}" ]]; then
  echo "ERROR: No se puede usar --model-dir con --model-repo/--num-shards." >&2
  exit 1
fi

# Tag para modelo: v0 = config, v1 = shard 1, v2 = shard 2, ...
model_tag_for_index() {
  local i="$1"
  if [[ "$i" -lt 0 ]] || [[ "$i" -gt "$NUM_SHARDS" ]]; then
    echo "ERROR: Índice $i fuera de rango (0 a $NUM_SHARDS)." >&2
    return 1
  fi
  echo "v${i}"
}

quay_login() {
  echo "Login en $QUAY_REGISTRY (se pedirá contraseña de forma interactiva)."
  $CONTAINER_CMD login "$QUAY_REGISTRY" -u redhat_dti
}

# Lista los tags existentes del repositorio en Quay (para evaluar y retomar).
list_existing_tags() {
  local image="${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}"
  local tags=()
  if command -v skopeo &>/dev/null; then
    local out
    out=$(skopeo list-tags "docker://${image}" 2>/dev/null) || true
    if [[ -n "$out" ]]; then
      if command -v jq &>/dev/null; then
        while IFS= read -r t; do [[ -n "$t" ]] && tags+=("$t"); done < <(echo "$out" | jq -r '.Tags[]?' 2>/dev/null)
      else
        # Parseo básico sin jq: extrae "v0", "v1", etc. de la salida JSON
        while read -r t; do
          [[ -n "$t" ]] && tags+=("$t")
        done < <(echo "$out" | grep -oE '"v[0-9]+"' | tr -d '"')
      fi
    fi
  fi
  if [[ ${#tags[@]} -eq 0 ]] && command -v curl &>/dev/null; then
    # Fallback: API pública de Quay (repos públicos)
    local repo_path="${QUAY_REGISTRY#*/}"
    local url="https://quay.io/api/v1/repository/${repo_path}/${MODEL_IMAGE_NAME}/tag/?limit=200"
    local api
    api=$(curl -sS -L "$url" 2>/dev/null) || true
    if [[ -n "$api" ]]; then
      if command -v jq &>/dev/null; then
        while IFS= read -r t; do [[ -n "$t" ]] && tags+=("$t"); done < <(echo "$api" | jq -r '.tags[].name' 2>/dev/null)
      else
        while read -r t; do
          [[ -n "$t" ]] && tags+=("$t")
        done < <(echo "$api" | grep -oE '"name"[[:space:]]*:[[:space:]]*"v[0-9]+"' | grep -oE 'v[0-9]+')
      fi
    fi
  fi
  if [[ ${#tags[@]} -gt 0 ]]; then
    printf '%s\n' "${tags[@]}" | sort -V
  fi
}

# Retorna 0 si el tag existe en la lista (archivo/stdin con un tag por línea).
tag_exists() {
  local tag="$1"
  local list="$2"
  grep -qFx "$tag" <<< "$list" 2>/dev/null
}

download_hf_file() {
  local base_url="$1"
  local filename="$2"
  local dest_dir="$3"
  local url="${base_url}/${filename}"
  mkdir -p "$dest_dir"
  if command -v wget &>/dev/null; then
    wget -q --show-progress -O "${dest_dir}/${filename}" "$url"
  elif command -v curl &>/dev/null; then
    curl -# -L -o "${dest_dir}/${filename}" "$url"
  else
    echo "ERROR: Se necesita 'wget' o 'curl'." >&2
    return 1
  fi
}

run_analyze() {
  echo "=== Análisis de imágenes en Quay ==="
  echo "Imagen: ${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}"
  echo "Modelo: $MODEL_REPO ($NUM_SHARDS shards)"
  echo "Tags esperados: v0 (config), v1..v${NUM_SHARDS} (shards)"
  echo ""

  # Listar tags sin login (API pública para repos públicos; repos privados requieren login previo)
  local existing
  existing=$(list_existing_tags)
  local existing_count=0
  [[ -n "$existing" ]] && existing_count=$(echo "$existing" | grep -c . 2>/dev/null) || true
  existing_count=$((existing_count + 0))
  echo "Tags ya presentes en Quay ($existing_count):"
  if [[ -n "$existing" ]]; then
    echo "$existing" | sed 's/^/  /'
  else
    echo "  (ninguno)"
  fi

  echo ""
  local missing=()
  local tag
  if ! tag_exists "v0" "$existing"; then
    missing+=("v0 (config)")
  fi
  local i=1
  while [[ "$i" -le "$NUM_SHARDS" ]]; do
    tag=$(model_tag_for_index "$i")
    if ! tag_exists "$tag" "$existing"; then
      missing+=("$tag (shard $i)")
    fi
    i=$((i + 1))
  done
  echo "Tags faltantes ($(( ${#missing[@]} ))):"
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf '  %s\n' "${missing[@]}"
    echo ""
    echo "Ejecute sin --analyze para descargar y subir solo los faltantes (retomar)."
  else
    echo "  (ninguno — todo subido)"
  fi
}

push_model_set_from_hf() {
  local hf_base="https://huggingface.co/${MODEL_REPO}/resolve/main"
  local work_dir="${SCRIPT_DIR}/.model-hf-$$"
  trap "rm -rf '${work_dir}'" EXIT
  mkdir -p "$work_dir"
  local build_dir="${work_dir}/build"
  mkdir -p "$build_dir"

  local existing_list=""
  if [[ "$RESUME" == true ]]; then
    echo "[Modelo] Consultando tags existentes en Quay..."
    existing_list=$(list_existing_tags)
  fi

  # 1) Config: tag v0
  local tag_v0
  tag_v0=$(model_tag_for_index 0)
  if [[ "$RESUME" == true ]] && tag_exists "$tag_v0" "$existing_list"; then
    echo "[Modelo] $tag_v0 ya existe en Quay, se omite."
  else
    echo "[Modelo] Descargando archivos de config desde $MODEL_REPO ..."
    local config_subdir="${build_dir}/config"
    mkdir -p "$config_subdir"
    local f
    IFS=',' read -ra FILES <<< "$CONFIG_FILES_CSV"
    for f in "${FILES[@]}"; do
      f="${f// /}"
      [[ -z "$f" ]] && continue
      if ! download_hf_file "$hf_base" "$f" "$config_subdir"; then
        echo "ADVERTENCIA: No se pudo descargar $f." >&2
        rm -f "${config_subdir}/${f}"
      fi
    done
    if [[ -n "$(ls -A "$config_subdir" 2>/dev/null)" ]]; then
      local dest="${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:${tag_v0}"
      echo "[Modelo] Build y push config -> $dest"
      cat > "$build_dir/Dockerfile" << 'DOCKERFILE_EOF'
FROM scratch
COPY config/ /model/
DOCKERFILE_EOF
      $CONTAINER_CMD build -f "$build_dir/Dockerfile" -t "$dest" "$build_dir"
      $CONTAINER_CMD push "$dest"
      $CONTAINER_CMD rmi "$dest" 2>/dev/null || true
      rm -rf "$config_subdir"/*
      echo "[Modelo] Config subido (v0), imagen local borrada y archivos eliminados."
    fi
  fi

  # 2) Shards: tags v1..vN; descargar de a BATCH_SIZE en paralelo, retomando si RESUME
  local num_padded
  num_padded=$(printf "%05d" "$NUM_SHARDS")
  local shard=1
  while [[ "$shard" -le "$NUM_SHARDS" ]]; do
    local batch_shards=()
    local batch_filenames=()
    local count=0
    while [[ "$count" -lt "$BATCH_SIZE" ]] && [[ "$shard" -le "$NUM_SHARDS" ]]; do
      local current_tag
      current_tag=$(model_tag_for_index "$shard")
      if [[ "$RESUME" == true ]] && tag_exists "$current_tag" "$existing_list"; then
        echo "[Modelo] $current_tag ya existe en Quay, se omite shard $shard."
        shard=$((shard + 1))
        continue
      fi
      local shard_pad
      shard_pad=$(printf "%05d" "$shard")
      local filename="model-${shard_pad}-of-${num_padded}.safetensors"
      batch_shards+=("$shard")
      batch_filenames+=("$filename")
      count=$((count + 1))
      shard=$((shard + 1))
    done
    [[ ${#batch_filenames[@]} -eq 0 ]] && continue

    # Descarga en paralelo (varios jobs en background)
    echo "[Modelo] Descargando ${#batch_filenames[@]} shard(s) en paralelo: ${batch_filenames[*]}"
    local i=0
    while [[ $i -lt ${#batch_filenames[@]} ]]; do
      download_hf_file "$hf_base" "${batch_filenames[i]}" "$build_dir" &
      i=$((i + 1))
    done
    wait || true

    for i in "${!batch_filenames[@]}"; do
      [[ -f "${build_dir}/${batch_filenames[i]}" ]] || { echo "ERROR: No se encontró ${batch_filenames[i]} tras descarga." >&2; return 1; }
    done

    # Build y push en paralelo: cada shard en su propio directorio para no pisar el Dockerfile
    echo "[Modelo] Build y push en paralelo (${#batch_filenames[@]} imágenes)"
    for i in "${!batch_filenames[@]}"; do
      (
        local name="${batch_filenames[i]}"
        local idx="${batch_shards[i]}"
        local tag
        tag=$(model_tag_for_index "$idx")
        local dest="${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:${tag}"
        local job_dir="${build_dir}/job_${i}"
        mkdir -p "$job_dir"
        cp "${build_dir}/${name}" "$job_dir/"
        cat > "$job_dir/Dockerfile" << DOCKERFILE_EOF
FROM scratch
COPY $name /model/
DOCKERFILE_EOF
        $CONTAINER_CMD build -f "$job_dir/Dockerfile" -t "$dest" "$job_dir"
        $CONTAINER_CMD push "$dest"
        $CONTAINER_CMD rmi "$dest" 2>/dev/null || true
        rm -rf "$job_dir"
        echo "[Modelo] $name subido ($tag), imagen local borrada."
      ) &
    done
    wait || true

    for i in "${!batch_filenames[@]}"; do
      rm -f "${build_dir}/${batch_filenames[i]}"
    done
  done

  rm -rf "$work_dir"
  trap - EXIT

  # Validación y limpieza: no debe quedar cache ni basura en disco
  if [[ -d "$work_dir" ]]; then
    echo "ADVERTENCIA: Directorio de trabajo aún existe, forzando borrado: $work_dir" >&2
    rm -rf "$work_dir"
  fi
  local leftover
  for leftover in "${SCRIPT_DIR}"/.model-hf-* "${SCRIPT_DIR}"/.build-model-*; do
    if [[ -d "$leftover" ]]; then
      echo "[Limpieza] Eliminando directorio residual: $leftover"
      rm -rf "$leftover"
    fi
  done
  $CONTAINER_CMD image prune -f 2>/dev/null || true
  echo "[Modelo] Listo: ${QUAY_REGISTRY}/${MODEL_IMAGE_NAME} tags v0..v${NUM_SHARDS} (modelo $MODEL_REPO). Cache local limpiada."
}

push_model_set_from_dir() {
  if [[ -z "${MODEL_DIR:-}" ]] || [[ ! -d "$MODEL_DIR" ]]; then
    echo "ERROR: Indique --model-dir DIR." >&2
    return 1
  fi
  local model_dir="$MODEL_DIR"
  local config_files=()
  local safetensor_files=()
  local f
  for f in "$model_dir"/*; do
    [[ -e "$f" ]] || continue
    if [[ "$f" == *.safetensors ]]; then
      safetensor_files+=("$f")
    else
      config_files+=("$f")
    fi
  done
  if [[ ${#safetensor_files[@]} -gt 0 ]]; then
    local sorted=()
    while IFS= read -r line; do sorted+=("$line"); done < <(printf '%s\n' "${safetensor_files[@]}" | sort -V)
    safetensor_files=("${sorted[@]}")
  fi
  local total_images=$(( (${#config_files[@]} > 0 ? 1 : 0) + ${#safetensor_files[@]} ))
  if [[ "$total_images" -eq 0 ]]; then
    echo "ERROR: No se encontraron archivos en $model_dir." >&2
    return 1
  fi

  local build_dir="${SCRIPT_DIR}/.build-model-$$"
  trap "rm -rf '${build_dir}'" EXIT
  mkdir -p "$build_dir"
  local idx=0

  if [[ ${#config_files[@]} -gt 0 ]]; then
    local tag
    tag=$(model_tag_for_index 0)
    local dest="${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:${tag}"
    echo "[Modelo] Build y push config -> $dest"
    local config_subdir="${build_dir}/config"
    mkdir -p "$config_subdir"
    for f in "${config_files[@]}"; do
      cp -a "$f" "$config_subdir/"
    done
    cat > "$build_dir/Dockerfile" << 'DOCKERFILE_EOF'
FROM scratch
COPY config/ /model/
DOCKERFILE_EOF
    $CONTAINER_CMD build -f "$build_dir/Dockerfile" -t "$dest" "$build_dir"
    $CONTAINER_CMD push "$dest"
    $CONTAINER_CMD rmi "$dest" 2>/dev/null || true
    for f in "${config_files[@]}"; do rm -rf "$f"; done
    rm -rf "$build_dir"/*
    idx=1
  fi

  for sf in "${safetensor_files[@]}"; do
    [[ -f "$sf" ]] || continue
    local name
    name=$(basename "$sf")
    local tag
    tag=$(model_tag_for_index "$idx")
    local dest="${QUAY_REGISTRY}/${MODEL_IMAGE_NAME}:${tag}"
    echo "[Modelo] Build y push $name -> $dest"
    cp -a "$sf" "$build_dir/"
    cat > "$build_dir/Dockerfile" << EOF
FROM scratch
COPY $name /model/
EOF
    $CONTAINER_CMD build -f "$build_dir/Dockerfile" -t "$dest" "$build_dir"
    $CONTAINER_CMD push "$dest"
    $CONTAINER_CMD rmi "$dest" 2>/dev/null || true
    rm -f "$build_dir/$name"
    rm -f "$sf"
    idx=$((idx + 1))
  done

  rm -rf "$build_dir"
  trap - EXIT
  for leftover in "${SCRIPT_DIR}"/.build-model-*; do
    [[ -d "$leftover" ]] && rm -rf "$leftover"
  done
  $CONTAINER_CMD image prune -f 2>/dev/null || true
  echo "[Modelo] Listo: ${QUAY_REGISTRY}/${MODEL_IMAGE_NAME} (desde directorio local). Cache local limpiada."
}

main() {
  if [[ "$ANALYZE_ONLY" == true ]]; then
    run_analyze
    return 0
  fi

  quay_login
  if [[ "$USE_HF_URLS" == true ]]; then
    push_model_set_from_hf
  else
    push_model_set_from_dir
  fi
}

main
