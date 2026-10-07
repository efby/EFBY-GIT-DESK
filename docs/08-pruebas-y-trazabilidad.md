# EfbyGitDesk — pruebas y trazabilidad

Referencia: [producto y requisitos](01-producto-y-requisitos.md). Fecha: 6 de octubre de 2026. El plan verifica el comportamiento observable y la integridad del repositorio; no replica internamente cada implementación.

## 1. Estrategia y entorno

Dominio y casos de uso utilizan puertos simulados en paquetes Swift. Los adaptadores se prueban con Git real en carpetas temporales: repositorio local, remoto bare y dos clones para comprobar diferencias, hooks, rechazos y carreras sin Internet ni credenciales reales. Los contratos Bitbucket Cloud usan respuestas controladas; una prueba optativa contra una cuenta exclusiva valida el contrato real.

Fixtures reproducibles y versionados: repositorio vacío; historial lineal; ramas divergentes; merge con dos padres; raíces sin ancestro común; archivos añadidos/borrados/renombrados; nombres Unicode, espacios y caracteres especiales; CRLF; enlaces simbólicos y cambios de modo donde el sistema lo admita; binario; puntero LFS; submódulo; clon shallow; worktree vinculado; estado de merge/rebase incompleto. Las configuraciones locales de prueba aíslan identidad, hooks y firma de las preferencias reales del usuario.

Rendimiento usa 100.000 commits y un diff grande. Registrar equipo, macOS, Git, tamaño de archivos y caché. La matriz de CI cubre las versiones de macOS y arquitecturas de CPU declaradas; Windows, Linux y Data Center están fuera del alcance.

## 2. Catálogo de casos

| ID | Caso y evidencia de aprobación |
|---|---|
| **T-01** | Registro, ruta equivalente, búsqueda, favoritos/grupos, recientes, pestañas y confianza persistida; quitar registro conserva carpeta y hashes de archivos. Apertura o credenciales heredadas no conceden confianza. Ruta movida/inaccesible muestra estado recuperable. |
| **T-02** | Capacidades de token, SSH y conexión heredada: transporte sin API funciona; API sin permisos Git no se presenta como autorización de push. Simular expiración, permiso insuficiente y host SSH nuevo/cambiado. |
| **T-03** | Catálogo Bitbucket Cloud con paginación, filtros, rate limit, timeout y 401/403. `next` o redirección a otro origen se rechaza sin reenviar Authorization. Clone por catálogo/URL usa `--no-checkout` y hooks vacíos; antes de confiar no se ejecutan filtros ni checkout. Destino no vacío, fallo parcial y cancelación conservan archivos existentes. |
| **T-04** | Repositorio confiable sin red: abrir, historial y diff funcionan; fetch/pull/push fallan explícitamente. Upstream/ahead/behind indican datos almacenados y fecha de verificación. Sin confianza solo se permite inspección restringida de objetos/historial. |
| **T-05** | Crear/checkout/borrar rama. Bloqueos por rama activa, worktree vinculado, commits no integrados y cambios que impedirían checkout; hashes del trabajo permanecen iguales. |
| **T-06** | Fetch actualiza referencias y contadores sin tocar HEAD, índice ni archivos. Prune solo ocurre al seleccionarlo. |
| **T-07** | Pull fast-forward, sin upstream y divergente. En divergencia no aparecen commits de merge, rebase, stash ni cambios en archivos. |
| **T-08** | Push inicial con upstream, push normal y rechazo non-fast-forward/protección del servidor. Destino visible coincide con la referencia modificada; rechazo conserva commits locales. |
| **T-09** | Stage/unstage/commit con parte del trabajo preparado; primer commit, índice vacío y mensaje vacío. El árbol confirmado coincide exactamente con el índice previsto. |
| **T-10** | Historial paginado/virtualizado y copia de SHA completo. Detectar shallow y objetos faltantes; búsqueda comunica si su alcance es local o parcial. |
| **T-11** | Selección de cero, uno, dos, dos iguales y tercer commit. Solo el par distinto permite comparar; tercer intento conserva el par. Seleccionar en cualquier orden mantiene A inferior y B superior del historial. Los documentos aparecen en paralelo, con líneas alineadas y desplazamiento vertical sincronizado. |
| **T-12** | Comparar árboles de commits adyacentes, no adyacentes, merge, ramas divergentes y raíces sin ancestro común. Inventario y patch coinciden con Git real A→B; no interviene merge-base. |
| **T-13** | Worktree/índice e índice/HEAD; añadido, borrado, rename, binario, LFS, submódulo, modo, enlace, Unicode/CRLF y archivo grande. Todas las rutas aparecen; los formatos sin diff textual muestran resumen o límite. |
| **T-14** | Amend de mensaje local: SHA distinto, árbol, padres y autor iguales, referencia de recuperación válida; índice preparado y operación incompleta bloquean. Verificar también HEAD raíz y merge. Fallo de hook/firma conserva el estado conocido. |
| **T-15** | Edición publicada: tip remoto verificado, confirmación del destino y lease explícito. Segundo clon avanza tras fetch: publicación se rechaza. Probar push URL diferente de fetch URL, varios destinos y respuesta perdida después de recibir el push: consultar referencia antes de reintentar. Rama protegida, HEAD modificado externamente y commit que ya no es tip conservan recuperación local. |
| **T-16** | Hooks que aceptan/rechazan y firma activada, ausente o fallida; hooks no se omiten. Una firma antigua nunca se copia al commit editado. Aislar claves de prueba temporales. |
| **T-17** | PTY/AppKit y biblioteca de terminal elegida tras H0: shell, directorio, entrada/salida, Unicode, resize, Ctrl+C, cierre y salida. Sin confianza no se crea shell. Commit/checkout por terminal refresca UI; durante amend se pausa nueva entrada, conservando output y posibilidad de interrumpir. Secuencias que intentan copiar al portapapeles/abrir enlaces o acciones nativas no actúan sin autorización. No reaparece un proceso vivo tras reiniciar. |
| **T-18** | Dos escrituras UI concurrentes, lock externo y cambios desde terminal durante lectura/escritura. Precondiciones se revalidan; locks no se borran. Cancelación y cierre distinguen efectos completados, pendientes o desconocidos. |
| **T-19** | Argumentos con metacaracteres no se ejecutan como shell; rutas/operaciones se validan entre capas. Repo sin confianza con hooks, filtros, fsmonitor, diff externo, textconv y verificador de firma maliciosos: no aparece ningún marcador; working copy, shell y red siguen bloqueados. Partial clone no realiza lazy fetch; replacement refs no sustituyen objetos comparados. Capacidades de endurecimiento ausentes se detectan. El clon autorizado respeta T-03. Secretos no aparecen en preferencias, errores, logs ni diagnóstico. |
| **T-20** | Dependencias/contratos: dominio/aplicación sin imports de infraestructura; adaptadores Git, API Cloud, Keychain, PTY y SQLite cumplen puertos/errores. UI respeta MainActor, actores serializan operaciones; no se presupone un renderer ni IPC. Si se incorpora XPC, añadir su contrato al alcance. |
| **T-21** | Rendimiento: latencia de historial/scroll frente a RNF-04, cancelación de diff grande y UI utilizable durante Git/red. Reportar percentiles y memoria; un timeout no se presenta como resultado completo. |
| **T-22** | Recorrido por teclado, foco al abrir/cerrar paneles, VoiceOver y estados distinguibles sin color. Verificar controles deshabilitados y sus motivos. |
| **T-23** | Instalación/arranque/desinstalación y detección de Git en macOS; rutas, PTY, Keychain, firma y configuración incompatible. Keychain bloqueado/denegado ofrece sesión en memoria sin guardar secretos en texto plano. Verificar arranque desde Finder, versiones/CPU declaradas y acceso a credenciales después de actualizar un build firmado. Migrar preferencias conserva registros, confianza y distribución. |
| **T-24** | Sesión de aceptación: abrir o clonar, rama, commit, fetch/pull/push, SHA, comparación, edición de mensaje y terminal. Fallos recuperables permiten continuar; diagnóstico redactado correlaciona la operación correcta. |

## 3. Matriz de cobertura

| Requisito | Pruebas mínimas |
|---|---|
| RF-01 | T-01, T-19, T-23, T-24 |
| RF-02 | T-02, T-19, T-23 |
| RF-03 | T-03, T-19, T-24 |
| RF-04 | T-04, T-18, T-19 |
| RF-05 | T-05, T-18, T-24 |
| RF-06 | T-06, T-18, T-24 |
| RF-07 | T-07, T-18, T-24 |
| RF-08 | T-08, T-18, T-24 |
| RF-09 | T-09, T-16, T-18, T-24 |
| RF-10 | T-10, T-21, T-24 |
| RF-11 | T-11, T-12, T-13, T-24 |
| RF-12 | T-13, T-21 |
| RF-13 | T-14, T-15, T-16, T-18, T-24 |
| RF-14 | T-17, T-18, T-23, T-24 |
| RF-15 | T-18, T-24 |
| RF-16 | T-01, T-17, T-22, T-23 |
| RNF-01 | T-20 |
| RNF-02 | T-02, T-03, T-17, T-19, T-20 |
| RNF-03 | T-01, T-03, T-05, T-14, T-15, T-18 |
| RNF-04 | T-21 |
| RNF-05 | T-22 |
| RNF-06 | T-10, T-13, T-23 |
| RNF-07 | T-19, T-24 |
| RNF-08 | T-20, T-23 |

## 4. Ejecución, evidencia y criterio de salida

Cada cambio ejecuta pruebas relevantes; el adaptador Git añade integración real. Un candidato ejecuta el catálogo, UI/PTY y empaquetado en las versiones/CPU macOS soportadas. La integración Cloud usa exclusivamente repositorios de pruebas.

Conservar resultado, versión, fixture, entorno y evidencia de integridad, sin secretos. Ediciones de mensajes y publicaciones se verifican leyendo objetos/referencias locales y remotas.

Salida: todos los RF P0 trazados y aprobados, cero defectos abiertos de pérdida de datos, ejecución sin confianza, credenciales expuestas o publicación incorrecta, y cero bloqueos de aceptación. Un requisito no ejecutado se registra como **pendiente**, nunca aprobado. Límites del visor, versiones/CPU de macOS y funciones no soportadas se publican con la versión. Este documento es un plan; no afirma que el software ni las pruebas ya estén implementados o ejecutados.
