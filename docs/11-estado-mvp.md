# EFBY Git Desk — registro de implementación y validación

Registro iniciado el 6 de octubre de 2026, actualizado el 8 de octubre. Las secciones conservan resultados y decisiones de cada etapa; las entradas posteriores pueden sustituir decisiones previas. Para el comportamiento vigente consultar [13 — Resumen y continuidad](13-resumen-del-proyecto-y-continuidad.md). Releases publicadas no equivalen a aceptación completa H6.

## Decisiones adoptadas en la implementación

- Swift 6 con concurrencia estricta, SwiftUI/Observation y AppKit para texto y terminal. Targets independientes de dominio, aplicación, infraestructura, presentación, composición y helper de credenciales.
- Git CLI por argumentos y pipes; drenaje simultáneo, salida acotada, timeout, cancelación y terminación de procesos propios. Las lecturas untrusted no ejecutan herramientas de working tree ni lazy fetch.
- Git 2.40 o posterior, comprobado al iniciar. Entorno de desarrollo verificado: Swift 6.4, Git 2.51, macOS 26.6.2, arm64. El mínimo de compilación macOS 14 no equivale a ejecución verificada en ese sistema.
- SQLite del sistema para catálogo, preferencias y journal. Migración v1 y rechazo de esquemas futuros; no se reanudan escrituras al reiniciar. La confianza incluye directorio canónico e identidad de dispositivo/inodo; sustituir `.git` revoca la confianza recordada.
- Keychain para tokens y referencias de operación efímeras. El helper recibe una referencia, no el token en argumentos ni entorno. Validación estricta del origen de la solicitud de credenciales, de URLs REST y de enlaces de paginación; redirecciones HTTP deshabilitadas.
- PTY propio con entrada/salida, resize, UTF-8, Ctrl+C y secuencias VT básicas. No se incorporó SwiftTerm ni otra dependencia externa. Las secuencias OSC no realizan acciones nativas; se revisa el pegado multilínea. No es todavía un emulador xterm completo.
- Paquete `.app` para desarrollo, con helper y firma ad hoc verificada. Sin App Sandbox. Esta fue la primera etapa; las verificaciones posteriores de Developer ID, notarización y universal se registran más abajo y en 12. El runtime Intel/macOS 14 sigue pendiente.

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

**Resultado de la primera etapa:** 38 pruebas aprobadas en 10 suites, sin omisiones, en una ejecución conjunta con benchmark y Keychain habilitados. Tiempo de pruebas: 5,551 s (excluye compilación). La regresión posterior al aislamiento de clone aprobó los 36 casos esenciales; los dos optativos conservaron su evidencia de ejecución separada.

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


### Paneles persistentes y cierre rojo

El visor muestra **Cerrar** sobre fondo rojo explícito, conservando Esc y el repositorio montado. El workspace utiliza dos separadores NSSplitView: carpetas 340 puntos inicialmente (210–340) y comparación A→B 340 inicialmente (mínimo 340), con historial mínimo de 370. Los anchos se aplican realmente al layout y se guardan en `workspace.sidebarWidth` y `workspace.detailWidth`; el antiguo ancho ideal `panel.detail` deja de determinar la distribución inicial. Preferencias recupera esos valores al restablecer distribución. El resize de ventana limita el ancho temporalmente sin sobrescribir lo elegido; las vistas nativas se conservan al cambiar medidas.

Validación: 73 pruebas registradas en 17 suites, 71 aprobadas y 2 optativas omitidas, 5,931 segundos. Cuatro pruebas nuevas verifican anchos nativos, restauración con SQLite en otra instancia del modelo, límites/valores inválidos y hosting real de WorkspaceView sin recrear paneles. Capturas sintéticas revisadas del workspace con medidas personalizadas y del visor con botón rojo. No se operaron repositorios personales ni se ensayó arrastre interactivo en la ventana del usuario.


### Líneas nuevas sin resaltado

Las filas con documento anterior ausente y documento nuevo presente no tienen fondo tenue de fila ni resaltado fuerte de fragmentos. Se conservan el signo +, números, sintaxis y mapas verdes para navegación. Una línea vacía existente que recibe texto sigue considerándose modificada. Eliminaciones y modificaciones sobre líneas existentes conservan el comportamiento anterior. Pruebas de rangos y texto nativo verifican la excepción y preservación de selección. Regresión completa: 71 aprobadas, 2 optativas omitidas, 73 registradas en 17 suites, 6,012 segundos.


### Navegación de archivos dentro del visor

La capa de comparación incorpora un PersistentSplitView con FileDiffView a la izquierda y el DiffPane existente a la derecha. Reutiliza inventario, selección y encabezados de contexto; mantiene el panel nativo mientras cambia el archivo, reiniciando solo el estado del documento elegido. Comparte `detailWidth` persistente con el workspace, mínimo derecho 340 y reserva izquierda de 640 cuando haya espacio. Loading/error/resúmenes conservan el navegador. Cerrar/Esc mantiene el workspace subyacente y su selección.

Validación: 74 pruebas registradas en 17 suites, 72 aprobadas y 2 optativas omitidas, 5,872 segundos. Nueva integración con Git real temporal compara dos commits y cambia entre README.md y script.py; verifica documentos nuevos, par/contexto intactos, panel derecho en la misma ventana y misma instancia, workspace conservado y cierre. Captura sintética del visor con el navegador derecho revisada. No se operó la ventana ni repositorios personales del usuario.


### Fondo verde en líneas nuevas

Ajuste posterior: las líneas totalmente nuevas conservan la ausencia de marcas fuertes por fragmentos, pero ahora reciben fondo verde tenue en B (alpha 0,13), incluidos prefijo/número/signo y salto de línea. El hueco de A queda neutro. Sintaxis, selección, modificaciones existentes y mapas se conservan. Este comportamiento reemplaza la decisión anterior de fondo neutro para adiciones completas.

Validación del ajuste: 74 pruebas registradas en 17 suites, 72 aprobadas y 2 optativas omitidas, 6,027 segundos. Prueba nativa verifica fondo verde tenue en texto y prefijo de la línea nueva, sin perder las marcas fuertes de las modificaciones existentes. Captura sintética revisada del navegador A→B con archivo totalmente nuevo.


### DMG universal y preparación de CI/release

Se agregó scripts/build-dmg.sh basado en el flujo de EFBY_POSTMAN y scripts/select-xcode.sh. Build-app permite EFBY_UNIVERSAL=1 y APP_VERSION; producto y auxiliar verificados con lipo como arm64/x86_64. El DMG local incluye la app, enlace Applications e instrucciones; hdiutil verify y montaje readonly verificaron imagen, firma ad hoc de la app contenida y enlace de instalación. Se añade checksum comprobado. Firma Developer ID y notarización son modos explícitos separados. Los flujos de CI y release generan universal; release exige secretos, valida Accepted/tickets/Gatekeeper y prepara borradores por tags. No se creó un tag ni se publicó una versión.

Validación: 74 pruebas registradas en 17 suites, 72 aprobadas y 2 optativas omitidas, 7,018 segundos; scripts revisados con bash -n y YAML con parser Ruby. Un fixture efímero verificó importación .p12 por pipe con contraseña por entorno y registro notarytool con contraseña por stdin, sin secretos en argumentos; fue eliminado. Certificado Developer ID real detectado; perfil notary local devolvió HTTP 401, por lo que no se intentó envío ni se afirma notarización. Navegador integrado bloqueado al no poder verificar política; no se modificaron secretos ni se ensayó Actions remoto. Intel y macOS 14 solo cubiertos en compilación/deployment target, sin runtime validado. Ver docs/12-dmg-y-github-actions.md.


### Alineación de líneas desplazadas

La alineación anterior emparejaba por posición las eliminaciones/adiciones de cada hunk, permitiendo que contexto vacío elegido por Git separara dos condiciones iguales. DiffAlignment conserva la validación del patch/documentos y luego realinea completos con DiffLineAlignment: anclas de contenido único no vacío y secuencia creciente; entre ellas, matching exacto Myers acotado para líneas repetidas. Nunca cruza el orden de los documentos. Solo los intervalos sin correspondencias exactas se emparejan como modificaciones; adiciones/eliminaciones incluyen huecos. Líneas idénticas desplazadas no reciben marcas de cambio. Se conservan CRLF y números originales.

Límites: 50.000 líneas combinadas, presupuesto de 2.000.000 operaciones de recorrido/matching y 250.000 entradas de trazas. Exceso produce aviso y diff original de Git, sin afirmar una alineación completa. Continúa ejecutándose en Task.detached mediante el pipeline existente. No pretende equivalencia semántica de código ni ignora cambios de indentación.

Validación: 80 pruebas registradas en 18 suites, 78 aprobadas y 2 optativas omitidas, 6,193 segundos. Seis pruebas nuevas: ejemplo de condiciones DE/QA/PR con tres líneas nuevas en ambos sentidos, repetición de 3.000 líneas con desplazamiento, bloques cruzados, límite de complejidad, 1.600 pares de secuencias pequeñas y Git real con líneas vacías en contexto. Preservación de texto/números completa comprobada. Captura sintética revisada: if alineados sin marcas y líneas bucket nuevas con fondo verde; documentos personales no operados. App/DMG universal regenerados, notarización pendiente como antes.
## Corrección del bloqueo de pruebas en Actions

El bloqueo después de `Build complete!` se reprodujo localmente con salida
redirigida. La muestra del ejecutor mostró `ProcessJob.run()` esperando a sus
lectores de pipes desde varios hilos del ejecutor cooperativo de Swift.
`ProcessRunner` ahora envía ese trabajo bloqueante a una cola concurrente de
Dispatch y devuelve el resultado mediante una continuación, manteniendo timeout,
cancelación y drenaje acotado. Una regresión ejecuta 24 procesos concurrentes con
128 KB de entrada/salida y stderr independiente.

Validación: 81 pruebas registradas, 79 aprobadas y dos optativas omitidas, en
18 suites; 6,450 segundos localmente y 10,640 segundos en GitHub Actions
([Release DMG #4](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37561896851)).
El paso completo de CI, incluida compilación, tardó 51 segundos y avanzó a la
importación del certificado. Ese intento falló luego por RC2 en OpenSSL 3,
un problema separado de la ejecución de pruebas.

La prueba del overlay dejó de comparar el número global de ventanas de NSApp:
comprueba la identidad de su ventana y contenido, evitando interferencias de
otras pruebas de UI paralelas. La suite completa posterior pasó localmente en
6,400 segundos y en Release DMG #6 en 14,449 segundos (81 registradas, 79 aprobadas
y dos optativas omitidas). El flujo remoto completó también firma y notarización
y subió el DMG universal. Ver evidencias y límites en docs/12-dmg-y-github-actions.md.
El supervisor de CI limita compilación/pruebas a 300 segundos, recoge diagnóstico
a los 120 segundos y termina su grupo de procesos ante timeout.

## Panel de comparación con tarjetas y árbol

Se muestran tarjetas del commit superior B y del inferior A, con mensaje, SHA
copiable, autor y fecha local; la dirección de cálculo sigue siendo A→B según
el orden del historial. El autor procede del commit: Git no guarda quién hizo
push. Los archivos se agrupan en carpetas desplegables con conteo, expandir todo,
selección y símbolos/color por tipo de cambio. No se agregaron controles de
ordenamiento ni selector Path/File. El árbol conserva bytes de rutas, renombres
y sustituciones archivo/directorio sin perder entradas.

Commit admite una URL opcional de avatar y la tarjeta la representa cuando esté
disponible. El adaptador local no obtiene imágenes de perfil; se muestran
iniciales, sin consultar servicios externos usando correos. La obtención de
avatares del proveedor sigue pendiente de una integración de perfiles.

Validación: suite completa con 83 pruebas registradas en 19 suites (81 aprobadas,
dos optativas omitidas), 6,439 segundos; dos pruebas del panel aprobadas también
tras ajustar la captura nativa de SwiftUI. Vista oscura de 560×750 revisada con
datos sintéticos. La versión con esta interfaz y la corrección de Keychain terminó correctamente
en Release DMG #8 (commit 7ed8af5), con firma y notarización verificadas en CI.

## Visor sin cabeceras duplicadas

Se retiraron las cabeceras Documento 1/Documento 2, SHA y rutas sobre los dos
documentos porque las tarjetas del panel derecho identifican la comparación.
Se conserva la barra Modificaciones, distancia en líneas al siguiente cambio,
navegación, marcas rojo/verde y scroll sincronizado. El aviso de ausencia de
salto de línea final se conserva en una fila compacta solo cuando corresponde.

Validación del cambio: app de desarrollo recompilada; prueba
overlayKeepsRepositoryMountedInSameWindow aprobada (0,606 segundos), captura
nativa del visor revisada y git diff --check sin errores. No se regeneró el DMG
para este ajuste: lo hará el flujo automático al fusionar el PR.

### Árbol de comparación compacto

Padding vertical de las filas reducido de 7 a 3 puntos, separación interna
de carpetas de 2 a 0 y entre filas raíz de 4 a 1. Menos margen alrededor de
Expandir todo y del texto de ayuda; se conserva tamaño de texto, selección,
indentación y navegación. Dos pruebas existentes del panel aprobadas, captura
nativa revisada y app de desarrollo recompilada.


## Historial: búsqueda y selección — 7 de octubre de 2026

- Buscar por SHA completo o prefijo hexadecimal de cuatro o más caracteres,
  incluyendo SHA-256 y mayúsculas. Las otras consultas filtran mensajes.
  Resolver solo commits alcanzables desde las referencias del historial;
  rechazar blobs/árboles y no interpretar expresiones u opciones Git.
- Cambiar o borrar filtros conserva selección, tarjetas, inventario y dirección
  A→B. Los seleccionados fuera de la página/filtro quedan visibles como selección
  conservada sin alterar offset ni contador de paginación.
- Elegir commits desde filtros distintos consulta su orden topológico fuera de
  MainActor, con límite de salida y aviso ante fallo. Sin ordenar, no compara.
- Tercer clic sobre otro commit abre confirmación. Cancelar conserva el par;
  aceptar selecciona solo el último pulsado para iniciar otra comparación.
- Regresión Git detectada durante implementación: `log --no-walk --skip=0`
  vuelve a recorrer ancestros. La consulta SHA no utiliza `--skip`; los candidatos
  están acotados a 64 y caben en una página. Pruebas verifican también SHA de HEAD.
- Evidencia: `scripts/test.sh`, 88 tests registrados en 20 suites, 86 aprobados,
  2 opcionales omitidos (Keychain y benchmark), 6,947 s; compilación debug incluida.
  Suite completa secuencial: 25,850 s. Una ejecución paralela previa detectó dos
  aserciones de layout transitorias y el defecto de búsqueda de HEAD ya corregido;
  la última ejecución habitual pasó completa. No se generó un DMG de esta rama.
- Nuevos casos: SHA-1/SHA-256, prefijos/completo/case, mensajes, objetos no commit,
  objetos inalcanzables, paginación, selección anterior a los primeros 100 commits,
  búsqueda vacía/sin resultados, dirección con filtros separados en ambos órdenes,
  confirmación aceptada y cancelada. Mantener pendientes de aceptación H6.


## Git en cuentas restringidas — 7 de octubre de 2026

El reporte sobre v0.1.4 mostró «El ejecutable encontrado no es Git» en un equipo
con Xcode sin licencia aceptada. La composición solo elegía el primer archivo
executable entre tres rutas, con `/usr/bin/git` como fallback. Se sustituye por
búsqueda y validación asíncronas de instalaciones del usuario; los launchers/rutas
de herramientas Apple y sus enlaces se excluyen antes de ejecutar. No se intenta
aceptar licencias ni se solicitan permisos de administrador.

Ajustes → Git ofrece archivo, ruta absoluta y detección automática. Se persiste
solo una configuración validada; la ruta guardada se restaura antes de reabrir
repositorios. Si la configuración falla, la aplicación y el catálogo siguen
accesibles. Git mínimo 2.40; no se instala ni actualiza Git. No se ejecutan perfiles
de shell ni se modifica el contenido de los repositorios para resolver la herramienta.

Verificado: `scripts/test.sh`, 94 pruebas registradas en 21 suites, 92 aprobadas y
2 opcionales omitidas, 7,457 s; build debug incluido. Se cubren PATH relativo/vacío,
duplicados, symlinks a Apple, fallback desde un candidato inválido, ruta con espacios,
versión antigua, configuración anterior preservada, restauración antes de abrir
repositorio y catálogo accesible ante Git no disponible. Las fixtures no equivalen
a una prueba en la cuenta restringida del equipo del reporte. Este cambio se entrega
por PR; el DMG publicado v0.1.4 todavía tiene la detección anterior.


### Fallback Miniforge — 7 de octubre de 2026

La detección incluye `~/miniforge3/bin/git`, usando el directorio personal de la
cuenta actual y sin depender de que Finder reciba el PATH de Terminal. Una ruta
configurada explícitamente y el Git válido de PATH conservan prioridad. Si no
se detecta otra instalación independiente, se valida el Git existente de Miniforge;
no se modifica `.zshrc`, instala software ni acepta la licencia de Xcode.
La prueba cubre PATH limitado a rutas del sistema y prioridad del Git elegido.
Validación: suite completa, 95 pruebas registradas, 93 aprobadas y 2 opcionales
omitidas en 25,211 s, con compilación debug correcta. Pendiente validar el DMG
en el equipo con Miniforge del reporte.


## Logo lateral y exploración de archivos — 7 de octubre de 2026

La cabecera lateral sustituye «EF» por el icono del bundle de EFBY Git Desk,
con el logotipo y la etiqueta #GitDesk. La casilla «Todos los archivos» amplía
el árbol de comparación con archivos sin cambios del commit de destino o del
índice. El inventario de cambios conserva eliminaciones y renombres, y sigue
siendo la vista inicial. Un archivo igual en ambos lados muestra el código
completo sin marcas. La lectura usa objetos Git originales; en contextos de
índice/working tree se exige confianza. Un inventario truncado se rechaza.

Validación: suite completa con 96 pruebas registradas, 94 aprobadas y 2
opcionales omitidas, 7,498 s; compilación debug correcta. La nueva prueba
integra Git real, un archivo Python sin cambios, uno nuevo y uno eliminado,
comprueba el contenido de ambos documentos y el regreso al filtro de cambios.
La nueva presentación aún requiere revisión visual del DMG empaquetado.

## Persistencia de carpetas y navegación de código — 8 de octubre de 2026

Los PR #14–#21, integrados hasta `a5dbee4` (`v0.1.12` en el repositorio local),
añadieron la memoria de carpetas abiertas/cerradas en los árboles de proyectos y
comparación, el control reversible **Expandir todo / Colapsar todo**, el índice
de declaraciones de Python, JavaScript, TypeScript y Dart, enlaces dentro del
documento derecho, navegación entre archivos y **Volver** con restauración de
posición. La primera versión colocaba funciones bajo cada archivo; la versión
vigente las enlaza en el código y deja el árbol como lista de archivos. Los enlaces
no dependen de la casilla **Todos los archivos**. Se priorizan imports y tipos
de receptor; las coincidencias ambiguas no se convierten en enlace.

Validación local del SHA `a5dbee4`: compilación limpia correcta (20,21 s),
Swift Testing con **100 pruebas registradas, 98 aprobadas y 2 opcionales omitidas**
en 22 suites (8,003 s). Los límites, casos cubiertos y pendientes figuran en
[13 — Resumen y continuidad](13-resumen-del-proyecto-y-continuidad.md). Esto no
verifica notarización ni ejecución del DMG descargado de v0.1.12.

## Auditoría y reparación de enlaces de código — 8 de octubre de 2026

La auditoría posterior a los PR #14–#21 encontró cuatro problemas: caché de
declaraciones compartida entre repositorios y obsoleta ante cambios locales,
falsas declaraciones en comentarios, selección arbitraria entre destinos
duplicados y enlaces activables solo con el mouse. La corrección separa la caché
por repositorio, vuelve a resolver en índice/working tree, verifica que la
declaración no sea un comentario, omite destinos ambiguos y publica enlaces
estándar de AppKit con activación por Retorno. La aceptación manual con VoiceOver
permanece pendiente.

Pruebas locales después del cambio: **102 registradas, 100 aprobadas y 2
opcionales omitidas** en 22 suites; compilación del bundle de
desarrollo y verificación `codesign` correctas. Se añadieron casos para
comentarios, sobrecargas, cambio de línea en un archivo de destino Git y
activación por teclado. No equivale a una validación del DMG distribuido.

## Acciones globales de repositorios — 9 de octubre de 2026

Se retiró «BITBUCKET CLOUD» del subtítulo del logo. El lateral agrupa y alinea
**Agregar carpeta**, **Fetch de todos** y **Confiar en todos**. La confianza global
requiere una hoja con rutas y advertencia antes de actuar. El servicio revalida
la identidad de cada proyecto, omite los incompatibles y muestra resultados por
repositorio. Fetch global usa los remotos de cada repositorio confiable, continúa
ante errores individuales e informa omisiones y cancelaciones. No ejecuta pull,
checkout ni concede confianza de manera implícita al pulsar fetch.
El panel de progreso se presenta desde el inicio y añade un resultado al acabar
cada proyecto/remoto, mostrando también la operación en curso y una opción de
cancelación. La prueba con remotos locales verifica el orden de eventos inicio/fin.

Las pruebas de integración usan repositorios y remotos locales temporales para
verificar varios remotos, proyectos sin confianza o sin remoto, un remoto no
admitido y una identidad reemplazada. El bundle de desarrollo se abrió en macOS:
se comprobaron el encabezado y los controles. La primera inspección descubrió
que la hoja mostraba cero proyectos pese al contador; se corrigió vinculando la
lista al identificador de la hoja. La segunda inspección mostró 183 pendientes y
sus rutas, sin confirmar la confianza. Se verificó el mismo ancho y alineación
de los tres botones en la aplicación abierta. El usuario probó fetch global en
su instalación y la barra de estado informó 3 completados, 183 omitidos y 0
errores; no se inspeccionó el contenido de los remotos. No se ejecutó confianza
global sobre repositorios personales. Quedan pendientes la aceptación manual de
ese flujo y la verificación del DMG distribuido.

Tras añadir el progreso en vivo, la aplicación recompilada se abrió de nuevo y
se pulsó **Fetch de todos**. La hoja apareció durante el proceso: mostraba
2 completados, 133 omitidos y el remoto `origin` de `infraestructura` en curso,
con botón para cancelar. Al terminar mostró 3 completados, 183 omitidos y 0
errores, lista individual desplazable y botón **Cerrar**. Esta comprobación no
equivale a inspeccionar el contenido de los remotos ni al DMG distribuido.

Validación local de esta rama: **104 pruebas registradas en 23 suites, 102
aprobadas y 2 optativas omitidas**; `scripts/build-app.sh` compiló el bundle y
verificó su firma ad hoc. Se revisaron enlaces Markdown y `git diff --check`.

## Progreso de confianza global — 9 de octubre de 2026

Después de la confirmación explícita, la misma hoja de **Confiar en todos**
cambia al panel de progreso. Indica el repositorio que está verificando, añade
cada resultado al terminar y ofrece cancelación; el resumen queda visible hasta
cerrarlo. Así no depende de cerrar una hoja para presentar otra. La prueba de
integración verifica eventos de inicio y fin por cada repositorio temporal y
revalidación de identidad. Se ejecutaron las 104 pruebas de 23 suites con éxito
(102 aprobadas y 2 optativas omitidas). No se confirmó confianza sobre los
repositorios personales del equipo.

## Cabeceras compactas — 9 de octubre de 2026

Se retiró el logotipo y nombre duplicados del lateral; ahora su cabecera dice
**Explorador**, mientras EFBY Git Desk permanece en la barra superior. La
cabecera central reemplaza el nombre repetido del repositorio por las dos
carpetas superiores de su ubicación, junto a la rama; la pestaña conserva el
nombre del repositorio. Se mantuvieron **Pendientes**, **Preparados** e
**Historial**. La ruta completa se ofrece como ayuda y etiqueta de accesibilidad.
En la ventana real se comprobó el ejemplo **PAY / CATALAGO** con `master`, el
lateral más compacto y las tres pestañas. La suite local completó 104 pruebas
registradas en 23 suites; el bundle recompiló con firma ad hoc.
