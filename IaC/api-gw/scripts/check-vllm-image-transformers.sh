#!/usr/bin/env bash
# Comprueba la versión de Transformers dentro de la imagen vLLM.
# Para GLM-4.7-Flash (glm4_moe_lite) se necesita transformers>=5.0.0; vLLM 0.17.x suele traer 4.x.
# Uso: DEBUG_LOG_PATH=/path/to/debug-2a01b8.log ./check-vllm-image-transformers.sh [IMAGE]
# Si no se pasa IMAGE, usa docker.io/vllm/vllm-openai:latest
set -euo pipefail

IMAGE="${1:-docker.io/vllm/vllm-openai:latest}"
DEBUG_LOG_PATH="${DEBUG_LOG_PATH:-}"

CONTAINER_CMD=""
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Se necesita podman o docker." >&2
  exit 1
fi

VER=$("$CONTAINER_CMD" run --rm "$IMAGE" python3 -c "import transformers; print(transformers.__version__)" 2>/dev/null || true)
if [[ -z "$VER" ]]; then
  VER="unknown"
fi

echo "Image: $IMAGE"
echo "Transformers version: $VER"
# Requerido para glm4_moe_lite (GLM-4.7-Flash)
if [[ "$VER" != "unknown" ]] && [[ "$VER" == "4."* ]]; then
  echo "WARNING: transformers $VER < 5.0.0 — glm4_moe_lite no soportado; usar imagen con transformers>=5.0.0."
fi

# #region agent log — write NDJSON for debug session
if [[ -n "$DEBUG_LOG_PATH" ]] && [[ -d "$(dirname "$DEBUG_LOG_PATH")" ]]; then
  TS=$(date +%s)000
  ID="log_${TS}_vllm_check"
  echo "{\"sessionId\":\"2a01b8\",\"id\":\"$ID\",\"timestamp\":$TS,\"location\":\"check-vllm-image-transformers.sh\",\"message\":\"Transformers version in vLLM image\",\"data\":{\"transformers_version\":\"$VER\",\"image\":\"$IMAGE\"},\"hypothesisId\":\"H1\"}" >> "$DEBUG_LOG_PATH"
fi
# #endregion
