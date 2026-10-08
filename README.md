# EFBY Git Desk

MVP de desarrollo de una aplicación nativa macOS para trabajar con repositorios Git locales y conectar con Bitbucket Cloud. SwiftUI/AppKit, Swift 6 y Clean Architecture; sin dependencias de terceros. Las funciones Git locales no necesitan Internet.

Incluye repositorios en pestañas, favoritos/grupos, confianza persistida, ramas, stage/unstage por archivo, commits, historial paginado con grafo, SHA completo y comparación directa A→B. También ofrece fetch, pull fast-forward, push con destino explícito, edición del mensaje de HEAD con recuperación y lease, y terminal PTY por repositorio.

## Compilar y abrir

Para desarrollar y compilar: Xcode con Swift 6.2 o posterior y Git 2.40 o posterior. Para usar el DMG instalado no se requiere Xcode: se utiliza una instalación independiente de Git accesible para la cuenta del usuario, detectable por PATH/rutas habituales o seleccionable en Ajustes → Git. No se invoca el Git de Apple ni se acepta su licencia. El entorno verificado utiliza Swift 6.4, Git 2.51 y macOS 26.6.2 en arm64. El mínimo de compilación es macOS 14; su ejecución e Intel están pendientes de validar.

```sh
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/EFBY Git Desk.app"
```

Para un paquete optimizado: `bash scripts/build-app.sh release`. El paquete incluye el helper de credenciales y lleva firma ad hoc de desarrollo. No es un release con Developer ID ni notarización. Abrir `Package.swift` en Xcode permite desarrollar los targets.

La aplicación instalada no requiere Xcode ni aceptar su licencia. Si no encuentra una instalación independiente y válida de Git, conserva el acceso al catálogo y los ajustes, pero no puede leer los repositorios. No instala ni reemplaza Git automáticamente.

## Uso inicial

1. Abre una carpeta Git. Comienza en inspección segura: historial y objetos, sin terminal, red ni cambios en archivos.
2. Revisa la carpeta y concede confianza para habilitar operaciones locales. Las credenciales y la confianza son independientes.
3. Selecciona **Pendientes** para preparar archivos y **Preparados** para revisar el índice y crear el commit. Las ramas ofrecen acciones en su menú contextual.
4. Selecciona un commit para revisar sus diferencias; selecciona dos para comparar sus árboles. Un tercer clic sobre otro commit pregunta si deseas reemplazar el par: cancelar conserva ambos y aceptar deja seleccionado el último commit pulsado para elegir el segundo. La dirección es siempre del commit inferior al superior en el historial, independientemente del orden de selección. La búsqueda del historial conserva los commits seleccionados incluso al borrarla. Puedes copiar el SHA completo.
5. Para Bitbucket, usa SSH/credenciales heredadas o agrega un API token en **Conexiones**. El catálogo necesita lectura de workspace y repositorios; publicar requiere permiso de escritura. El token se guarda en Keychain.
6. Clona en una carpeta nueva. La aplicación realiza `--no-checkout` y solicita confianza antes de materializar archivos.
7. **Editar mensaje de HEAD** presenta un plan que caduca a los 60 segundos. Publicarlo exige que HEAD coincida con la punta remota y utiliza un lease exacto. La referencia de recuperación se conserva incluso si el envío falla.
8. **Terminal** abre el panel; **Nueva sesión** inicia una shell. Ocultarlo conserva la sesión. Cerrar una sesión activa presenta confirmación. Los cambios se consultan al volver al foco y cada cuatro segundos.

**Abrir carpeta** admite un repositorio individual o una carpeta superior. Busca proyectos Git en todas las subcarpetas, conserva la estructura en un árbol expandible y recuerda las carpetas agregadas. **Buscar en todos los proyectos** encuentra repositorios por nombre, ruta o grupo incluso con el árbol contraído. No se ejecutan hooks ni se confía automáticamente en los proyectos encontrados. La búsqueda se puede cancelar; si hay carpetas inaccesibles, enlaces externos o repositorios no compatibles, la app informa el resultado parcial.

Las pestañas **Pendientes**, **Preparados** e **Historial** cambian la vista del repositorio; las dos primeras muestran sus contadores. El menú **Ramas** permite consultar ramas locales/remotas y cambiar o borrar una rama local integrada. El panel lateral de área de trabajo se eliminó para ampliar el contenido.

El repositorio ocupa todo el espacio disponible incluso sin seleccionar commits. Selecciona un commit (o dos para comparar A→B) y haz clic en un archivo para abrir su diff. El compare cubre el área de la misma ventana de la app, conservando montada la vista del repositorio y sus sesiones, sin activar el fullscreen de macOS. **Cerrar** o `Esc` recuperan la vista anterior; cambiar la selección de commits cierra el visor.

En el panel de archivos, **Todos los archivos** muestra también los archivos sin cambios del árbol seleccionado para revisar código. Desmarcado, vuelve al inventario de modificaciones. Los archivos eliminados siguen visibles al mostrar todos; un archivo sin cambios abre sus dos documentos completos al hacer clic. La cabecera lateral usa el logo de la app.

Los árboles de proyectos y comparación recuerdan las carpetas contraídas. En la comparación, el botón cambia entre **Expandir todo** y **Colapsar todo**. En el documento derecho, algunas llamadas, clases y referencias a tipos de Python, JavaScript, TypeScript y Dart se convierten en enlaces a su declaración, incluso si el archivo de destino no está en la lista filtrada. Los enlaces se pueden activar con clic o, al seleccionarlos, con Retorno. **Volver** o Comando + [ recupera el archivo y la posición de lectura anteriores. La búsqueda es acotada y heurística: omite destinos ambiguos, no reconoce todas las construcciones dinámicas o multilínea y no modifica archivos. Las declaraciones del índice y del working tree se vuelven a consultar para evitar enlaces obsoletos; la caché de revisiones inmutables se separa por repositorio. Los detalles y límites están en el [resumen de continuidad](docs/13-resumen-del-proyecto-y-continuidad.md).

Ambos documentos sincronizan el desplazamiento horizontal y vertical. El texto modificado dentro de cada línea tiene un fondo más intenso: rojo en lo eliminado y verde en lo agregado. Las líneas idénticas no se marcan; el resaltado conserva el formato de código y tu selección manual. **Modificaciones** indica cuántas líneas faltan, desde el borde inferior visible, para llegar al próximo cambio al bajar. El mapa vertical está detrás del indicador de scroll de cada columna: rojo indica líneas eliminadas y verde, agregadas. Arrastra el indicador o usa anterior/siguiente para navegar.

Las preferencias guardan distribución de paneles, terminal, registro y pestañas; al reiniciar no se restauran procesos vivos. Quitar un registro conserva los archivos del repositorio. Los remotos de otros proveedores mantienen disponibles las funciones locales; la integración de red del MVP se limita a Bitbucket Cloud.

## Validación y límites

El [estado del MVP](docs/11-estado-mvp.md) registra pruebas reales, trazabilidad y pendientes. Las pruebas Git usan carpetas temporales, remoto bare y dos clones, sin modificar repositorios personales. La última corrección de navegación, en el [PR #23](https://github.com/efby/EFBY-GIT-DESK/pull/23), pasó localmente **102 pruebas registradas en 22 suites: 100 aprobadas y 2 optativas omitidas**. El bundle de desarrollo compiló y superó la verificación de firma ad hoc antes del push. Estos resultados corresponden a esa rama; no prueban un nuevo DMG distribuido.

Pruebas optativas:

```sh
EFBY_BENCHMARK=1 EFBY_BENCHMARK_REPORT="$PWD/.build/benchmark.json" bash scripts/test.sh --filter PerformanceTests
EFBY_KEYCHAIN_TEST=1 bash scripts/test.sh --filter KeychainTests
```

La prueba de Keychain crea y elimina únicamente un valor ficticio con identificador aleatorio. Nunca contiene tokens reales. El benchmark genera 100.000 commits y elimina su fixture al terminar.

El terminal implementa interacción y secuencias VT básicas; no ofrece aún compatibilidad completa con aplicaciones de pantalla completa ni todos los atributos ANSI. Los worktrees vinculados, clones shallow/parciales y submódulos abiertos individualmente se limitan a inspección; bare y sparse checkout se rechazan con diagnóstico. El diff textual tiene un límite visible de 2 MB y conserva el inventario de archivos.

La conexión contra una cuenta real de Bitbucket, el acceso del helper a Keychain dentro de un paquete de distribución, la aceptación manual con VoiceOver, la instalación del DMG descargado en otro Mac y el runtime macOS 14/Intel siguen pendientes. La firma Developer ID, notarización y publicación en Releases se verificaron en CI para versiones anteriores; eso no verifica el DMG de esta rama. Esta versión se entrega para pruebas de desarrollo y todavía no cumple el criterio de release de H6.

- [Estado consolidado y decisiones actuales](docs/13-resumen-del-proyecto-y-continuidad.md)
- [Documentación](docs/README.md)
- [Plan de desarrollo](docs/07-plan-de-desarrollo.md)
- [Decisiones adoptadas](docs/11-estado-mvp.md)
- [Instrucciones del proyecto](AGENTS.md)

Repositorio de desarrollo: [efby/EFBY-GIT-DESK](https://github.com/efby/EFBY-GIT-DESK). Las claves de autenticación permanecen fuera del repositorio y nunca se versionan.

El icono reutiliza el logotipo y el diseño de EFBY_POSTMAN, con la etiqueta inferior **#GitDesk**. El vector está en `Resources/Brand/EfbyLogo.ai`; `scripts/generate-icon.sh` regenera el PNG y el icono macOS `.icns`, que el empaquetado incorpora al bundle.

El selector **Formato de código** detecta Python, JavaScript/JSX, TypeScript/TSX, Dart, Swift, Java/Kotlin, C/C++, C#, Go, Rust, Ruby, Shell, SQL, JSON, YAML/TOML, HTML/XML, CSS y Markdown. Permite elegir manualmente el lenguaje o texto plano. El resaltado léxico distingue cadenas, comentarios, palabras clave, números y llamadas; los fondos y signos de diff se conservan. Es una ayuda de lectura básica, sin ejecutar código ni ofrecer análisis de compilador.


## Instalador DMG

Generar el paquete local universal con `scripts/build-dmg.sh --universal`. El instalador se guarda en `dist/EFBY-Git-Desk-dev.dmg`. El flujo firmado/notarizado y los secretos de GitHub están descritos en [DMG y GitHub Actions](docs/12-dmg-y-github-actions.md). Al fusionar un pull request hacia `main` desde una rama del repositorio se genera un DMG universal firmado y notarizado y se publica en Releases con tag de versión, checksum y notas automáticas. Abrir o actualizar un PR no genera el paquete. Trabajar en ramas y PR; no hacer push directo a `main`. Los demás pushes, incluidos tags, no generan DMG. También se conserva la ejecución manual de Release DMG.
