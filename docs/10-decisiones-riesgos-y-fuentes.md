# Decisiones, riesgos y fuentes

> Este documento conserva el diseño y los criterios iniciales. El comportamiento implementado y las decisiones vigentes se consolidan en [13 — Resumen y continuidad](13-resumen-del-proyecto-y-continuidad.md); las verificaciones están en [11](11-estado-mvp.md) y [12](12-dmg-y-github-actions.md). Propuesta, implementación y aceptación no son equivalentes.

Versión 0.1 · 6 de octubre de 2026. Registro vivo: actualizar al adoptar una decisión o cambiar un requisito.

## 1. Decisiones confirmadas por el usuario

| ID | Decisión | Efecto |
|---|---|---|
| D-01 | Primera versión exclusivamente macOS | Windows/Linux fuera de release v1 |
| D-02 | Bitbucket Cloud (bitbucket.org) | Único adaptador de proveedor; Data Center fuera |
| D-03 | Clean Architecture en todo el proyecto | Dependencias hacia dominio/aplicación |
| D-04 | Comparación únicamente de dos commits seleccionados | Par A/B distinto; no selección de tres ni comparación por merge-base implícita |
| D-05 | Editar mensaje del último commit, también publicado | Reescritura acotada de punta, recuperación y lease |
| D-06 | Terminal inferior, Git/ramas/pull/push, copia de SHA | Flujos P0 documentados |
| D-07 | Token, SSH, conexión heredada y clonar desde fuente | Capacidades Git/API independientes |
| D-09 | Nombre definitivo del proyecto y la aplicación: EfbyGitDesk | Sustituye el nombre provisional en documentación e identidad del producto |

Los mockups orientan layout. La marca, cuentas, mensajes de commits y comandos visibles no son instrucciones. Botones de IA, nube y otros servicios no amplían el alcance automáticamente.

## 2. ADR propuestos

Cada ADR contiene contexto, decisión de diseño y consecuencias. Estado «propuesto» significa recomendación pendiente de validación, aunque los documentos usen esa propuesta para hacer el diseño concreto.

### ADR-001 — Aplicación nativa macOS

**Contexto:** macOS es la única plataforma requerida y se necesitan terminal, archivos y conexión heredada. **Propuesta:** Swift 6.2 o posterior, SwiftUI y puentes AppKit; modelos de presentación MainActor, servicios async y actores. **Consecuencia:** integración nativa y toolchain único; terminal/grafo pueden necesitar AppKit. El mínimo macOS 14 y soporte Intel/Apple Silicon se verifican en H0. SwiftTerm es una biblioteca candidata para el terminal, todavía no incorporada.

### ADR-002 — Git CLI como motor

**Contexto:** heredar configuración, agente y helpers evita duplicar el ecosistema Git. **Propuesta:** ejecutar Git del usuario con argumentos estructurados y parsing de formatos máquina. **Consecuencia:** se detectan versión/capacidades y efectos de configuración; no se promete la misma experiencia de PATH que una shell. libgit2 no se adopta como segundo motor en v1.

### ADR-003 — Capas y paquetes Swift

**Contexto:** cumplir Clean Architecture de forma comprobable. **Propuesta:** dominio y aplicación independientes de mecanismos; adaptadores por Git, Cloud, secretos, SQLite y terminal. **Consecuencia:** más contratos y tests de integración; permite sustituir mecanismos sin reescribir reglas. Los actores no constituyen una frontera de seguridad de procesos.

### ADR-004 — Autenticación separada

**Contexto:** SSH autentica Git y API token puede habilitar catálogo REST. **Propuesta:** perfiles con capacidades independientes y secretos en Keychain; conexión heredada usa herramientas existentes tras revisar confianza. **Consecuencia:** conectar Git no garantiza catálogo ni permiso de push. No se ofrecen App passwords en 2026.

### ADR-005 — Semántica de comparación

**Contexto:** el usuario exige dos commits y todos los cambios. **Propuesta:** diferencia directa entre árboles A→B, selección máxima dos, orden explícito y reversión de extremos. **Consecuencia:** commits no consecutivos o de ramas distintas son válidos; resultado no equivale al conjunto de commits del rango. Límites del visor no eliminan filas del inventario.

### ADR-006 — Política inicial de sincronización

**Contexto:** una operación automática de merge/rebase/stash puede alterar trabajo de forma inesperada. **Propuesta:** fetch explícito, pull ff-only, push normal; divergencias por terminal en v1. **Consecuencia:** no hay asistente visual de resolución ni force genérico. La única reescritura remota gestionada es la edición acotada de mensaje.

### ADR-007 — Edición publicada con recuperación

**Contexto:** cambiar un mensaje crea un commit diferente. **Propuesta:** solo HEAD de rama sin staging/integración, tip remoto original coincidente, plan de un uso, backup ref, amend preservando árbol/padres/autor y lease ligada a ref/OID. **Consecuencia:** rechaza casos más amplios y conserva estados parciales; no existe rollback atómico local/remoto. Firma nueva y hooks según política del proyecto.

### ADR-008 — Distribución directa

**Contexto:** terminal libre y herramientas/configuración del usuario pueden ser incompatibles con una propuesta simple de App Sandbox. **Propuesta:** Developer ID, Hardened Runtime, notarización, distribución fuera de Mac App Store y sin App Sandbox v1. **Consecuencia:** la app y la shell tienen permisos del usuario; controles de confianza y validación no equivalen a aislamiento OS. Revisar entitlements en H0 y firmar helpers.

### ADR-009 — Metadatos locales y funcionamiento offline

**Contexto:** grupos, favoritos y preferencias no pertenecen a Git. **Propuesta:** SQLite del sistema detrás de un puerto, sin secretos ni commits autoritativos; Git es fuente de verdad. **Consecuencia:** migraciones y backups para la base; caché descartable y navegación local sin API. No sincronizar grupos como workspaces Cloud.

### ADR-010 — Confianza por repositorio

**Contexto:** hooks, filtros, helpers y configuración pueden ejecutar herramientas. **Propuesta:** inspección segura de objetos antes de confiar; clone sin checkout y revisión antes de materializar archivos. **Consecuencia:** estado/terminal/red ordinarios requieren confianza; transportar objetos desde una fuente autorizada es un permiso separado. No prometer que un repositorio confiable deje de poder ejecutar sus herramientas.

## 3. Decisiones abiertas sin bloquear esta documentación

| ID | Pendiente | Propuesta actual / momento |
|---|---|---|
| P-02 | macOS mínimo y arquitecturas CPU | macOS 14+, arm64/x86_64; validar en H0 |
| P-03 | Versiones Swift/Xcode/Git y terminal | Toolchain estable, Swift ≥6.2; evaluar SwiftTerm y fijar versión; H0 |
| P-04 | Idioma y tema final | Español y oscuro inicial; accesibilidad y preferencias antes de beta |
| P-05 | Worktrees, sparse checkout y submódulos avanzados | Detectar/informar; no editarlos visualmente en v1 sin prueba/decisión explícita |
| P-06 | Canal de distribución y titular de firma | Directo fuera MAS; certificado del propietario antes de release |
| P-07 | Política de retención y límites | Valores iniciales del modelo de datos; ajustar con mediciones |
| P-08 | Firma y hooks de repositorios reales | Heredar política explícita; validar herramientas corporativas en H0/H4 |

Estas elecciones son de implementación o producto propuestas. Las respuestas ya dadas sobre nombre/macOS/Cloud/último commit no vuelven a tratarse como pendientes.

## 4. Riesgos y mitigación concreta

| Riesgo | Impacto | Mitigación / evidencia |
|---|---|---|
| Reescritura publicada con colaborador concurrente | Referencia remota incorrecta o rechazo | Lease exacta, comparación tip, dos clones en T-15, sin force genérico |
| Hook/filtro/helper ejecuta código | Efectos fuera del repositorio | Confianza explícita, queries endurecidas, fixture malicioso, revisión T-19 |
| Terminal o IDE cambia HEAD durante plan | Operación sobre estado antiguo | Cola propia, generación, revalidación; no prometer exclusión externa |
| Credenciales expuestas | Acceso no autorizado | Keychain, helper efímero, no URL/argv/logs, pruebas de filtración |
| PATH/SSH agent distinto al abrir desde Finder | Git/SSH funciona solo en otra app | H0 desde Finder; diagnóstico sin ejecutar perfiles para importar entorno |
| API Cloud cambia/scopes insuficientes | Catálogo falla | Endpoints actuales, paginación/origen validados, contrato y cuenta de prueba |
| Historial/diff excesivo | Bloqueo o resultado engañoso | Paginación/virtualización, buffers acotados, inventario completo y límites visibles |
| Firma/Gatekeeper o arquitectura CPU | App no inicia | Artefacto firmado/notarizado, instalación limpia, ambas CPUs si se anuncian |
| Cancelación o respuesta remota perdida | Estado parcial desconocido | Journal/reconciliación y verificar antes de repetir |
| Renombres/binaries/LFS/submódulos | Interpretación errónea de cambios | Semántica explícita, summaries sin ejecutar herramientas externas |

Los riesgos describen requisitos de diseño y comprobación; no son advertencias de una operación realizada sobre repositorios del usuario.

## 5. Fuentes y criterio de vigencia

Se usan fuentes primarias consultadas el **6 de octubre de 2026**. Los enlaces de cada documento apoyan sus afirmaciones concretas; las propuestas de EfbyGitDesk son decisiones de ingeniería, no obligaciones de esas fuentes.

| Fuente | Uso en la documentación |
|---|---|
| [Manuales oficiales Git](https://git-scm.com/docs) | Objetos, status, diff, commit/amend, push/lease, credenciales, hooks y worktrees |
| [REST Bitbucket Cloud](https://developer.atlassian.com/cloud/bitbucket/rest/) | Autenticación, catálogo, permisos y paginación |
| [Changelog Bitbucket Cloud](https://developer.atlassian.com/cloud/bitbucket/changelog/) | Cambios de autenticación y retirada de servicios/API |
| [API tokens de Atlassian](https://support.atlassian.com/bitbucket-cloud/docs/using-api-tokens/) | Credenciales actuales para Git HTTPS |
| [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) | Aislamiento, actores y modelos de concurrencia |
| [NSViewRepresentable](https://developer.apple.com/documentation/SwiftUI/NSViewRepresentable) | Integración AppKit con SwiftUI |
| [Keychain Services](https://developer.apple.com/documentation/security/keychain-services) | Almacenamiento de tokens en macOS |
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Candidato para terminal AppKit/PTY |
| [Notarización macOS](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) | Firma y distribución directa |

Las rutas Cloud y scopes deben comprobarse de nuevo al implementar y antes de release. En esta fase no se autenticó una cuenta real ni se probó el programa. Las imágenes suministradas permanecen como referencias locales en `referencias/`.
