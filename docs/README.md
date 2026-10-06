# EfbyGitDesk — documentación para construir el programa

**Versión:** 0.1 · **Fecha:** 6 de octubre de 2026 · **Estado:** especificación inicial completa para revisión e implementación. **Nombre confirmado por el usuario:** EfbyGitDesk.

## Alcance confirmado

Aplicación de escritorio **solo macOS**, con **Bitbucket Cloud** como integración remota inicial y **Clean Architecture** en todo el proyecto. Permitirá abrir y organizar repositorios, clonar desde Bitbucket, heredar una conexión Git existente o usar token/SSH, gestionar ramas, fetch/pull/push, preparar archivos y crear commits, copiar SHA y usar un terminal inferior.

La comparación admite **exactamente dos commits distintos**, con A base y B destino. Compara sus árboles directamente y conserva el inventario de todos los archivos cambiados, aunque algún contenido no admita diff textual. Los cambios locales tienen una vista propia de working tree e índice.

La edición solicitada cambia el **mensaje del último commit de la rama, también cuando ya fue publicado**. Se limita a una punta remota coincidente, conserva árbol/padres/autor, crea recuperación local y publica con una lease ligada al OID verificado. El nuevo mensaje cambia el SHA; una política del servidor puede impedir la reescritura.

## Qué contiene esta entrega

| Documento | Para qué sirve |
|---|---|
| [01 — Producto y requisitos](01-producto-y-requisitos.md) | Alcance, MVP, 16 requisitos funcionales, 8 no funcionales y aceptación |
| [02 — Arquitectura Clean](02-arquitectura-clean.md) | Capas, módulos, ejecución nativa, concurrencia, terminal y dependencias |
| [03 — UX, pantallas y flujos](03-ux-pantallas-y-flujos.md) | Gestor de repositorios, vista principal, comparación, terminal y estados |
| [04 — Dominio, datos y contratos](04-dominio-datos-y-contratos.md) | Entidades, puertos, entradas/salidas, persistencia, eventos y errores |
| [05 — Git y Bitbucket](05-git-y-bitbucket.md) | Semántica Git, autenticación actual, API Cloud, clone, diff y amend/push |
| [06 — Seguridad y credenciales](06-seguridad-y-credenciales.md) | Keychain, SSH, confianza, ejecución, terminal, registro y recuperación |
| [07 — Plan de desarrollo](07-plan-de-desarrollo.md) | Hitos H0–H6, historias, dependencias, normas del equipo y CI |
| [08 — Pruebas y trazabilidad](08-pruebas-y-trazabilidad.md) | 24 casos de prueba y relación con todos los requisitos |
| [09 — Operación, distribución y manual](09-operacion-distribucion-y-manual.md) | Instalación prevista, uso, diagnóstico, backups, recuperación y release |
| [10 — Decisiones, riesgos y fuentes](10-decisiones-riesgos-y-fuentes.md) | Decisiones confirmadas, 10 ADR propuestos, pendientes y fuentes primarias |
| [Referencia — Vista principal](referencias/01-vista-principal.png) | Mockup proporcionado por el usuario |
| [Referencia — Gestor de repositorios](referencias/02-gestor-repositorios.png) | Mockup proporcionado por el usuario |

Para revisar producto, leer 01 y 03. Para implementar, seguir 02, 04, 05 y 06, luego tomar historias de 07 con su evidencia en 08. El manual 09 describe el comportamiento esperado de la futura app. El registro 10 distingue decisiones aceptadas de recomendaciones.

## Propuesta técnica

Swift 6.2 o posterior, SwiftUI con AppKit donde haga falta, Git instalado en el equipo, SQLite del sistema y Keychain. Se evaluará SwiftTerm como candidato para terminal PTY; no se incorporó ninguna dependencia en esta entrega. macOS mínimo, soporte Intel/Apple Silicon y versiones concretas se validan en el primer prototipo.

Los grupos/favoritos son organización local; no equivalen a workspaces de Bitbucket. SSH y credenciales heredadas pueden permitir transporte Git sin acceso al catálogo API. Las imágenes orientan la composición, pero sus textos/botones no añaden funciones al alcance. IA, pipelines, pull requests, nube, Data Center, otros proveedores y asistentes de rebase/merge quedan fuera del MVP.

El terminal permite comandos del usuario con sus permisos. La integración gestionada de la UI solo admite Bitbucket Cloud; los comandos escritos voluntariamente en la shell no se restringen a un proveedor. Repositorios locales pueden inspeccionarse sin red; conexiones no soportadas se identifican antes de acciones remotas de la UI.

## Estado de validación

La documentación se revisó para coherencia de alcance, contratos y referencias. Se comprobó que la matriz cubra los 24 requisitos con casos de prueba existentes y que los enlaces locales del paquete resuelvan. Las políticas de autenticación/API se contrastaron con fuentes oficiales vigentes a la fecha indicada.

No existe todavía una aplicación, ni se ejecutaron pruebas del programa o conexiones con una cuenta Bitbucket real. Las métricas y criterios QA son objetivos de aceptación. La siguiente actividad de implementación es **H0: viabilidad nativa**, que valida terminal, Git heredado, Keychain y distribución desde Finder antes de desarrollar el resto.

Los archivos Markdown son la fuente editable. El dossier unificado y el ZIP son copias generadas para lectura y traslado; se regeneran al cambiar los documentos.
