# EfbyGitDesk 0.1.0 — estado del MVP

Fecha: 6 de octubre de 2026. Versión de desarrollo; H6 y el criterio de release permanecen pendientes.

## Decisiones adoptadas en la implementación

- Swift 6 con concurrencia estricta, SwiftUI/Observation y AppKit para texto y terminal. Targets independientes de dominio, aplicación, infraestructura, presentación, composición y helper de credenciales.
- Git CLI por argumentos y pipes; drenaje simultáneo, salida acotada, timeout, cancelación y terminación de procesos propios. Las lecturas untrusted no ejecutan herramientas de working tree ni lazy fetch.
- Git 2.40 o posterior, comprobado al iniciar. Entorno de desarrollo verificado: Swift 6.4, Git 2.51, macOS 26.6.2, arm64. El mínimo de compilación macOS 14 no equivale a ejecución verificada en ese sistema.
- SQLite del sistema para catálogo, preferencias y journal. Migración v1 y rechazo de esquemas futuros; no se reanudan escrituras al reiniciar. La confianza incluye directorio canónico e identidad de dispositivo/inodo; sustituir `.git` revoca la confianza recordada.
- Keychain para tokens y referencias de operación efímeras. El helper recibe una referencia, no el token en argumentos ni entorno. Validación estricta del origen de la solicitud de credenciales, de URLs REST y de enlaces de paginación; redirecciones HTTP deshabilitadas.
- PTY propio con entrada/salida, resize, UTF-8, Ctrl+C y secuencias VT básicas. No se incorporó SwiftTerm ni otra dependencia externa. Las secuencias OSC no realizan acciones nativas; se revisa el pegado multilínea. No es todavía un emulador xterm completo.
- Paquete `.app` para desarrollo, con helper y firma ad hoc verificada. Sin App Sandbox. Developer ID, notarización, DMG e Intel/universal no se declaran aprobados.

## Funciones y trazabilidad

| RF | Implementación actual | Evidencia / límite |
|---|---|---|
| RF-01 | Registro, pestañas, búsqueda, favoritos, grupos, recientes y confianza | SQLite real; quitar conserva archivos; sustitución de `.git` revoca confianza. Recorrido completo de pestañas pendiente de QA manual. |
| RF-02 | SSH/helpers heredados y API token en Keychain | Keychain CRUD probado con valor ficticio. Cuenta real y acceso del helper desde distribución pendientes. |
| RF-03 | Catálogo paginado y clonación sin checkout | Fixtures REST: páginas, origen externo y errores; Git real: destino existente rechazado, checkout posterior. |
| RF-04 | Inspección local offline y restricciones de confianza | Historia/diff locales y prueba de fsmonitor sin ejecución antes de confiar. |
| RF-05 | Crear, cambiar y borrar ramas integradas | Checkout bloqueado conserva bytes; worktree vinculado no se modifica. |
| RF-06 | Fetch de ramas a referencias remotas, sin prune ni checkout | Integración con remoto bare; destino capturado y validado. |
| RF-07 | Pull fast-forward | Divergencia no crea merge ni descarta contenido; rama/HEAD revalidados tras fetch. |
| RF-08 | Push de SHA y rama explícitos, upstream opcional | Git real en fixtures de publicación; servidor Bitbucket y protección de ramas pendientes. |
| RF-09 | Stage/unstage por archivo y commit del índice | Primer commit, nombres especiales, rename completo y hook rechazado preservando índice. |
| RF-10 | Historial paginado, búsqueda, grafo y copia de SHA completo | Objetos Git reales SHA-1 y SHA-256; fixture de 100.000 commits. Copia y teclado requieren completar QA manual. |
| RF-11 | Selección limitada a dos commits, A→B e intercambio | Árboles sin ancestro común, merges y raíz; nunca merge-base. La tercera selección conserva el par. |
| RF-12 | Diff unificado, lista de rutas, índice/HEAD y worktree/índice | Rename y binario; resúmenes para LFS/submódulos/enlaces. Límite textual visible de 2 MB; inventario hasta 16 MB o error explícito, sin afirmar completitud de salida truncada. |
| RF-13 | Plan de un solo uso, caducidad 60 s, recuperación y lease exacta | Árbol/autor/padres preservados; HEAD nuevo, índice preparado, avance remoto y carrera durante push. Tras interrupción de publicación se consulta el destino antes de considerar reintento. |
| RF-14 | Terminal PTY por repositorio, sesiones, ocultación y cierre confirmado | PTY real: directorio, UTF-8, resize, Ctrl+C, entrada pausada y salida. Refresco cada 4 s/foco. Compatibilidad VT avanzada pendiente. |
| RF-15 | Permiso por commonGitDir mantenido durante await, journal, cancelación | 20 escritores serializados; lock externo conservado; pipes simultáneos, SIGTERM ignorado y handles heredados acotados. |
| RF-16 | Preferencias, paneles, terminal y pestañas persistidos; controles accesibles | Persistencia SQLite y ventana nativa observadas. VoiceOver, foco completo y restauración visual tras reinicio pendientes. |

## Pruebas ejecutadas

**Resultado final:** 38 pruebas aprobadas en 10 suites, sin omisiones, en una ejecución conjunta con benchmark y Keychain habilitados. Tiempo de pruebas: 5,551 s (excluye compilación). La regresión posterior al aislamiento de clone aprobó los 36 casos esenciales; los dos optativos conservaron su evidencia de ejecución separada.

Se implementaron pruebas Swift Testing de dominio, almacenamiento/procesos, integración Git, recuperación, terminal, REST con fixtures, coordinación, compatibilidad, rendimiento y Keychain. Cada fixture Git utiliza una carpeta temporal y configuración/identidad/hook/firma de prueba. El transporte a remoto local está habilitado solo en el adaptador de pruebas; la composición de la aplicación lo mantiene deshabilitado.

El benchmark genera exactamente 100.000 commits y consulta seis veces una página de 100 mediante el mismo adaptador del producto. Mediciones iniciales en debug: **0,312–0,323 s**. No se controló la caché fría del sistema ni se midió p95 de interacción o memoria de la UI: esas partes de RNF-04 permanecen pendientes. `scripts/test.sh` omite por defecto benchmark y Keychain; sus variables optativas están documentadas en README.

Keychain se probó creando, leyendo y eliminando una entrada ficticia `fixture.<UUID>`. No se utilizaron credenciales de cuentas ni se dejó esa entrada almacenada. Esto verifica el adaptador de almacenamiento, no una autenticación real ni el ACL del helper después de actualizar una firma.

La ventana `.app` se abrió mediante LaunchServices y se observó la interfaz nativa: registro, historial, ramas y diff. Las pruebas automáticas no sustituyen la sesión completa T-24 ni la evaluación T-22 con VoiceOver.

## Límites y pendientes para beta/release

- Cuenta/repositorio de pruebas Bitbucket: token, catálogo real, SSH/huellas, permisos insuficientes, ramas protegidas y recuperación tras respuesta perdida de servidor. La referencia oficial usada para el catálogo es [List repositories in a workspace](https://developer.atlassian.com/cloud/bitbucket/rest/api-group-repositories/#api-repositories-workspace-get); no se deducen permisos de push del listado.
- Helper Keychain dentro del paquete firmado, actualización de credenciales y cuenta con Keychain bloqueado. No existe todavía el modo de credenciales solo en memoria previsto en T-23.
- Pantallas completas de terminal, colores/atributos ANSI, ancho de caracteres complejos y aplicaciones curses; cierre de procesos que se disocien explícitamente de la sesión no está garantizado por cerrar el PTY.
- Diagnóstico exportable/revisable y presentación de entradas pendientes del journal. La versión actual guarda fases y recuperación, sin telemetría ni tokens en SQLite, pero no ofrece aún una pantalla de recuperación del journal.
- QA de teclado, VoiceOver, restauración de layout, múltiples ventanas y sesión de aceptación de punta a punta.
- Caché fría, p95 de interacción, memoria y cancelación con repositorios de tamaño real; rendimiento de dibujo del grafo en historiales muy ramificados.
- Ejecución en macOS 14 e Intel; firma Developer ID, notarización, instalador y verificación del mismo artefacto distribuido.

Bare/sparse checkout se rechazan; worktrees vinculados, shallow/partial clone y submódulos abiertos como repositorios quedan en inspección. Los objetos ausentes dan diagnóstico sin descargas implícitas. La red está limitada a Bitbucket Cloud, aunque el código de desarrollo se aloje en GitHub.

## Recuperación y datos locales

Las referencias de edición se conservan bajo `refs/efbygitdesk/backups/<UUID>`. Ante publicación fallida, consultar HEAD y la referencia remota antes de volver a intentar. El programa no realiza reset ni rollback automático. Cancelar puede dejar cambios ya ejecutados y requiere reconciliar el estado real.

El catálogo está en `~/Library/Application Support/EfbyGitDesk/catalog.sqlite`; contiene metadatos y journal, no tokens. Las sesiones y la salida del terminal no se restauran ni persisten. Quitar registros/perfiles conserva repositorios. Las claves privadas y públicas del repositorio de desarrollo permanecen fuera de Git.
