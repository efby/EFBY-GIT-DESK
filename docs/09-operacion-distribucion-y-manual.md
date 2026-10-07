# Operación, distribución y manual previsto

Versión 0.1 · 6 de octubre de 2026 · Describe el comportamiento esperado de la futura aplicación; todavía no existe un instalador.

## 1. Instalación y requisitos

La propuesta técnica es macOS 14 o posterior, binario arm64/x86_64 y Git instalado separadamente. Las versiones mínimas finales se fijan tras H0. La aplicación comprueba Git al arrancar: ejecutable válido, versión y capacidades necesarias. Si la instalación de Apple requiere Command Line Tools, se explica cómo obtenerlas; EFBY Git Desk no instala ni reemplaza Git silenciosamente.

Distribuir un `.app` en DMG o ZIP firmado con Developer ID, Hardened Runtime y notarización; verificar firmas y ticket del artefacto final. Apple documenta los requisitos de firma, runtime y timestamp para notarización. [Notarización de software macOS](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

La distribución propuesta es directa fuera de Mac App Store, sin App Sandbox en v1, para permitir terminal libre y herramientas del usuario. No implica ejecutarse como administrador. Los permisos de privacidad de macOS pueden impedir acceso a una carpeta o herramienta: mostrar la causa y permitir elegir otra ubicación. No solicitar acceso total al disco como condición general.

Los ejecutables auxiliares del mecanismo askpass también se firman. Evitar entitlements que relajen protecciones sin una necesidad comprobada. El mismo build que se envía a usuarios se ensaya desde Finder en un perfil limpio, con la cuarentena normal de una descarga; no se valida distribución solo ejecutando desde Xcode.

## 2. Primera sesión

1. Seleccionar o detectar Git y completar diagnóstico de capacidades.
2. Abrir una carpeta existente o elegir «Clonar».
3. Revisar el estado de confianza de una carpeta nueva; una conexión válida no concede confianza en scripts del repositorio.
4. Elegir transporte heredado, SSH o token. Agregar token API solo si se desea catálogo Cloud.
5. Identificar rama y remoto de seguimiento antes de sincronizar.

En un clon nuevo, primero se transfieren objetos sin checkout. La aplicación explica la configuración que podría ejecutar filtros/herramientas y pide confiar antes de materializar el working tree. El usuario puede conservar la copia para inspeccionar historial sin iniciar esos programas.

## 3. Uso cotidiano

El gestor busca por nombre, ruta y grupo. «Cerrar» cierra una pestaña; «Quitar» elimina una referencia del catálogo local; ninguna de esas acciones elimina la carpeta del repositorio. Favoritos y grupos son locales a EFBY Git Desk.

En la vista de trabajo, la cabecera muestra repositorio, rama y remoto. «Obtener cambios (fetch)» actualiza referencias. «Traer cambios (pull)» admite fast-forward; si existe divergencia, muestra las alternativas y requiere resolverla explícitamente por terminal en v1. «Enviar cambios (push)» muestra el destino antes de ejecutarse. El servidor puede rechazar el envío aunque la conexión funcione.

La vista de cambios separa archivos preparados y pendientes. Preparar un archivo añade su estado actual al índice; editarlo después puede producir cambios preparados y pendientes a la vez. El commit incluye lo preparado, con hooks/firma del proyecto cuando correspondan.

El terminal inferior comienza en la carpeta del repositorio y conserva su contexto. El prompt de la shell puede cambiar si el usuario navega a otra carpeta; la ubicación inicial no garantiza el cwd actual. La aplicación sigue observando el repositorio abierto y muestra su identidad fuera del prompt. Refrescar manualmente está disponible si un cambio externo no se detecta de inmediato.

## 4. Comparar commits y copiar SHA

Entrar en comparación y seleccionar A y B. El commit inferior del historial es la base y el superior es el destino, independientemente del orden de selección. Con exactamente dos commits, la lista muestra los cambios para pasar de A a B. Seleccionar un archivo abre ambas versiones completas en columnas paralelas, con números de línea y cambios resaltados. Una tercera selección requiere quitar primero uno de los extremos.

La comparación muestra todos los archivos detectados aunque un binario o archivo grande no pueda representarse como texto. Un filtro puede ocultar filas visualmente, pero se indica el total y el filtro activo. Si los árboles son iguales, el resultado informa que no hay diferencias aunque los SHA sean distintos.

«Copiar SHA» copia el identificador completo. Un único commit muestra detalle y cambios respecto de un padre identificado; un merge permite elegir padre. Eso es distinto de la comparación de dos commits.

## 5. Corregir el último mensaje publicado

La acción se habilita para HEAD de una rama local, sin staging pendiente ni integración en curso. La app obtiene información remota reciente y exige que el HEAD original sea la punta de la rama de destino. No permite modificar un commit anterior enterrado en la historia.

La revisión muestra mensaje actual y nuevo, SHA anterior, rama/remoto, efecto sobre firma y referencia de recuperación. Tras confirmar, crea un commit nuevo con el mismo árbol/padres/autor y publica con una lease ligada al OID esperado. Una política de rama puede rechazarlo.

Un fallo de publicación puede dejar el nuevo commit solo en local. La interfaz distingue «editado localmente», «publicación verificada» y «requiere revisión». Si la respuesta del servidor se pierde, consulta el estado antes de sugerir reintentar. Nunca promete deshacer automáticamente el cambio ni recurre a un force push general.

## 6. Recuperación y respaldo

| Situación | Respuesta prevista |
|---|---|
| Aplicación cerrada durante una operación | Al reiniciar, marcar operación interrumpida y consultar estado real; no relanzar escrituras |
| Push con timeout | Verificar referencia remota y comparar con OID previsto antes de otro envío |
| Amend local con push rechazado | Mantener nuevo commit y backup ref; explicar opciones y conservar ambos |
| Carpeta movida | Localizar nueva ruta y validar identidad; no recrear ni reclonar automáticamente |
| Base de metadatos dañada | Conservar copia, ofrecer restauración/exportación; repositorios Git permanecen independientes |
| Keychain bloqueado/denegado | Solicitar acceso o usar credencial solo en memoria; no guardar en texto plano |
| Clone parcial | Marcar carpeta incompleta y ofrecer revisar/limpiar únicamente el resultado de esa operación |
| Lock Git externo | Informar contención y esperar/inspeccionar; no eliminar el lock automáticamente |

Las referencias de recuperación mantienen el commit anterior alcanzable en el repositorio local. No reemplazan un respaldo completo del working tree, archivos sin seguimiento o servicio remoto. Para restaurar una referencia, comprobar su valor actual y el trabajo pendiente, explicar el efecto y requerir una acción expresa; no sugerir `reset --hard` como recuperación universal.

Exportar metadatos locales conserva grupos/favoritos/preferencias y perfiles sin secretos. Importar valida rutas y marca capacidades de conexión por verificar. Los tokens no viajan en el export; las claves SSH permanecen en el mecanismo del usuario. Un backup de la base se crea antes de migraciones; su importación no modifica Git.

## 7. Diagnóstico y soporte

El panel de diagnóstico muestra versión app/macOS/Git, arquitectura CPU, Git seleccionado, capacidades disponibles, último fetch y códigos de operaciones. No muestra tokens, claves, cabeceras Authorization ni output completo del terminal.

Una exportación de diagnóstico es revisable antes de guardar/compartir y permite ocultar rutas y nombres de repositorios. No hay telemetría remota en MVP. Soporte solicita un ejemplo mínimo o repo sintético cuando un patch real podría contener datos privados.

| Problema | Comprobación y siguiente acción |
|---|---|
| SSH funciona en Terminal y falla en EFBY Git Desk | Revisar Git ejecutable, SSH_AUTH_SOCK, host alias y herramientas disponibles desde Finder |
| API funciona, push falla | Revisar transporte, scope de escritura, repositorio y política de rama; API no prueba capacidad Git |
| Clone por SSH funciona, catálogo vacío | Conectar API token y comprobar workspace/permisos; mantener clonación por URL |
| Pull no continúa | Mostrar divergencia, upstream ausente o cambios bloqueantes; resolución explícita por terminal |
| Diff incompleto | Revisar filtro, indicador de límite y objetos faltantes; cargar más o fetch autorizado |
| Mensaje editado cambia SHA | Comportamiento esperado: nueva identidad del commit; mostrar ambos OID y backup |
| Conflicto detectado | Mostrar archivos y operación Git en curso; resolver/continuar/abortar en terminal sin descarte automático |

## 8. Actualizaciones y desinstalación

La primera versión se actualiza mediante instalación manual de un build firmado. Las notas indican cambios de compatibilidad y migraciones. Antes de reemplazar, esperar operaciones activas y cerrar sesiones terminales. La actualización no relanza comandos ni cambia configuración global Git/SSH.

Desinstalar la app no elimina repositorios. Ofrecer una acción separada para eliminar metadatos y secretos propios de EFBY Git Desk, identificando exactamente su alcance. Esa acción no revoca tokens en Atlassian ni borra claves SSH del usuario. Mantener instrucciones de revocación y respaldo en el manual final.

## 9. Lista de release

Comprobar matriz RF/QA, límites y notas; versiones/dependencias fijadas; ausencia de credenciales en bundle/logs; firma de app/helpers; notarización y ticket; instalación limpia desde Finder; terminal/Git/agente/Keychain; actualización con preferencias anteriores; VoiceOver/teclado; prueba de lease fallida y recuperación. El informe adjunta resultados reales y excepciones. Esta lista es un plan y no certifica un producto aún no construido.

El bundle de desarrollo se genera como `dist/EFBY Git Desk.app`. Abrir carpeta busca Git en todos los descendientes y registra el árbol de proyectos; seleccionar un resultado abre únicamente ese repositorio. La búsqueda es cancelable. Los datos existentes y credenciales conservan sus identificadores internos para evitar migraciones por el cambio del nombre visible.


### Tamaños de paneles y cierre del compare

El botón **Cerrar**, con fondo rojo, vuelve al repositorio; Esc mantiene la misma acción. La comparación A→B comienza en 340 puntos (mínimo actual) y carpetas en 340 (máximo actual, reducible hasta 210). Arrastrar sus separadores permite ajustar los anchos. La app guarda los tamaños elegidos y los restaura al cambiar de repositorio o iniciar otra sesión. Una ventana más pequeña limita temporalmente el espacio sin reemplazar la preferencia. Restablecer distribución recupera esos valores iniciales.


El visor de diferencias mantiene **Comparación A→B** a la derecha, con sus commits y lista de archivos. Haz clic en otro archivo para sustituir los documentos sin cerrar la comparación. El archivo actual queda marcado y el separador permite adaptar el ancho, compartido con el panel de la pantalla principal y guardado entre sesiones. **Cerrar** o Esc vuelve al workspace con la selección de commits conservada. También funciona con el detalle de un commit y las comparaciones del índice/working tree.
