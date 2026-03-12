# API Gateway para IA — cluster arqlab

Este directorio documenta y (cuando existan) contiene los manifiestos del **API Gateway preparado para IA** desplegado en el cluster **arqlab**.

## Rol

- **Exponer** un endpoint OpenAI-compatible (`/v1/chat/completions`, etc.) consumible desde **VS Code (Windows)** con Continue.dev.
- **Backend**: el servicio vLLM (GLM-4.7-Flash) desplegado en **IBM CDP**, accesible vía **NodePort** (ej. `http://<ip-nodo-cdp>:<nodePort>`).

Flujo: **VS Code (Windows) → API GW en arqlab → vLLM en IBM CDP (NodePort)**.

## Configuración del backend

El API GW debe configurarse con la URL del vLLM en IBM CDP:

- Tras desplegar vLLM en CDP, obtener la IP de un nodo worker y el NodePort del Service:
  ```bash
  oc get svc -n vllm-models vllm-glm-47-flash
  oc get nodes -o wide
  ```
- URL de backend: `http://<node-ip>:<nodePort>` (ej. `http://10.1.2.3:30080`).
- La conectividad de red entre el cluster arqlab y los nodos de IBM CDP debe permitir acceso a ese NodePort (firewall, rutas, etc.).

## Contenido previsto

- Descripción del producto/componente elegido como API GW para IA (ej. Kong, APIM, Envoy, o solución específica “preparada para IA”).
- Manifiestos de despliegue en arqlab (Deployment/StatefulSet, Service, Ingress/Route, ConfigMap con la URL del backend vLLM).
- Instrucciones para actualizar la URL del backend si cambia el NodePort o el nodo.

Cuando se definan el componente y los YAML, se añadirán en este directorio (p. ej. `manifests/` o ficheros concretos).
