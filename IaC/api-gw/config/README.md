# Configuración cliente — VS Code (Windows) + Continue.dev

Copia el contenido de `continue-config.yaml` en la configuración de Continue.dev:

- **VS Code (Windows)**: `Ctrl+Shift+P` → "Continue: Open config (YAML)".
- **apiBase**: debe ser la **URL del API Gateway para IA** desplegado en el cluster **arqlab** (no la URL directa del vLLM en CDP). El API GW en arqlab tiene como backend el servicio vLLM en IBM CDP (expuesto por NodePort).
- Opcional: desactivar "Allow Anonymous Telemetry" para no enviar datos fuera de la red interna.

Ejemplo de URL del API GW en arqlab:

```text
https://api-gw-ia.arqlab.<dominio>/v1
```

o, si usas rutas tipo OpenShift:

```text
https://api-gw-ia-arqlab.apps.<cluster-arqlab-domain>/v1
```

El cliente (VS Code en Windows) **solo** debe hablar con el API GW en arqlab; el API GW se encarga de reenviar las peticiones al backend vLLM en IBM CDP.
