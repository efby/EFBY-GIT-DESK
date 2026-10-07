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
| RF-11 | Selección limitada a dos commits, inferior → superior | Árboles sin ancestro común, merges y raíz; nunca merge-base. La tercera selección conserva el par. |
| RF-12 | Documentos en paralelo, lista de rutas, índice/HEAD y worktree/índice | Rename y binario; resúmenes para LFS/submódulos/enlaces. Límite textual visible de 2 MB; inventario hasta 16 MB o error explícito, sin afirmar completitud de salida truncada. |
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

## Ajuste del visor de diferencias

El diff se muestra únicamente después de seleccionar explícitamente un archivo. Su cabecera identifica la ruta y permite cerrarlo; al cerrar, la lista vuelve a ocupar el panel. Cambiar commits o el contexto de comparación cierra el visor. Un refresco conserva la selección explícita, pero no vuelve a abrir un visor cerrado. Las consultas del inventario y del diff tienen cancelación independiente.

El contenedor del repositorio, historial y panel de archivos solicitan todo el espacio disponible, también sin commits seleccionados y en estados vacíos. La prueba de regresión con Git real pasó; la suite general ejecutó 37 pruebas, con 2 optativas omitidas (39 registradas en 11 suites). Después de ajustar el cambio de repositorio se repitió la prueba específica y pasó. La revisión visual de estos cambios en la aplicación queda pendiente.

## Comparación paralela y dirección fija

Por indicación del usuario, A corresponde al commit inferior del historial y B al superior, incluso si se seleccionan en el orden inverso. La posición topológica visible determina el sentido; no se usan fechas ni merge-base. Se retiró el intercambio manual. Un solo commit sigue comparándose contra su padre elegido (o árbol vacío si es raíz).

El visor lee ambos documentos completos desde blobs Git, sin filtros, textconv ni descargas implícitas. Muestra números de línea, signos y colores de cambio; alinea los bloques de adición/eliminación con huecos. Las dos columnas tienen scroll vertical y horizontal sincronizados. Los renombres conservan la ruta original y la nueva; se identifica la ausencia de salto de línea final. Staging y cambios locales mantienen HEAD → índice e índice → área de trabajo.

Se mantienen resúmenes para binarios, submódulos, conflictos y contenido no UTF-8. Límite: 2 MB por documento y 50.000 líneas entre ambos; ante un límite o alineación incompleta se informa y se conserva el resumen de Git. Suite general: 42 pruebas ejecutadas y aprobadas, 2 optativas omitidas (44 registradas, 12 suites). Las nuevas pruebas cubren documentos completos con hunks separados, bloques de distinta longitud, raíz, renombre con salto de línea en la ruta, binarios, índice/worktree, selección en ambos órdenes, límites y sincronización nativa de scroll. La imagen de las columnas AppKit se revisó fuera de pantalla usando un fixture sintético; el recorrido completo de la ventana con repositorios reales sigue pendiente.

El refresco de un archivo ya abierto conserva el visor nativo mientras se consulta el contenido, para no reiniciar el scroll ni la selección cada cuatro segundos. Los controles de fin de línea se representan sin añadir filas visuales; se verificaron CRLF y cambios de salto final.

## Resaltado de código y evolución del compare

La primera versión del compare ampliado utilizaba una ventana independiente con fullscreen de macOS. Este comportamiento se reemplazó por una capa dentro de la misma ventana, según la aclaración del usuario. Historial, paneles y terminal permanecen montados debajo; volver al repositorio conserva commits, repositorio y distribución.

Detección automática por extensión y selector manual: Python, JavaScript/JSX, TypeScript/TSX, Swift, Java, Kotlin, C/C++, C#, Go, Rust, Ruby, Shell, SQL, JSON, YAML/TOML, HTML/XML, CSS y Markdown. El lexer básico resalta palabras clave, cadenas, comentarios, números, llamadas, tipos y algunas etiquetas/decoradores; conserva estado de cadenas/comentarios multilínea entre filas de diff. No interpreta código ni analiza gramáticas completas: regex JS, interpolación de templates, anidación de comentarios y lenguajes embebidos pueden tener resaltado aproximado. Archivos desconocidos usan texto plano. El límite adicional de resaltado es 60.000 tokens por documento; el contenido permanece visible después de alcanzarlo. El cálculo se realiza fuera del actor principal.

Las pruebas verifican detección, Unicode y rangos UTF-16, cadenas/comentarios multilínea con huecos, texto plano, preservación de selección/scroll al recolorear y ventana independiente con cierre sin perder contexto. Se revisaron capturas fuera de pantalla del visor completo y de las columnas coloreadas con fixtures sintéticos; la transición a un Space dejó de formar parte del flujo tras reemplazar esa implementación. La suite general aprobó 47 pruebas, con 2 optativas omitidas (49 registradas en 13 suites).

## Compare dentro de la app, scroll y mapa de modificaciones

La comparación cubre toda el área de contenido de la misma ventana. No crea NSWindow ni solicita fullscreen de macOS. La vista anterior sigue montada y no recibe clics ni entrada de teclado mientras está cubierta; Volver al repositorio o Esc cierran la capa.

Ambos ejes de desplazamiento se sincronizan bidireccionalmente. El ancho de ambos documentos se calcula usando la línea más larga de cualquiera de las versiones, para conservar el mismo recorrido horizontal aunque sus longitudes sean distintas. El recoloreado conserva scroll y selección.

Modificaciones agrupa filas cambiadas consecutivas y muestra sus rangos Base/Destino, un mapa acotado a 240 segmentos y distancias en líneas sin cambios. El primer bloque indica su distancia desde el inicio; los siguientes, desde el final del anterior. Tarjetas, mapa y botones anterior/siguiente navegan a la primera fila del bloque. Añadidos, eliminados y cambios del salto final se incluyen; los resúmenes no textuales conservan su diagnóstico.

La suite general aprobó 51 pruebas, con 2 optativas omitidas (53 registradas, 14 suites, 5,323 s). Incluye sincronización de ambos ejes desde ambas columnas, ancho común con versiones de distinta longitud, saltos repetidos, agrupación/distancias, mapa de 50.000 filas y conservación del contexto y la vista nativa en la misma ventana. Se revisó una captura de la capa completa con un fixture sintético; el flujo interactivo con repositorios personales no se automatizó.

## Mapas verticales y distancia al siguiente cambio

La sección horizontal con tarjetas se reemplazó por mapas en las pistas verticales de ambas columnas, detrás de sus indicadores de posición. Los dos mapas muestran las mismas ubicaciones, con rojo para contenido eliminado y verde para agregado; una sustitución muestra ambos colores. Los huecos de alineación del documento opuesto tienen fondo neutro. Las pistas permanecen visibles y conservan el arrastre y comportamiento nativo del scroll.

La cabecera informa dinámicamente las líneas que faltan desde la última fila visible hasta la primera fila del siguiente bloque al bajar. Si hay modificaciones en pantalla, lo indica; después del último bloque muestra que no quedan más cambios hacia abajo. La distancia considera filas alineadas y el tamaño actual del área visible. Anterior/siguiente navega según la posición actual, sin depender del último salto pulsado.

Pruebas nuevas cubren marcas de adición, eliminación y sustitución, cálculo de distancia, cambios visibles, fin de cambios, actualización al mover cualquiera de las dos columnas y proporción del indicador al pasar a un documento corto. Se revisó una captura sintética del visor completo con ambas pistas verticales.

La suite general aprobó 54 pruebas, con 2 optativas omitidas (56 registradas, 14 suites, 5,252 s). El bundle se reconstruye en release arm64 con firma ad hoc de desarrollo.

## Cierre visible del visor

El botón «Cerrar comparación», con una X y fondo destacado, está al inicio de la cabecera del visor. Conserva su ancho aunque la ruta sea larga; la ruta se trunca en el medio. «Esc para volver» recuerda el atajo. El botón y Esc ejecutan `closeDiff`, que cierra únicamente la capa de comparación y conserva la ventana, el repositorio y las sesiones. Está disponible también durante la carga y en los estados de error o resumen.

Validación: 6 pruebas dirigidas en 2 suites aprobaron (0,884 s), incluidas conservación de ventana/contexto y persistencia del visor cerrado tras refresh. Se revisó una captura sintética del visor con el nuevo botón.

## Pestañas del área de trabajo

Se retiró la columna lateral que contenía Área de trabajo, Ramas locales y Ramas remotas. Pendientes, Preparados e Historial son pestañas nativas de selección única sobre el contenido, con contadores de cambios. Ramas locales y remotas se consultan desde un menú compacto, con las acciones existentes de checkout/borrado integrado y copia del nombre.

Historial y detalle conservan su identidad dentro de una región de dos columnas que aprovecha el ancho liberado. Las pestañas locales requieren confianza, siguen usando sus contextos Git respectivos y cierran el visor del contexto anterior. El cambio no modifica archivos, ramas ni sesiones de terminal por sí mismo. Se agrega una prueba con Git real para distinguir inventario del índice y del área de trabajo, verificar el bloqueo sin confianza y conservar el repositorio al volver a Historial.

Validación: 55 pruebas aprobadas, 2 optativas omitidas (57 registradas, 14 suites, 5,528 s). Se revisó una captura sintética de las pestañas, el menú Ramas y las dos columnas ampliadas.

## Resaltado de cambios dentro de cada línea

Los fragmentos que cambian tienen fondo más intenso que el contexto de la fila: rojo para lo eliminado en Base y verde para lo agregado en Destino. Se distinguen cambios separados dentro de una misma línea, sin marcar los fragmentos comunes entre ellos. Líneas idénticas no reciben marcas de texto; un cambio exclusivo del salto final conserva el indicador Git sin resaltar caracteres iguales. Los huecos del lado opuesto siguen neutros.

El cálculo usa caracteres Unicode completos y entrega rangos UTF-16 para AppKit, sin dividir emojis o caracteres compuestos. Se ejecuta junto a la alineación fuera de MainActor y se reutiliza al recolorear. No se cambian los rangos seleccionados por el usuario. Se acota el trabajo con un presupuesto de 2.000.000 productos de longitudes por archivo, un máximo de 250.000 por pareja y 4.096 caracteres por tramo; sobre ese límite se marca el tramo entre prefijo/sufijo comunes y se informa el menor detalle.

Validación: 61 pruebas aprobadas, 2 optativas omitidas (63 registradas, 15 suites, 5,264 s). Incluye reemplazos separados, adiciones/eliminaciones unilaterales, igualdad, cambio exclusivo del salto final, espacios, rangos Unicode, límite de complejidad y conservación de fondos/selección al actualizar sintaxis. Se revisó una captura sintética del visor con una inserción marcada en verde.

## EFBY Git Desk: carpetas superiores y árbol de proyectos

Nombre visible actualizado en ventana, sidebar, preferencias, errores y metadatos del bundle. La distribución local usa EFBY Git Desk.app; ejecutables, módulos, ID del bundle, ubicación del catálogo y servicio Keychain no cambian.

Se incorpora un puerto de descubrimiento de carpetas y un adaptador de recorrido fuera de MainActor. Busca a cualquier profundidad, incluye ocultos/paquetes y .git archivo/directorio, continúa dentro de repositorios anidados, ignora .git interno y evita ciclos/duplicados. Los enlaces a carpetas externas se omiten y se informan, junto a problemas de lectura. Los candidatos se validan con la inspección Git existente; no se ejecuta checkout ni se concede confianza nueva. Los bare siguen sin soporte y se informan sin impedir abrir los demás. La cancelación conserva cualquier registro ya realizado, sin cambiar archivos del proyecto.

Las raíces del árbol se guardan en preferencias del catálogo y se normalizan las rutas para conservar la misma identidad que Git. El sidebar muestra carpetas expandibles y proyectos, junto a accesos de favoritos y grupos. Su árbol se construye en segundo plano. La búsqueda usa todos los repositorios registrados por nombre, ruta o grupo, independientemente de carpetas contraídas. Seleccionar una carpeta agrupadora no activa una ruta sin Git.

Validación: 67 pruebas aprobadas, 2 optativas omitidas (69 registradas, 16 suites, 5,879 s). Nuevas pruebas cubren profundidad, ocultos, paquetes, anidados, .git archivo, worktree real, ciclos/alias, enlaces externos, cancelación, candidatos inválidos/bare, persistencia, deduplicación, conservación de confianza/favoritos/grupos y estructura jerárquica. Se revisaron capturas sintéticas del sidebar y búsqueda de un proyecto con el árbol contraído. La interacción con carpetas personales no se automatizó.
