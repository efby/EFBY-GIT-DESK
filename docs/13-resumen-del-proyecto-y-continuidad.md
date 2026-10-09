# EFBY Git Desk — resumen del proyecto y continuidad

Corte documental: **8 de octubre de 2026**, base `f75d7c7` (merge documental
del PR #22), con la app distribuida de `a5dbee4` (`v0.1.12`) y las correcciones
de navegación descritas más abajo. Este documento permite retomar el proyecto
sin reconstruir conversaciones. La evidencia de Releases que figura más abajo
corresponde a su verificación histórica hasta v0.1.2; no se ha comprobado aquí
el DMG de v0.1.12 en un equipo de destino.

## Identidad, alcance y fuentes

- Nombre visible: **EFBY Git Desk**. Proyecto, package y módulos: `EfbyGitDesk`.
- Repositorio de desarrollo: [efby/EFBY-GIT-DESK](https://github.com/efby/EFBY-GIT-DESK).
- Aplicación nativa solo macOS; integración gestionada inicial con Bitbucket Cloud.
  GitHub aloja el desarrollo y distribución; no supone integración GitHub en la app.
- Clean Architecture obligatoria; Git es fuente de verdad de archivos y referencias.
- La documentación 01–10 conserva requisitos, diseño base, contratos y aceptación.
  [11](11-estado-mvp.md) registra la evolución y resultados históricos.
  [12](12-dmg-y-github-actions.md) es la guía de firma, notarización y Actions.
- El espejo de ChatGPT conserva su identidad EfbyGitControl. Sus `sources/` y
  referencias sincronizadas no se modificaron; el desarrollo y esta documentación
  versionada viven en `EFBY-GIT-DESK/`. Hay una copia auxiliar de trabajo para PR.

## Arquitectura implementada

| Capa / módulo | Responsabilidad |
|---|---|
| EfbyGitDeskDomain | Valores Git, repositorios, commits, comparación y sus invariantes |
| EfbyGitDeskApplication | Casos de uso, puertos, confianza, coordinación y planes de operación |
| EfbyGitDeskInfrastructure | Git CLI, procesos, SQLite, Keychain, Bitbucket REST y PTY |
| EfbyGitDeskPresentation | SwiftUI/Observation, modelos MainActor y controles AppKit |
| EfbyGitDeskApp | Composición e inyección de adaptadores |
| EfbyGitDeskCredential | Helper de credenciales con referencias a secretos |

Swift 6 con concurrencia estricta; SwiftUI y AppKit para paneles, texto y terminal.
SQLite y frameworks del sistema; no se añadieron frameworks de terceros ni
SwiftTerm. El terminal es un PTY propio con soporte VT básico. Swift 6.4 fue
verificado localmente; Actions utilizó Xcode 26.5/Swift 6.3.2 en ensayos registrados.
El mínimo de compilación es macOS 14. App y auxiliar se generan arm64/x86_64,
sin atribuir por ello ejecución comprobada en Intel/macOS 14.

## Funciones del MVP

El registro local permite repositorios, pestañas, favoritos, grupos, recientes,
confianza y preferencias persistidas. Abrir una carpeta superior descubre proyectos
Git en sus subcarpetas y construye un árbol navegable. La búsqueda encuentra
repositorios por nombre, ruta o grupo aun con carpetas contraídas. El descubrimiento
no concede confianza ni ejecuta hooks; informa resultados parciales y permite cancelar.

La marca EFBY Git Desk está en la barra superior junto a un símbolo de ramas
cian del tamaño del anterior logotipo. El lateral se titula **Explorador**, con
símbolo de panel, y Bitbucket Cloud permanece
como conexión opcional. Bajo el árbol,
tres botones de igual ancho permiten agregar carpeta, hacer **Fetch de todos** y
**Confiar en todos**. El fetch recorre los remotos
de cada repositorio confiable de forma secuencial, revalida identidad antes de leer
remotos y conserva un resultado por remoto; omite los no confiables, los de solo
inspección y los que no tienen remoto. Un error individual no detiene los demás.
El panel de progreso aparece al iniciar, indica el proyecto/remoto en curso y
añade resultados uno por uno. Permite cancelar y conserva el resumen al terminar.
La confianza global requiere revisar la lista de pendientes y confirmar una advertencia
sobre hooks/filtros/auxiliares, terminal y checkout de clones. Tras confirmar,
la misma hoja muestra el progreso por repositorio y permite cancelar o revisar
el resumen final. `DeskService.trust` revalida cada identidad; no se confía en
worktrees vinculados ni repositorios que
solo admiten inspección. Ambos procesos admiten cancelación y muestran resultados
parciales. La comprobación visual de la hoja se hizo sin ejecutar confianza sobre
los repositorios personales del equipo.
La suite local de esta rama terminó con 104 pruebas registradas, 102 aprobadas
y 2 optativas omitidas en 23 suites; el bundle de desarrollo compiló con firma
ad hoc verificada. No se generó ni comprobó un DMG de distribución.

El workspace ocupa el área disponible incluso sin seleccionar commits. Las acciones
se presentan en pestañas **Pendientes**, **Preparados** e **Historial**, con contadores;
las ramas están en el menú **Ramas**, sin el antiguo lateral de área de trabajo.
Los paneles son redimensionables y recuerdan ancho. Los valores iniciales registrados
son 340 puntos para comparación y lateral; el mínimo del lateral es 210. El visor
reserva espacio para documentos y el navegador de archivos según tamaño disponible.

La pestaña activa ya identifica el repositorio. La cabecera central muestra como
contexto sus dos carpetas superiores y la rama, con la ruta completa en ayuda y
accesibilidad. **Pendientes**, **Preparados** e **Historial** se conservan como
estados distintos.
El visor de archivos extiende ese contexto a **carpetas / repositorio / archivo**
en su cabecera y ofrece la ruta absoluta como ayuda.

Se implementaron ramas, staging por archivo, commit del índice, fetch, pull solo
fast-forward y push con destino explícito. Historial paginado, grafo, búsqueda y SHA
completo. La búsqueda acepta SHA completo o prefijo hexadecimal de al menos cuatro
caracteres (sin distinguir mayúsculas), además de mensajes para las consultas no
hexadecimales. Busca objetos commit alcanzables desde las referencias del historial,
no solamente la página cargada; admite SHA-1 y SHA-256. Prefijos con más de 64 objetos
solicitan más caracteres. No interpreta expresiones como `HEAD~1` ni opciones Git.

Cambiar o borrar la búsqueda conserva los commits seleccionados, sus datos y el
contexto de comparación. Si un seleccionado queda fuera del filtro o de la página,
se muestra una selección conservada que permite quitarlo. La paginación mantiene
su propio contador y no incorpora esos commits artificialmente. La dirección A→B
se conserva al filtrar; si el par se elige desde búsquedas diferentes, se consulta
el orden topológico de Git antes de comparar. Esa consulta está acotada a 16 MB;
un límite o fallo bloquea la comparación con aviso, sin inventar el orden.

Clonación sin checkout, seguida de confianza antes de materializar archivos.
Tokens en Keychain y transporte SSH/helpers heredados, separados del catálogo REST.

Editar el mensaje de HEAD crea recuperación y un plan de un solo uso que caduca a
los 60 segundos. Conserva árbol, padres y autor y revalida antes de escribir. Publicar
requiere tip remoto coincidente y lease con ref/OID esperado; sin force push genérico
ni rollback automático. La recuperación permanece ante fallos. La matriz RF-01…RF-16
y sus límites están en [11](11-estado-mvp.md); implementación no equivale a QA completo.

El Git de ejecución se detecta entre instalaciones existentes del usuario (PATH,
`~/.local/bin`, `~/bin`, `~/miniforge3/bin`, perfiles Nix/Homebrew y rutas habituales Homebrew,
MacPorts y `/usr/local/git/bin`). No se ejecutan `/usr/bin/git`, sus enlaces ni
rutas de herramientas de Apple durante la detección/configuración. Ajustes → Git
permite elegir o escribir una ruta absoluta y conservarla para siguientes sesiones;
se aplica antes de reabrir repositorios guardados. No exige Xcode, su licencia ni
permisos de administrador para usar la app distribuida. Git ≥2.40 es necesario
para leer y operar repositorios, aunque ya estén descargados. No se instala,
actualiza ni reemplaza Git; un fallo deja accesible el catálogo y los ajustes.
Una ruta incorrecta no sustituye una instalación ya validada. No se ejecutan
perfiles de shell para descubrir Git ni se buscan ejecutables dentro de repositorios.

El terminal inferior conserva sesiones al ocultarse; admite directorio, resize,
Unicode y Ctrl+C. Refresca cambios al recuperar foco y periódicamente. No restaura
procesos vivos al reiniciar ni persiste su salida. Quitar registros conserva repositorios.

## Comparación y lectura de código

1. Seleccionar exactamente dos commits distintos. A es el inferior del historial y
   B el superior, independientemente del orden de clic. Un tercer clic sobre otro
   commit pregunta si se quiere limpiar el par anterior. Cancelar conserva ambos;
   aceptar deja seleccionado el último commit pulsado para elegir su compañero.
   Pulsar uno de los dos seleccionados continúa quitándolo sin pedir confirmación.
2. Comparar directamente sus árboles A→B, también entre ramas sin ancestro común;
   nunca sustituir por merge-base o triple punto.
3. Mostrar inventario; el diff se abre **solo al hacer clic en un archivo**.
4. El visor cubre la misma ventana de la app y conserva montado el workspace. No
   activa fullscreen de macOS. **Cerrar**, en rojo, o `Esc` recuperan la vista anterior.
5. El panel derecho permanece visible para cambiar de archivo sin cerrar el visor.

El panel derecho muestra tarjetas apiladas: B superior y A inferior, mensaje,
SHA copiable, fecha local y **autor del commit**. Git no registra quién hizo push.
Hay URL opcional para avatar, pero el adaptador local no obtiene fotos: actualmente
se usan iniciales. La integración de perfiles del proveedor sigue pendiente; no se
consulta Gravatar ni se envían correos a servicios externos para obtener imágenes.

Los archivos aparecen en árbol con carpetas desplegables, conteos, selección,
iconos/color por tipo de cambio y un control que alterna **Expandir todo** y
**Colapsar todo** según su estado. Se conservan
bytes e identidades de rutas, incluso no UTF-8 y sustituciones archivo/directorio.
La casilla **Todos los archivos** consulta el árbol del commit de destino o el índice
para incluir archivos sin cambios; la lista de modificaciones conserva los eliminados.
El árbol se construye fuera del actor principal. La cabecera de repositorios muestra
el icono de EFBY Git Desk ya incorporado al bundle en lugar de las letras «EF».
No se agregaron controles de ordenamiento ni selector Path/File. Las filas compactas
usan 3 puntos de padding vertical en lugar de 7, separación interna de carpeta 0
y raíz 1; se redujo margen del texto de ayuda y Expandir todo sin reducir la fuente.

Se retiraron las cabeceras duplicadas Documento 1/Documento 2, SHA y ruta sobre el
código, porque las tarjetas y la barra del archivo ya identifican el contexto.
El aviso de falta de salto de línea final sigue visible solo cuando corresponde.
Los archivos CRLF se dibujan sin símbolos de retorno de carro al final de cada
línea; sus bytes originales siguen disponibles para la comparación.

Ambos documentos sincronizan scroll horizontal y vertical, con números originales
y huecos cuando no hay correspondencia. La barra **Modificaciones**, navegación al
cambio anterior/siguiente y distancia en líneas al próximo cambio se conservan.
La distancia hacia abajo se calcula desde el borde inferior visible. Cada columna
lleva un mapa vertical detrás del indicador de scroll: rojo eliminado, verde añadido.

Las líneas iguales, incluso desplazadas, no se marcan. La alineación usa anclas
únicas y matching exacto Myers acotado entre anclas, manteniendo el orden documental.
Si los bloques cruzan posiciones, no se fuerza un emparejamiento que cruce el orden.
Los límites y fallback explícito están en 11: 50.000 líneas combinadas, presupuesto
2.000.000 operaciones y 250.000 entradas de traza. No es equivalencia semántica.

Texto eliminado rojo y añadido verde. Las modificaciones de líneas existentes
resaltan solo los fragmentos cambiados en ambos lados; texto común queda sin marca.
Una línea totalmente nueva tiene fondo verde tenue y signo +, sin resaltado intenso
por fragmentos. El hueco del otro lado queda neutro. Una línea vacía existente que
recibe texto es una modificación. Se preservan sintaxis y selección manual.

El selector de formato detecta Python, JS/JSX, TS/TSX, Dart, Swift y otros lenguajes conocidos;
permite elección manual o texto plano. Es resaltado léxico, sin ejecutar código.
Binarios, LFS, enlaces, submódulos y contenido grande muestran resumen/límite; el
límite textual de 2 MB no debe convertirse en omisión silenciosa del inventario.

Capturas sintéticas revisadas, no sesiones de repositorios personales:

![Tarjetas y árbol compacto](evidencia/compare-panel-compacto.png)

![Visor sin cabeceras duplicadas y barra Modificaciones conservada](evidencia/compare-sin-cabeceras.png)

El icono conserva el logotipo y estilo de EFBY_POSTMAN, con etiqueta **#GitDesk**.
Fuentes y generación: `Resources/Brand/EfbyLogo.ai` y `scripts/generate-icon.sh`.

## Carpetas persistentes y enlaces de código — PR #14 a #21

El PR #14 guardó en SQLite las carpetas contraídas del árbol de proyectos y del
árbol de comparación (este último por repositorio). El control de comparación
alterna **Expandir todo** y **Colapsar todo** según las carpetas visibles; cambiar
el filtro de archivos conserva el estado de las carpetas ocultas por ese filtro.
Las filas del inventario se materializan con `LazyVStack`, evitando crear de
entrada todas las vistas de archivos. La búsqueda de proyectos sigue encontrando
repositorios dentro de carpetas contraídas.

La navegación por funciones evolucionó después de ese PR. **Estado actual:** el
árbol lista archivos, sin sublistas de funciones. En el documento derecho del
visor, las llamadas, nombres de clase y ciertas referencias de tipos se subrayan
cuando el índice encuentra una declaración suficientemente determinada. Pulsar
un enlace abre el archivo de destino en el mismo visor y salta a su línea; el
nombre de una clase y el de su método pueden ser enlaces separados. Esto funciona
con el filtro **Todos los archivos** activo o inactivo, pues el salto puede abrir
un archivo ausente de la lista filtrada. **Volver** o Comando + [ retrocede por
los archivos visitados y restaura el desplazamiento horizontal y vertical.
Los enlaces se ofrecen en comparaciones textuales alineadas con documento A y B;
los cambios binarios, truncados o sin uno de los documentos siguen usando el
resumen/visor anterior.

El índice reconoce patrones comunes de Python, JavaScript, TypeScript y Dart,
incluidos imports relativos y varias formas de declaración, métodos, constructores
y campos tipados. Usa el archivo abierto para extraer nombres, imports y tipos de
receptor; una consulta Git acotada busca declaraciones candidatas en la revisión
comparada. Prefiere el módulo importado o la clase receptora y omite el enlace
cuando no logra desambiguar. Es **navegación heurística**, no un servidor de
lenguaje: no resuelve todas las importaciones dinámicas, sobrecargas, sintaxis
multilínea o nombres generados, y puede omitir enlaces válidos. No ejecuta código
ni modifica archivos del repositorio.

Límites observados en código: 2 MB para indexar el texto abierto, 20.000 líneas y
500 símbolos por archivo; hasta 80 nombres de llamada y 400 coincidencias de
búsqueda Git por consulta, con salida acotada a 2 MB. La caché en memoria conserva
hasta 48 revisiones inmutables de archivos, separadas por repositorio; los contextos
de índice y working tree se vuelven a consultar para no conservar declaraciones
obsoletas. El historial de **Volver** conserva hasta 64 saltos. Git
excluye carpetas típicas de dependencias y compilación (`node_modules`, `dist`,
`.next`, `build`, `coverage`, `vendor`). Ningún límite convierte una búsqueda
heurística de símbolos en prueba de ausencia de una declaración.

Secuencia integrada: PR #14 persistencia e índice inicial; #15 estabilización
del test de panel; #16–#19 enlaces en el visor, importaciones, navegación entre
archivos y restauración de posición; #20 ajuste de compilación del test en CI;
#21 campos tipados y resolución de métodos por tipo. Los tags locales recorren
v0.1.6 a v0.1.12. En este corte, una compilación limpia de `origin/main` y la
suite Swift Testing terminaron correctamente: **100 pruebas registradas, 98
aprobadas y 2 opcionales omitidas**, en 22 suites. Registro local:
`/private/tmp/gitdesk-review-tests.log`. Se comprobaron parsers, ambigüedad,
saltos entre archivos y persistencia con fixtures; quedan pendientes la
verificación visual de la app distribuida, el DMG descargado y pruebas sobre
repositorios reales grandes.

### Corrección de enlaces tras la auditoría del 8 de octubre

La revisión de los PR #14–#21 detectó que el índice podía reutilizar destinos de otro
repositorio o de archivos locales modificados, aceptar líneas comentadas como
declaraciones y escoger la primera sobrecarga cuando había varias coincidencias.
La corrección incorpora el repositorio a la clave de caché, no reutiliza los
resultados en índice/working tree, descarta comentarios reconocibles en la línea
declarada y deja sin enlace los
destinos ambiguos. Las respuestas asíncronas comprueban también la solicitud,
el repositorio y el contexto antes de publicarse.

Los enlaces del visor derecho usan ahora el atributo estándar de AppKit y se
activan con Retorno al seleccionarlos. La suite comprueba ese atributo y la
activación por teclado; la aceptación manual con VoiceOver sigue pendiente.
Validación local: **102 pruebas registradas, 100 aprobadas y 2 opcionales
omitidas** en 22 suites; bundle de desarrollo construido con firma ad hoc y
verificación `codesign` correcta. No se ha verificado un nuevo DMG distribuido.

## Distribución y reglas del repositorio

Trabajar en ramas y PR; **no hacer push directo a main**. No se alteraron reglas de
protección del servidor: esta norma es parte del flujo de desarrollo acordado.

| Evento | Resultado |
|---|---|
| PR interno fusionado hacia main | Tests, firma, notarización, artefacto y Release |
| PR abierto/actualizado/cerrado sin merge | No genera DMG |
| Push a rama o tag | No genera DMG |
| Release DMG manual en main | Genera y publica Release |
| Release DMG manual en otra rama | Genera artefacto; no publica Release |
| Fork o Dependabot | Firma automática omitida; no ejecutar código externo con secretos |

Se compila el SHA del merge. App y auxiliar universales; firma Developer ID con
Hardened Runtime/timestamp; ZIP de la app aceptado por Apple, ticket de app adjunto;
DMG creado, aceptado y con ticket. Verificación estricta, checksum, montaje readonly,
enlace Applications, ticket de app montada y Gatekeeper antes de entregar. No se
re-firma el DMG ni se degrada a unsigned si faltan secretos. Guía operativa: [12](12-dmg-y-github-actions.md).

La publicación verifica checksum del artefacto descargado por su trabajo, crea tag
semántico sobre el SHA compilado y adjunta DMG/checksum con notas automáticas.
Primera versión v0.1.0; siguientes incrementan patch del mayor tag semántico,
respetando una versión base superior en Info.plist. APP_VERSION se aplica antes de
firmar. No reemplaza Releases existentes. El flujo se serializa sin cancelar el
trabajo activo. La escritura de contenido se limita al trabajo de publicación.

Secretos requeridos, **solo nombres**: MACOS_CERTIFICATE_P12_BASE64,
MACOS_CERTIFICATE_PASSWORD, APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID.
Los valores, .env, .p12, PEM y deploy keys permanecen fuera de Git. GitHub no permite
recuperar valores de secretos existentes. Se reutilizó el origen autorizado de
POSTMAN, aislando la identidad de distribución sin modificar el proyecto de referencia.

## Incidencias resueltas y evidencia

| Problema | Corrección / evidencia |
|---|---|
| Actions detenido después de Build complete! | ProcessJob bloqueaba hilos del ejecutor cooperativo de Swift. Dispatch concurrente + continuación async conserva cancelación/timeout/drenaje; regresión con 24 procesos y 128 KB. Build complete indica compilación, no tests aprobados. |
| Esperas indefinidas de CI | Supervisor con diagnóstico a 120 s y límite de 300 s, terminación del grupo de procesos propio; paso Tests con límite de 10 minutos. |
| Test de ventanas intermitente | Validar identidad de ventana/contenido propio, sin comparar NSApp.windows.count mientras otras suites crean ventanas. |
| PKCS12 RC2 no leído por OpenSSL 3 | Activar proveedor legacy al descifrar el contenedor existente; no cambiar verificación TLS. |
| SecKeychainItemImport rechazó /dev/stdin | Importar PEM completo desde directorio temporal 0700, archivos 0600; contraseña por entorno, eliminación inmediata, trap y limpieza final. |
| Credenciales Apple/acuerdo pendiente | El propietario aceptó el acuerdo y Apple validó credenciales; no se afirma que cambiar una contraseña resolviera ese problema. |
| DMG solo en Actions, sin Releases | Trabajo de publicación con tag, notas, checksum y asset DMG tras generación exitosa. |

Las ejecuciones inicialmente bloqueadas se cancelaron. Los intentos fallidos se
conservan en Actions y el registro 12, separados de las verificaciones exitosas.

- Suite local posterior a las tarjetas: **83 registradas, 81 aprobadas, 2 optativas
  omitidas, 19 suites, 6,439 s**. No atribuir ejecución de optativas a esa regresión.
- Ajuste de cabeceras: una prueba de overlay aprobada, 0,606 s; build/captura revisados.
- Árbol compacto: dos pruebas existentes aprobadas, 0,532 s; build/captura revisados.
- [Release DMG #8](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37564003950):
  `7ed8af5`, compare actualizado y certificado corregido; generación 4m 5s,
  total 7m 48s con cola, tests/firma/notarización/verificación/subida correctos.
- [v0.1.0](https://github.com/efby/EFBY-GIT-DESK/releases/tag/v0.1.0): `c04bdd4`,
  PR #5; publicación automática verificada en [run 37564816832](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37564816832).
- [v0.1.1](https://github.com/efby/EFBY-GIT-DESK/releases/tag/v0.1.1): `15ac933`,
  PR #6; publicación automática verificada en [run 37566099456](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37566099456).
- [v0.1.2](https://github.com/efby/EFBY-GIT-DESK/releases/tag/v0.1.2): `5e26fd3`,
  PR #7; [run 37567560580](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37567560580)
  terminó correctamente en 3m 10s. Generación 2m 50s y publicación 9s. DMG de
  3,43 MB y checksum presentes; última Release cuya publicación se verificó en
  esta documentación histórica.

Resultados estructurados: [mvp-validacion.json](evidencia/mvp-validacion.json).
Los valores antiguos son snapshots de su etapa; las decisiones posteriores pueden
sustituirlos. El digest ZIP de Actions es distinto del digest del DMG de una Release.

## Pendientes y criterios de continuidad

Distribuir instaladores firmados no completa por sí solo H6. Permanecen abiertos:
cuenta real Bitbucket y ramas protegidas; helper Keychain en distribución; VoiceOver,
foco/teclado y restauración visual completos; instalación del artefacto descargado
en otro Mac; runtime Intel/macOS 14; terminal VT avanzado; avatares del proveedor;
matriz QA y objetivos de rendimiento completos (incluidos caché fría y p95).

No ampliar silenciosamente soporte de bare, sparse checkout, worktrees vinculados,
shallow/partial o submódulos. Los límites y restricciones actuales están en README/11.
La confianza precede working tree, terminal, red y mutaciones; operaciones avanzadas,
rewrite arbitrario, stash/rebase/merge automáticos y otros proveedores quedan fuera del MVP.

Para continuar: revisar este corte, consultar Git/PR/Actions reales, elegir historia
pequeña y actualizar comportamiento/evidencia/pendientes. Ejecutar pruebas pertinentes,
no sustituir evidencia histórica ni escribir secretos. Conservar originales sincronizados,
repositorios y recuperación. Dejar PR concreto para revisión; el merge activa distribución.
