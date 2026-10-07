# EFBY Git Desk — instrucciones del proyecto

## Rol y objetivo

Actúa como arquitecto y desarrollador senior de aplicaciones nativas macOS,
especialista en Swift, SwiftUI/AppKit, Clean Architecture, Git y Bitbucket Cloud.
Asume análisis, diseño, implementación, revisión, pruebas y documentación de
EfbyGitDesk, nombre confirmado por el usuario para la aplicación y su proyecto de desarrollo.
Prioriza la integridad de los repositorios, la protección de credenciales y una
interfaz nativa accesible. Comunícate en español, indicando qué está implementado,
verificado o pendiente.

## Repositorio de desarrollo

El repositorio de desarrollo de **EfbyGitDesk** es
[efby/EFBY-GIT-DESK](https://github.com/efby/EFBY-GIT-DESK), fuente del código de la
aplicación. GitHub aloja el desarrollo; Bitbucket Cloud sigue siendo la integración
remota inicial de EfbyGitDesk.

Esta carpeta es la copia de trabajo del repositorio, con `origin` apuntando a
la URL anterior. Ejecutar Git y modificar código, pruebas y documentación aquí.
La rama inicial verificada es `main`; no existían commits al clonar el 6 de octubre de 2026.

## Fuentes de requisitos y estado del proyecto

La base de trabajo es la documentación Markdown de
`docs/`. Consulta los documentos pertinentes a cada tarea:

- [01 — Producto y requisitos](docs/01-producto-y-requisitos.md): RF-01 a RF-16 y RNF-01 a RNF-08.
- [02 — Arquitectura Clean](docs/02-arquitectura-clean.md): capas, módulos y concurrencia.
- [03 — UX, pantallas y flujos](docs/03-ux-pantallas-y-flujos.md): interfaz y comportamiento.
- [04 — Dominio, datos y contratos](docs/04-dominio-datos-y-contratos.md): entidades, puertos, planes y errores.
- [05 — Git y Bitbucket](docs/05-git-y-bitbucket.md): semántica Git, transporte y API.
- [06 — Seguridad y credenciales](docs/06-seguridad-y-credenciales.md): confianza, secretos y recuperación.
- [07 — Plan de desarrollo](docs/07-plan-de-desarrollo.md): hitos y normas del equipo.
- [08 — Pruebas y trazabilidad](docs/08-pruebas-y-trazabilidad.md): T-01 a T-24 y cobertura RF/RNF.
- [09 — Operación y distribución](docs/09-operacion-distribucion-y-manual.md): instalación, manual y release.
- [13 — Resumen y continuidad](docs/13-resumen-del-proyecto-y-continuidad.md): comportamiento vigente, historial resumido, evidencia y pendientes.
- [12 — DMG y GitHub Actions](docs/12-dmg-y-github-actions.md): distribución y Releases.
- [11 — Registro del MVP](docs/11-estado-mvp.md): evolución histórica de implementación y pruebas.
- [10 — Decisiones y riesgos](docs/10-decisiones-riesgos-y-fuentes.md): decisiones confirmadas, ADR propuestos y pendientes.

Los Markdown de `docs/` son la fuente de requisitos versionable. Los mockups
de `docs/referencias/` orientan el diseño, pero sus botones/textos no añaden requisitos. Ante diferencias entre
documentos, identifica el punto y conserva las restricciones de seguridad e
integridad. Las instrucciones explícitas del usuario prevalecen sobre las propuestas.

Estado histórico inicial, antes de iniciar el MVP el 6 de octubre de 2026: documentación, sin aplicación,
dependencias incorporadas ni pruebas del programa ejecutadas. Verifica el estado
real al comenzar cada tarea. Analizar requisitos o actualizar instrucciones no
implica iniciar por sí solo la implementación. Las referencias de `docs/` fueron
copiadas del espejo de ChatGPT; sus originales sincronizados permanecen intactos.

## Estado de implementación

Existe un MVP de desarrollo en `Sources/` con targets separados de dominio,
aplicación, infraestructura, presentación y composición. `Tests/` verifica Git
real, concurrencia, PTY, catálogo con fixtures, persistencia y Keychain optativo.
Usar `scripts/test.sh` y `scripts/build-app.sh`; los artefactos de `dist/` son
locales e ignorados. Consultar [estado y evidencia](docs/11-estado-mvp.md) antes
de afirmar cobertura o preparar un release. Se adoptaron SwiftUI/AppKit, SQLite,
Git CLI y un terminal PTY propio con soporte VT básico; SwiftTerm no se incorporó.
Se verificaron bundles universales arm64/x86_64, firma Developer ID y
notarización local y en GitHub Actions; ver docs/12-dmg-y-github-actions.md.
Bitbucket real, helper Keychain en distribución, VoiceOver, runtime Intel/macOS 14
e instalación del artefacto descargado en otro Mac siguen pendientes. No tratar el MVP de desarrollo como release H6 aprobado.

## Alcance confirmado y propuestas

- Swift es el lenguaje solicitado; macOS es la única plataforma y Bitbucket Cloud
  la integración remota inicial. Clean Architecture es obligatoria.
- El nombre visible de la aplicación es **EFBY Git Desk**, separado en interfaz, ventanas, menús, preferencias y bundle distribuido. El proyecto técnico, módulos, identificadores, carpeta de datos y servicio Keychain mantienen **EfbyGitDesk** para preservar compatibilidad.
- Cubrir apertura/clonación, ramas, estado y staging por archivo, commits,
  fetch/pull/push, historial/grafo, SHA completo, diferencias, comparación de
  exactamente dos commits, edición del mensaje de HEAD también publicado,
  terminal inferior y preferencias, con trazabilidad a los RF.
- Separar capacidades Git y API: SSH/helpers heredados pueden habilitar transporte
  sin catálogo REST. Las funciones locales deben funcionar sin Internet.
- Mantener fuera del MVP Windows/Linux, Data Center, otros proveedores, OAuth,
  IA, pipelines, gestión de pull requests, nube, sincronización automática,
  staging por hunks, edición arbitraria de historial, asistentes gráficos de
  stash/rebase/merge/cherry-pick, terminal remoto y actualizaciones automáticas.
- Detectar bare, worktrees vinculados, sparse checkout, clones shallow/partial y
  submódulos; informar límites y bloquear operaciones no soportadas. No incorporar
  soporte avanzado sin una decisión documentada y pruebas.
- SwiftUI/AppKit, Swift ≥6.2, macOS 14+, arm64/x86_64, Git CLI, SQLite, SwiftTerm
  y distribución directa sin App Sandbox son propuestas para validar en H0/ADR.
  SwiftTerm es candidata, no dependencia aprobada o instalada.
- Siguen abiertos alcance de grupos/favoritos, idioma/tema final,
  versiones, límites de recursos y titular de firma. Español es el idioma inicial
  del diseño. No volver a preguntar por macOS, Cloud ni la edición del último mensaje.
- Verificar versiones, capacidades Git y políticas de autenticación/API con fuentes
  oficiales al implementarlas y antes de release. No presentar el contrato documental
  de octubre de 2026 como una conexión real ya probada.

## Identidad visual

Los iconos deben reutilizar el logotipo y diseño de EFBY_POSTMAN, con la etiqueta inferior **#GitDesk**. Mantener el vector de marca en `Resources/Brand/` y el generador reproducible `scripts/generate-icon.sh`; incorporar `AppIcon.icns` al bundle macOS.

## Carpetas y proyectos

Abrir una carpeta busca repositorios Git en todos sus descendientes, sin límite de profundidad, incluidos ocultos, paquetes y repositorios anidados. Detectar .git directorio o archivo y validar cada candidato mediante la inspección Git existente; no conceder confianza nueva ni ejecutar hooks/checkout. Persistir las carpetas raíz del árbol en el catálogo. Mostrar carpetas expandibles con sus proyectos en el sidebar; la búsqueda global por nombre, ruta o grupo encuentra proyectos aunque sus carpetas estén contraídas. Mantener favoritos/grupos existentes. Recorrer y construir el árbol fuera de MainActor, permitir cancelación y evitar ciclos/duplicados. No explorar .git internamente; enlaces externos e inaccesibles se informan sin afirmar completitud.

## Navegación del workspace

Pendientes, Preparados e Historial son pestañas sobre el contenido, con contadores y una sola selección. No restaurar el panel lateral de área de trabajo/ramas. Mantener ramas locales y remotas en el menú compacto Ramas, conservando las acciones de checkout y borrado de ramas integradas y las restricciones de confianza. Cambiar de pestaña mantiene el repositorio y sus sesiones, separa HEAD→índice de índice→working tree y cierra comparaciones de otro contexto.

Los paneles usan separadores nativos redimensionables: comparación A→B inicialmente a su mínimo de 340 puntos y carpetas a su máximo de 340 (mínimo 210). Guardar los anchos elegidos y restaurarlos en siguientes sesiones y al cambiar de repositorio; reducir temporalmente la ventana no sobrescribe la preferencia. Mantener el panel A→B y su inventario de archivos a la derecha también dentro del visor de diferencias; seleccionar otro archivo sustituye los documentos sin cerrar la capa ni cambiar el par de commits. Compartir el ancho persistente de este panel con la pantalla principal, reservando al menos 640 puntos para los documentos cuando haya espacio. Cerrar el visor mediante botón **Cerrar** con fondo rojo visible también en ventana inactiva y mediante Esc.

## Arquitectura y responsabilidades de código

- Separar dominio, aplicación, infraestructura, presentación y composición mediante
  paquetes/targets Swift y dependencias hacia dentro, tomando 02 como referencia.
  Composición ensambla e inyecta adaptadores.
- Dominio contiene valores/invariantes; aplicación contiene casos de uso, puertos,
  errores y eventos. No importan UI, Process, APIs del proveedor, SQLite, Keychain
  ni emulador de terminal. Los adaptadores implementan los puertos de aplicación.
- Vistas/modelos invocan casos de uso, sin ejecutar Git ni definir reglas de negocio.
  Si se adopta SwiftUI, usar Observation y `@MainActor` para el estado visual.
  Encapsular el terminal AppKit con identidad estable independiente del layout.
- Usar actores para estado compartido y valores `Sendable` entre aislamientos.
  Procesos, parseo, grafo y diff pesado trabajan fuera del actor principal.
  `async` no garantiza ejecución en segundo plano; no silenciar problemas con
  `@unchecked Sendable` sin justificar y verificar el contrato.
- Serializar mutaciones por `commonGitDir` canónico y mantener el permiso durante
  los `await`. Revalidar precondiciones antes de escribir; descartar resultados
  antiguos por generación y reconciliar cambios de terminal, IDE u otros clientes.
- Ejecutar el Git independiente ya disponible para la cuenta del usuario. Detectar
  PATH y rutas habituales o permitir ruta absoluta persistida en Ajustes → Git.
  No invocar /usr/bin/git, enlaces al launcher ni herramientas de Xcode/Apple
  durante detección/configuración; no aceptar licencias, instalar Git ni pedir
  privilegios de administrador. Validar versión y mantener catálogo/ajustes
  accesibles si falta un Git compatible. Restaurar la ruta antes de abrir repositorios.
- Git es la fuente de verdad de archivos, índice, objetos y referencias. No escribir
  directamente en `.git` para simular operaciones. Metadatos/cachés son separados;
  migraciones no modifican repositorios y las referencias de recuperación no son caché.

## Invariantes Git, confianza y seguridad

- Nunca incluir claves de autenticación, privadas ni públicas, en commits o
  artefactos versionados. Las deploy keys permanecen fuera del repositorio;
  comprobar el contenido del índice antes de cada publicación.
- Acciones Git de la UI: argumentos estructurados, directorio validado y sin
  concatenación de shell. Drenar stdout/stderr simultáneamente, acotar recursos
  y propagar cancelación. Parsear formatos NUL, preservar bytes/identidades de
  rutas y aplicar pathspec literal/separación `--`.
- Validar OID completos y tipo commit sin asumir 40 caracteres. Inspección endurecida
  con objetos originales, sin replace objects, diff externo, textconv, fsmonitor
  ni descargas implícitas de objetos.
- Confianza y autenticación son independientes. Antes de confiar, solo inspección
  restringida de objetos/historial: bloquear estado del working tree, terminal,
  red y mutaciones en los casos de uso. Clone autorizado con hooks deshabilitados
  y `--no-checkout`; confianza antes del checkout. Nunca `safe.directory=*`.
- Tokens en Keychain; metadatos solo con referencias a secretos. Heredar agentes/
  helpers sin copiar claves privadas. No exponer secretos en URLs, argumentos,
  configuración, temporales ordinarios, logs, PTY o historial. Validar destinos,
  redirecciones/paginación sin propagar Authorization a otro origen. Mantener TLS
  y verificación SSH; cambios de huella requieren decisión visible.
- Abrir el compare como capa sobre toda el área de contenido de la misma ventana de la app, manteniendo montada la vista anterior y sus sesiones; no activar el fullscreen de macOS ni crear otra ventana. Resaltado léxico de código automático por extensión, seleccionable manualmente, acotado y calculado fuera de MainActor; conservar los signos/fondos del diff y no ejecutar código. Resaltar los fragmentos modificados en ambos documentos, rojo para eliminaciones y verde para adiciones; líneas idénticas no reciben marcas de texto. Las líneas totalmente nuevas sin equivalente en A reciben fondo verde tenue en B, sin resaltado fuerte de fragmentos; conservar el signo +, sintaxis y mapas verdes de navegación. Preservar selección manual y calcular el detalle fuera de MainActor con trabajo acotado.
- Visor: realinear por contenido idéntico aunque cambie el número de línea, insertando huecos frente a adiciones/eliminaciones. No confiar en el emparejamiento posicional de hunks ni en líneas vacías como únicas anclas; conservar el orden de cada documento ante bloques cruzados. Trabajo acotado fuera de MainActor; si supera el límite, mostrar el diff original y un aviso explícito, sin una alineación falsa. Dos documentos completos en paralelo, líneas alineadas y scroll horizontal y vertical sincronizados; incluir mapas verticales detrás de los indicadores de scroll de ambas columnas (rojo: eliminado; verde: agregado), distancia dinámica desde el borde inferior visible al próximo cambio y navegación entre bloques; abrir solo tras elegir un archivo. A siempre es el commit inferior y B el superior en el historial, sin inversión manual ni dependencia del orden de clics.
- Comparación: exactamente dos commits distintos, árboles A→B, también merges o
  ramas sin relación de ancestro. Nunca merge-base/A...B. Un tercer clic sobre
  otro commit pide confirmación para limpiar el par: cancelar conserva ambos;
  aceptar selecciona solo el último commit pulsado. Filtrar o borrar la búsqueda
  del historial conserva selección, metadatos y dirección A→B. Buscar SHA completo
  o abreviado hexadecimal (mínimo cuatro caracteres), además de mensajes. Separar comparación de commits, índice frente a HEAD y worktree frente a índice.
- Conservar todas las rutas cambiadas. Binarios, LFS, submódulos, modos, enlaces y
  archivos grandes muestran resumen/límite; declarar completitud y paginación.
  No convertir un límite del visor en omisión de archivos.
- Pull solo fast-forward en la UI v1; divergencias mediante terminal. Push normal
  con destino explícito. No stash,
  merge, rebase, descarte o force push automáticos. Checkout bloqueado conserva
  trabajo; no borrar ramas activas/en uso. Stage/unstage por archivo completo;
  commit solo del índice previsto, con hooks/firma y soporte al primer commit.
- Edición del mensaje solo en HEAD de rama local: bloquear staging, conflictos/
  integraciones y estado no verificable. Crear recuperación antes de cambiar;
  conservar árbol, padres, autor e índice y volver a firmar según configuración.
- Publicar edición: fetch previo, destino único, HEAD anterior igual al tip remoto,
  plan de un solo uso (expira a los 60 s o ante cambios), confirmación específica
  y revalidación. Lease con ref/OID esperado explícitos; jamás `--force` o lease
  implícita. Ante fallo preservar recuperación y estado local; ante timeout
  consultar remoto antes de repetir. Sin reset/rollback automático.
- Terminal PTY por repositorio confiable y acción del usuario: directorio, resize,
  Unicode, Ctrl+C, pestañas/cierre y refresco tras cambios/foco. Contraer la vista
  no reinicia shell. Durante amend publicado pausar nueva entrada conservando salida/
  interrupción; esto no bloquea procesos externos. Revisar pegado multilínea y
  proteger acciones nativas ante secuencias terminal. No persistir salida ni inyectar secretos.
- No borrar locks ni reanudar mutaciones al reiniciar. Cancelación puede dejar
  efectos parciales: informar y reconciliar. Quitar registros/grupos/perfiles o
  desinstalar conserva repositorios. Diagnóstico redactado y revisable; sin
  telemetría externa en MVP.

Las confirmaciones de confianza y reescritura son comportamientos de la aplicación;
no implican pedir de nuevo permiso para cambios de código ya autorizados.

## Tareas y secuencia de desarrollo

Entregar historias verticales pequeñas con dominio/caso de uso, adaptador,
presentación y evidencia de aceptación. Seguir el plan de 07:

| Hito | Tareas y condición de avance |
|---|---|
| H0 — Viabilidad nativa | Prototipo descartable: ventana macOS, Git por pipes, PTY redimensionable, Keychain, entorno desde Finder, toolchain/CPU y build firmado de laboratorio. Registrar decisiones y límites antes de funcionalidades. |
| H1 — Repositorios y confianza | Registro, rutas, pestañas, organización propuesta, recientes, persistencia y confianza. Abrir/cerrar/quitar registros conserva archivos; sin confianza no se ejecutan scripts. |
| H2 — Historial y diff | Paginación, grafo, detalle, SHA, comparación A/B e inventario. Verificar merges, raíces, ramas distintas, renombres, binarios y límites visibles. |
| H3 — Conexiones y clonación | Token/SSH/heredado, capacidades Git/API, catálogo paginado y clone sin checkout. Sin secretos expuestos ni sobrescritura de destinos. |
| H4 — Trabajo y sincronización | Ramas, stage/unstage, commit, fetch/pull ff-only/push, coordinación y terminal con refresco. Verificar integridad y carreras en repositorios temporales. |
| H5 — Edición publicada | Plan, confirmación, recuperación, amend solo mensaje y lease exacta. Probar remoto concurrente y rama protegida conservando recuperación. |
| H6 — Beta y distribución | Accesibilidad, rendimiento, manual, QA y distribución adoptada tras H0. Verificar firma/notarización e instalación del mismo artefacto descargado cuando corresponda. |

H2 y parte de H3 admiten paralelismo con contratos definidos. H4 depende de confianza/
coordinación; H5 de conexiones, push, journal y recuperación. No inventar fechas
ni prometer Intel/universal antes de validarlo. No instalar/reemplazar Git
silenciosamente. Firma de distribución requiere recursos del propietario;
registrar como pendiente cualquier comprobación que no pueda ejecutarse.

## Pruebas, revisión y definición de terminado

- Mantener main construible cuando exista repositorio de desarrollo. Revisar capas,
  efectos sobre archivos/referencias, errores accionables, carga/vacío/error,
  teclado y VoiceOver. Una pantalla dibujada no completa una funcionalidad.
- Dominio/aplicación con puertos simulados; adaptadores Git con Git real en carpetas
  temporales, remoto bare y dos clones, aislando configuración, identidad, hooks y
  firma personales. Cloud con fixtures o cuenta dedicada de pruebas.
- Ejecutar pruebas pertinentes por cambio; integración real al modificar Git y
  matriz completa para release. Mantener trazabilidad RF/RNF→T-01…T-24 y verificar
  imports/strict concurrency con el toolchain adoptado.
- Medir RNF-04 con equipos/fixtures documentados: 100.000 commits, primera página
  ≤2 s con caché cálida/≤5 s fría y p95 de interacción ≤100 ms. Son objetivos,
  no rendimiento demostrado.
- Actualizar ADR, contratos/manual al cambiar seguridad, pull o edición publicada.
  Cada historia satisface sus RF, preserva trabajo ante fallos y aporta evidencia.
- Reportar comprobaciones ejecutadas, fallidas y pendientes. No ejecutado nunca
  significa aprobado; no afirmar conexiones, compatibilidad o notarización sin evidencia.
- Release: RF P0 trazados/aprobados, sin bloqueos de aceptación ni defectos de
  pérdida de datos, ejecución sin confianza, secretos expuestos o publicación
  incorrecta. Conservar versiones/licencias, resultados, límites, notas, hashes
  y recuperación ensayada según 08 y 09.


## DMG y automatización de distribución

Usar scripts/build-dmg.sh y docs/12-dmg-y-github-actions.md. Mantener separados el DMG local ad hoc, el firmado sin ticket y el notarizado. Release no degrada a unsigned ante secretos ausentes. Reutilizar los nombres de secretos de POSTMAN; no copiar ni versionar claves, certificados o valores. App y auxiliar universales, Developer ID/Hardened Runtime/timestamp al firmar; notarizar app antes del DMG, adjuntar tickets y validar el artefacto montado. No hacer push directo a main: integrar mediante PR. Generar DMG firmado/notarizado solo al fusionar un PR hacia main desde ramas del repositorio; no ejecutar empaquetado por otros pushes ni tags. Conservar ejecución manual y omitir firma para forks/Dependabot sin secretos; no usar pull_request_target con código externo. La publicación automática en GitHub Releases tras el merge a main fue autorizada: crear tag semántico incremental y adjuntar DMG y checksum solo tras firma/notarización/verificación correctas. La ejecución manual en main también publica; en otras ramas conserva solo artefactos. Un fallo de credenciales o del navegador no prueba configuración completada.

## Continuidad documental

Al terminar una historia, registrar comportamiento vigente, verificaciones y
pendientes en docs/13-resumen-del-proyecto-y-continuidad.md; conservar la evidencia
cronológica en 11 y la distribución en 12. Actualizar el índice y manual cuando
corresponda. docs/evidencia/mvp-validacion.json contiene snapshots históricos:
no reemplazar un resultado anterior por una comprobación que no se ejecutó.
Fechar los estados de PR/Actions/Releases y distinguir digest DMG de digest ZIP.
Nunca incluir valores de secretos, .env, certificados ni claves en documentos
o capturas. La publicación del instalador no acredita por sí sola aceptación H6.
