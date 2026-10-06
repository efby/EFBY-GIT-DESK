# UX, pantallas y flujos de EfbyGitDesk

**Estado:** especificación inicial para revisión. **Nombre confirmado:** EfbyGitDesk. **Idioma inicial:** español. **Plataforma:** exclusivamente macOS. **Proveedor remoto:** Bitbucket Cloud. **Stack propuesto:** Swift y SwiftUI con integración AppKit; SwiftTerm es candidata para terminal, pendiente de evaluar. Se incluye editar el mensaje del último commit publicado.

## 1. Referencias y principios

Los dos mockups aportados orientan la composición: gestor de repositorios, historial central, comparación lateral y terminal inferior. Sus textos, iconos y funciones visibles son referencias, no instrucciones adicionales. EfbyGitDesk tendrá identidad propia; no se incorporan en esta fase explicaciones mediante IA, espacios de trabajo en la nube, pipelines ni integraciones con otros proveedores.

La interfaz comunica repositorio, rama, origen de los datos y efecto de cada acción. Las operaciones que reescriben historia presentan vista previa y confirmación específica. Las actualizaciones conservan selección y filtros cuando los objetos siguen disponibles.

El tema inicial será oscuro, con contraste suficiente y estados reconocibles mediante texto e iconos, además del color. Las etiquetas usan vocabulario consistente: «Obtener cambios» para fetch, «Traer cambios» para pull y «Enviar cambios» para push; una ayuda breve conserva los términos Git entre paréntesis.

## 2. Gestor de repositorios

Es la entrada cuando no hay repositorios abiertos. Contiene «Abrir carpeta», «Clonar», búsqueda y secciones «Abiertos», «Favoritos», «Recientes» y «Grupos locales». Los grupos organizan referencias sin mover carpetas. Los contadores reflejan elementos disponibles y coincidencias del filtro.

Cada fila presenta nombre, ruta abreviada, rama o estado HEAD separado, cambios locales y disponibilidad. Las acciones permiten abrir, marcar como favorito, asignar a un grupo, mostrar la carpeta y quitar de recientes. «Quitar de recientes» y «Cerrar» nunca eliminan archivos. Una ruta inexistente conserva la entrada con las opciones «Localizar carpeta» y «Quitar referencia». Los grupos se crean, renombran y eliminan conservando los repositorios que contienen.

La búsqueda local filtra por nombre, ruta y grupo. Sin coincidencias conserva el texto y ofrece «Limpiar búsqueda». La pantalla vacía ofrece abrir o clonar. Consultar y organizar repositorios descargados no requiere autenticación.

### Abrir un repositorio existente

1. Seleccionar carpeta y validar que corresponda a un repositorio Git; reconocer también un worktree cuya entrada `.git` sea un archivo. Los worktrees vinculados se admiten para inspección en v1; sus mutaciones gráficas permanecen bloqueadas aunque se haya otorgado confianza, hasta validar su soporte completo.
2. Mostrar nombre, ubicación y remotos detectados, sin revelar credenciales.
3. Abrir una pestaña en «Confianza pendiente», cargar inspección segura de objetos e historial y registrar el acceso en recientes.

Antes de confiar, no se evalúa el estado del área de trabajo ni se habilitan terminal u operaciones de red. La pantalla identifica carpeta y capacidades que se activarán mediante «Confiar en este repositorio». Declinar conserva la inspección segura; confiar permite cargar estado y habilitar acciones. Un repositorio previamente confiado debe conservar una identidad válida para reutilizar esa decisión.

Un error distingue carpeta sin Git, permisos insuficientes y repositorio no disponible. Si el repositorio ya está abierto, se activa su pestaña existente.

### Clonar desde Bitbucket

El formulario acepta una URL HTTPS o SSH de Bitbucket, carpeta de destino y método de conexión. Permite escoger un repositorio desde Bitbucket cuando exista una conexión válida a su API; también permite introducir la URL directamente. Antes de comenzar muestra URL sin secretos, destino, protocolo y perfil elegido. Un destino existente con contenido se rechaza con una explicación accionable.

La clonación usa transporte explícitamente autorizado, hooks vacíos y `--no-checkout`. Al terminar solicita confianza antes de checkout, filtros o terminal; declinar mantiene la inspección segura. El progreso informa fases reales y cancelación cuando sea viable. Si queda una carpeta incompleta, permite revisar o retirar ese resultado. Los fallos conservan los datos seguros y distinguen conectividad, autenticación, permisos y repositorio inexistente o inaccesible, sin afirmar inexistencia cuando el servidor oculta recursos privados.

## 3. Conexión y autenticación

La conexión expone dos capacidades por separado: **operaciones Git** y **acceso a la API de Bitbucket**. Cada una muestra su estado y una prueba de conexión propia.

- **Token:** conexión HTTPS y/o API según el tipo de token, sus permisos y el mecanismo admitido por Bitbucket. El formulario explica las capacidades solicitadas y mantiene el secreto oculto; nunca lo presenta en URL, historial ni registros.
- **SSH:** operaciones Git mediante la configuración y agente SSH del usuario. Una clave SSH no habilita por sí sola la API. Si falta acceso API, la interfaz mantiene disponibles las operaciones Git autorizadas y explica qué requiere otra conexión.
- **Heredada:** utiliza remoto, configuración Git, auxiliar de credenciales y entorno SSH existentes. La aplicación detecta capacidades mediante pruebas; no extrae ni muestra contraseñas o claves privadas.

El primer contacto SSH presenta la identidad del servidor que debe verificarse cuando corresponda. Los errores ofrecen una causa útil sin transformar una falla de API en una desconexión total del repositorio. La elección de un perfil para Git y de uno para API puede ser distinta.

## 4. Vista principal

La zona superior contiene pestañas con indicadores de confianza, cambios locales y operación en curso. Una cabecera fija muestra repositorio, rama, remoto y seguimiento. La barra incluye obtener, traer, enviar y crear o cambiar rama. La disponibilidad indica si falta confianza o conexión, sin ocultar acciones.

La columna de referencias permite explorar ramas locales, ramas remotas y etiquetas, con búsqueda. Cambiar rama con modificaciones locales presenta los archivos afectados y las alternativas permitidas; nunca descarta cambios automáticamente. Un HEAD separado se muestra de forma persistente y ofrece crear una rama desde ese commit.

El centro muestra historial paginado con grafo, asunto, autor, fecha y SHA abreviado; el detalle conserva la información completa. El grafo tiene representación textual accesible de padres y referencias. La paginación conserva selección y posición de lectura.

El panel derecho presenta detalle del commit, comparación o archivo seleccionado. El usuario puede ajustar su ancho. El terminal ocupa la zona inferior, admite redimensionar, contraer y cerrar, y conserva su sesión mientras permanece abierto el repositorio. El espacio reservado al terminal no oculta el estado de una operación Git.

## 5. Selección y comparación de commits

Con un commit seleccionado se muestra su detalle: SHA completo copiable, mensaje completo, autor y fecha, referencias, padres y cambios respecto de un padre definido. Para un merge se identifica el padre utilizado y se permite elegir otro; no se presenta un único resultado ambiguo. Copiar SHA confirma la acción discretamente sin reemplazar la selección.

La comparación requiere **exactamente dos commits**. El modo de selección mantiene como máximo dos. Una tercera selección se rechaza con «Ya hay dos commits seleccionados; deselecciona uno para cambiarlo»; nunca sustituye silenciosamente un extremo. Salir del modo de comparación devuelve una selección individual coherente.

El encabezado identifica **A: base** y **B: destino**, con mensaje y SHA de ambos. A es siempre el commit inferior y B el superior según el orden visible del historial; el orden de clics no afecta la comparación. No hay inversión manual. La leyenda «Cambios para pasar de A a B» define el sentido.

El resultado compara los árboles de A y B directamente. No representa automáticamente el rango de commits ni una comparación desde el ancestro común. Permite comparar commits de ramas distintas y muestra el resultado incluso si uno no es antecesor del otro.

La lista de archivos ofrece vista por rutas o árbol y filtros por estado. Cada archivo indica agregado, modificado, eliminado o renombrado según el resultado obtenido. El diff admite vista unificada y lado a lado, búsqueda y navegación entre cambios. Binarios, archivos grandes, permisos, enlaces simbólicos y submódulos tienen estados explícitos; un archivo sin previsualización sigue apareciendo en la lista. Si ambos árboles coinciden, se informa «Sin diferencias entre A y B».

Los cambios locales se consultan desde una vista distinta que separa área de trabajo e índice. Sus comparaciones identifican sus extremos: trabajo frente a índice, e índice frente a HEAD. No utilizan las dos selecciones del historial.

## 6. Flujos de operaciones

**Obtener cambios:** indicar remoto, actualizar referencias y mostrar resultado. **Traer cambios:** identificar seguimiento y ejecutar ff-only por defecto. Si hay divergencia o falta seguimiento, explicar el estado y orientar la resolución desde terminal. Merge y rebase se resuelven allí en esta versión. Los conflictos existentes muestran archivos pendientes, estado y orientación para continuar o cancelar desde terminal.

**Enviar cambios:** mostrar rama local, remoto y rama de destino, además de los commits previstos cuando puedan determinarse. Una rama sin seguimiento requiere elegir destino. Un rechazo conserva la información y explica si faltan permisos, cambió el remoto o existe una restricción de rama.

**Editar mensaje del último commit:** función incluida, también para commits publicados. Aclara «editar comentario del último push»: un push puede contener varios commits y no posee un mensaje de commit editable propio. La acción se limita al último commit de la rama y muestra mensaje actual, propuesta y efecto sobre el SHA.

Si ya fue publicado, el flujo avanzado explica que corregirlo reescribe historia, comprueba rama, permisos y referencia remota, y presenta el plan antes de modificar. La confirmación identifica la rama afectada. Nunca ofrece un envío forzado sin protección; si el remoto cambió respecto de la referencia verificada, se detiene y exige actualizar la evaluación. Los cambios locales del índice y del área de trabajo no se incorporan a una corrección de mensaje. Un resultado parcial distingue modificación local y publicación remota para permitir recuperación informada.

## 7. Terminal inferior

El terminal se habilita tras confiar, inicia en la carpeta del repositorio y mantiene sesiones diferenciadas entre pestañas. Admite interacción, selección, copia, pegado y redimensionamiento. Un pegado de varias líneas se puede revisar antes de enviarlo.

Las modificaciones ejecutadas en el terminal actualizan estado, referencias e historial de la aplicación. Durante el plan y ejecución de edición publicada se pausa la nueva entrada al terminal gestionado, conservando salida, scroll y copia; se permite interrumpir un proceso activo. La pausa termina al completar, fallar o cancelar la operación. No detiene procesos ya iniciados, herramientas externas ni escrituras fuera de EfbyGitDesk: esos cambios invalidan el plan. Otras operaciones muestran contención y errores sin prometer exclusión global. Cerrar una sesión activa informa si sigue ejecutando un proceso y permite conservarla.

## 8. Estados, accesibilidad y criterios UX

Todas las regiones contemplan carga, vacío, éxito y error. Sin red siguen funcionando historial local, búsqueda, comparación y terminal; las acciones remotas explican su fallo o disponibilidad. Un repositorio sin commits muestra su estado inicial. Cambios locales, conflictos y HEAD separado tienen indicadores persistentes. Una operación prolongada ofrece progreso por fase y cancelación solo donde sea viable.

La navegación es completa por teclado y VoiceOver. Atajos propuestos: `⌘O` abrir carpeta, `⇧⌘O` gestor, `⌘F` buscar en la región activa, `⇧⌘C` copiar SHA y `⌘J` alternar terminal. Sus combinaciones se muestran en los menús de macOS y no interceptan entrada del terminal cuando tiene el foco. Los controles tienen nombre accesible, foco visible y objetivos de al menos 32 puntos, ampliables con densidad cómoda. VoiceOver anuncia selección, extremos A/B y resultados sin releer el historial completo. El color nunca es la única señal.

En ventanas estrechas, las referencias se contraen, la comparación conserva ambas columnas con desplazamiento horizontal independiente y el detalle puede abrirse como región dedicada. Repositorio, rama y extremos A/B permanecen identificables. El ancho mínimo se definirá al validar el prototipo en macOS.

La aceptación UX exige que: quitar referencias no elimine carpetas; la selección admita como máximo dos commits; la dirección se mantenga del commit inferior al superior; copiar entregue el SHA completo; errores remotos conserven contexto; corregir mensajes no incluya cambios preparados; el terminal refresque la vista; y los flujos funcionen con teclado y VoiceOver.
