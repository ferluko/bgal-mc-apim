#!/usr/bin/env bash
# push-to-quay.sh — Wrapper que invoca los dos scripts desacoplados:
#   Set 1: push-vllm-to-quay.sh  — particionar imagen Docker vLLM y subir a Quay (multus-cni)
#   Set 2: push-model-to-quay.sh — descargar safetensors de HF de a pares, una imagen por shard + config (ovn-cni)
#
# Para usar solo un set, ejecute directamente el script correspondiente:
#   ./push-vllm-to-quay.sh --vllm-image IMAGE
#   ./push-model-to-quay.sh [--model-repo REPO] [--num-shards N] [--analyze] [--no-resume]
#
# Tags modelo: v0 = archivos de config, v1 = safetensor 1, v2 = safetensor 2, ...
# Con --analyze en push-model-to-quay.sh se ve qué está subido y qué falta; sin --no-resume se retoma.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUSH_VLLM=true
PUSH_MODEL=true
VLLM_IMAGE=""
MODEL_REPO="zai-org/GLM-4.7-Flash"
NUM_SHARDS="48"
CONFIG_FILES=""
BATCH_SIZE="2"
MODEL_DIR=""
ANALYZE=""
NO_RESUME=""

usage() {
  cat << EOF
Uso: $0 [OPCIONES]

Invoca push-vllm-to-quay.sh (Set 1) y/o push-model-to-quay.sh (Set 2).

Set 1 (vLLM):
  --vllm-image IMAGE   Imagen vLLM a particionar y subir (multus-cni:v0.35..v0.45)

Set 2 (modelo — tags v0=config, v1..vN=shards):
  --model-repo REPO    Repo Hugging Face (default: zai-org/GLM-4.7-Flash)
  --num-shards N       Número de shards (default: 48)
  --config-files LIST  Archivos de config (default: model.safetensors.index.json,config.json,tokenizer.json,tokenizer_config.json)
  --batch-size N       Shards a la vez (default: 2)
  --model-dir DIR      Modelo ya en disco (no descarga HF)
  --analyze            Solo listar qué hay en Quay y qué falta (push-model)
  --no-resume          Subir todo desde cero (push-model)

General:
  --push-vllm-only     Solo ejecutar Set 1 (vLLM).
  --push-model-only    Solo ejecutar Set 2 (modelo).
  -h, --help           Esta ayuda.

Scripts desacoplados:
  Set 1: $SCRIPT_DIR/push-vllm-to-quay.sh
  Set 2: $SCRIPT_DIR/push-model-to-quay.sh  (soporta --analyze y retomar por defecto)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vllm-image)      VLLM_IMAGE="$2"; shift 2 ;;
    --model-repo)      MODEL_REPO="$2"; shift 2 ;;
    --num-shards)      NUM_SHARDS="$2"; shift 2 ;;
    --config-files)    CONFIG_FILES="$2"; shift 2 ;;
    --batch-size)      BATCH_SIZE="$2"; shift 2 ;;
    --model-dir)       MODEL_DIR="$2"; shift 2 ;;
    --analyze)         ANALYZE="--analyze"; shift ;;
    --no-resume)       NO_RESUME="--no-resume"; shift ;;
    --push-vllm-only)  PUSH_MODEL=false; shift ;;
    --push-model-only) PUSH_VLLM=false; shift ;;
    -h|--help)         usage; exit 0 ;;
    *)                 echo "Opción desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

run_vllm() {
  if [[ -z "$VLLM_IMAGE" ]]; then
    echo "Set 1 (vLLM): omitido (falta --vllm-image)." >&2
    return 0
  fi
  echo "=== Set 1: push-vllm-to-quay.sh ==="
  "$SCRIPT_DIR/push-vllm-to-quay.sh" --vllm-image "$VLLM_IMAGE"
}

run_model() {
  echo "=== Set 2: push-model-to-quay.sh ==="
  local args=()
  if [[ -n "$MODEL_DIR" ]]; then
    args+=(--model-dir "$MODEL_DIR")
  else
    args+=(--model-repo "$MODEL_REPO" --num-shards "$NUM_SHARDS")
    [[ -n "$CONFIG_FILES" ]] && args+=(--config-files "$CONFIG_FILES")
    args+=(--batch-size "$BATCH_SIZE")
  fi
  [[ -n "$ANALYZE" ]] && args+=("$ANALYZE")
  [[ -n "$NO_RESUME" ]] && args+=("$NO_RESUME")
  "$SCRIPT_DIR/push-model-to-quay.sh" "${args[@]}"
}

if [[ "$PUSH_VLLM" == true ]]; then
  run_vllm
fi
if [[ "$PUSH_MODEL" == true ]]; then
  run_model
fi

echo "Listo."
