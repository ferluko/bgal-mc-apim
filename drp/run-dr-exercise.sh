#!/usr/bin/env bash
# =============================================================================
# ORQUESTADOR PRINCIPAL — Ejercicio DRP
# Banco Galicia — Plataforma OCP + 3scale (ns:amp) + F5 LTM Active-Active
#
# Flujo:
#   1. PRE   → captura baseline (PGA activo, CMZ pasivo)
#   2. Pausa → operador ejecuta switch F5 + DNS
#   3. DURING → snapshots intermedios (CMZ activo)
#   4. POST  → valida retorno a normalidad (PGA activo)
#
# Uso:
#   ./run-dr-exercise.sh              # modo interactivo con pausas
#   ./run-dr-exercise.sh --pre        # solo fase PRE
#   ./run-dr-exercise.sh --during     # solo snapshot DURING
#   ./run-dr-exercise.sh --post       # solo fase POST
#   ./run-dr-exercise.sh --war-room   # imprime instrucciones de terminales
# =============================================================================
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

DRP_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
export DRP_EXERCISE_DIR="${DRP_EXERCISE_DIR:-$REPORTS_DIR/$TIMESTAMP}"
mkdir -p "$DRP_EXERCISE_DIR"

MODE="${1:-interactive}"

# ---------------------------------------------------------------------------
# Instrucciones del War Room
# ---------------------------------------------------------------------------
print_war_room() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║              DRP WAR ROOM — Terminales recomendadas          ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}TTY 1 — Orquestador (este terminal)${NC}"
    echo    "  ./run-dr-exercise.sh"
    echo ""
    echo -e "${CYAN}TTY 2 — Eventos Warning en tiempo real (ambos clusters)${NC}"
    echo    "  ./live/watch-events.sh all"
    echo ""
    echo -e "${CYAN}TTY 3 — Pods problemáticos + reinicios${NC}"
    echo    "  ./live/watch-pods.sh all"
    echo ""
    echo -e "${CYAN}TTY 4 — Routers / IngressControllers${NC}"
    echo    "  ./live/watch-ingress.sh all"
    echo ""
    echo -e "${CYAN}TTY 5 — DNS resolution (FQDN agnóstico)${NC}"
    echo    "  ./live/watch-dns.sh"
    echo -e "  FQDN observado: ${YELLOW}$AGNOSTIC_FQDN${NC}"
    echo ""
    echo -e "${CYAN}TTY 6 — Audit log (cambios manuales PGA)${NC}"
    echo    "  ./live/watch-audit.sh pga"
    echo ""
    echo -e "${CYAN}TTY 7 — Audit log (cambios manuales CMZ)${NC}"
    echo    "  ./live/watch-audit.sh cmz"
    echo ""
    echo -e "${CYAN}TTY 8 (opcional) — Watcher de recursos (deploy/routes)${NC}"
    echo    "  ./live/watch-changes.sh pga deploy"
    echo    "  ./live/watch-changes.sh cmz deploy"
    echo ""
}

# ---------------------------------------------------------------------------
# Helper: esperar confirmación del operador
# ---------------------------------------------------------------------------
pause_for_operator() {
    local msg="$1"
    echo ""
    echo -e "${YELLOW}${BOLD}>>> ACCIÓN REQUERIDA: $msg${NC}"
    echo -e "${YELLOW}Presioná ENTER cuando esté listo...${NC}"
    read -r
}

# ---------------------------------------------------------------------------
# Timeline del ejercicio
# ---------------------------------------------------------------------------
TIMELINE_FILE="$DRP_EXERCISE_DIR/timeline.txt"
timeline() {
    echo "$(date '+%H:%M:%S') | $*" | tee -a "$TIMELINE_FILE"
}

# ---------------------------------------------------------------------------
# Modos de ejecución
# ---------------------------------------------------------------------------
case "$MODE" in

    --pre)
        log "Ejecutando solo fase PRE"
        export DRP_EXERCISE_DIR
        "$DRP_SCRIPT_DIR/pre/precheck.sh"
        ;;

    --during)
        log "Ejecutando snapshot DURING"
        export DRP_EXERCISE_DIR
        "$DRP_SCRIPT_DIR/during/during.sh"
        ;;

    --post)
        log "Ejecutando solo fase POST"
        export DRP_EXERCISE_DIR
        "$DRP_SCRIPT_DIR/post/postcheck.sh"
        ;;

    --war-room)
        print_war_room
        ;;

    interactive|--interactive)
        # ---------------------------------------------------------------------------
        # MODO INTERACTIVO COMPLETO
        # ---------------------------------------------------------------------------
        clear
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║        BANCO GALICIA — EJERCICIO DRP — ORQUESTADOR           ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  Directorio del ejercicio: ${CYAN}$DRP_EXERCISE_DIR${NC}"
        echo -e "  Activo inicial (PRE):     ${GREEN}$CLUSTER_PGA (PGA)${NC}"
        echo -e "  DR target (DURING):       ${CYAN}$CLUSTER_CMZ (CMZ)${NC}"
        echo -e "  FQDN agnóstico:           ${YELLOW}$AGNOSTIC_FQDN${NC}"
        echo ""

        print_war_room

        pause_for_operator "Abrí los 7 terminales del war room antes de continuar"
        timeline "INICIO — Ejercicio DRP arrancado"

        # ---- FASE PRE -------------------------------------------------------
        log ""
        log "════════════════════════════════════════"
        log "  FASE 1/3: PRE (baseline)"
        log "════════════════════════════════════════"
        timeline "FASE PRE — inicio"

        export DRP_EXERCISE_DIR
        "$DRP_SCRIPT_DIR/pre/precheck.sh"
        timeline "FASE PRE — completada"

        # ---- SWITCH F5 + DNS ------------------------------------------------
        echo ""
        echo -e "${BOLD}════════════════════════════════════════${NC}"
        echo -e "${BOLD}  SWITCH: F5 LTM + DNS${NC}"
        echo -e "${BOLD}════════════════════════════════════════${NC}"
        echo ""
        echo -e "  Acciones a ejecutar por operador:"
        echo -e "  ${YELLOW}1. Deshabilitar VIPs en F5 LTM de PGA${NC}"
        echo -e "  ${YELLOW}2. Habilitar VIPs en F5 LTM de CMZ${NC}"
        echo -e "  ${YELLOW}3. Cambiar DNS de $AGNOSTIC_FQDN → IPs de CMZ${NC}"
        echo ""

        pause_for_operator "Ejecutá el switch de F5 y DNS, luego presioná ENTER"
        timeline "SWITCH — F5 + DNS ejecutado por operador"

        # ---- FASE DURANTE ---------------------------------------------------
        log ""
        log "════════════════════════════════════════"
        log "  FASE 2/3: DURANTE (CMZ activo)"
        log "════════════════════════════════════════"
        timeline "FASE DURANTE — inicio"

        # Primer snapshot inmediato
        "$DRP_SCRIPT_DIR/during/during.sh"
        timeline "FASE DURANTE — snapshot 1"

        echo ""
        echo -e "${YELLOW}El ejercicio está en curso. Podés ejecutar snapshots adicionales:${NC}"
        echo -e "  ${CYAN}./run-dr-exercise.sh --during${NC}  (en otro terminal)"
        echo ""

        pause_for_operator "Validá el comportamiento en CMZ y presioná ENTER cuando estés listo para el failback"
        timeline "DURANTE — validación OK, iniciando failback"

        # ---- SWITCH BACK ----------------------------------------------------
        echo ""
        echo -e "${BOLD}════════════════════════════════════════${NC}"
        echo -e "${BOLD}  FAILBACK: F5 LTM + DNS → PGA${NC}"
        echo -e "${BOLD}════════════════════════════════════════${NC}"
        echo ""
        echo -e "  Acciones a ejecutar por operador:"
        echo -e "  ${YELLOW}1. Deshabilitar VIPs en F5 LTM de CMZ${NC}"
        echo -e "  ${YELLOW}2. Habilitar VIPs en F5 LTM de PGA${NC}"
        echo -e "  ${YELLOW}3. Restaurar DNS de $AGNOSTIC_FQDN → IPs de PGA${NC}"
        echo ""

        pause_for_operator "Ejecutá el failback de F5 y DNS, luego presioná ENTER"
        timeline "FAILBACK — F5 + DNS restaurado"

        # ---- FASE POST ------------------------------------------------------
        log ""
        log "════════════════════════════════════════"
        log "  FASE 3/3: POST (validación)"
        log "════════════════════════════════════════"
        timeline "FASE POST — inicio"

        "$DRP_SCRIPT_DIR/post/postcheck.sh"
        timeline "FASE POST — completada"

        # ---- FIN ------------------------------------------------------------
        timeline "FIN — Ejercicio DRP completo"

        echo ""
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}${BOLD}  EJERCICIO DRP COMPLETADO${NC}"
        echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  Evidencia almacenada en: ${CYAN}$DRP_EXERCISE_DIR${NC}"
        echo ""
        echo "  Estructura:"
        echo "    pre/       → baseline antes del switch"
        echo "    during/    → snapshots durante CMZ activo"
        echo "    post/      → estado post-failback"
        echo "    timeline.txt → log cronológico del ejercicio"
        echo ""
        cat "$TIMELINE_FILE"
        ;;

    *)
        echo "Uso: $0 [--pre|--during|--post|--war-room|interactive]"
        exit 1
        ;;
esac
