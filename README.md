# EfbyGitDesk

MVP de desarrollo de una aplicación nativa macOS para trabajar con Git local y Bitbucket Cloud. SwiftUI/AppKit, Swift 6 y Clean Architecture; sin dependencias de terceros.

Incluye repositorios en pestañas, favoritos/grupos, confianza persistida, ramas, stage/unstage por archivo, commits, historial paginado con grafo, SHA completo y comparación directa A→B. También ofrece fetch, pull fast-forward, push con destino explícito, edición del mensaje de HEAD con recuperación y lease, y terminal PTY por repositorio.

## Compilar y abrir

Requisitos: Xcode con Swift 6.2 o posterior y Git 2.40 o posterior. El entorno verificado utiliza Swift 6.4, Git 2.51 y macOS 26.6.2 en arm64. El mínimo de compilación es macOS 14; su ejecución e Intel están pendientes de validar.

```sh
bash scripts/test.sh
bash scripts/build-app.sh
open dist/EfbyGitDesk.app
```

Para un paquete optimizado: `bash scripts/build-app.sh release`. El paquete incluye el helper de credenciales y lleva firma ad hoc de desarrollo. No es un release con Developer ID ni notarización. Abrir `Package.swift` en Xcode permite desarrollar los targets.

## Uso inicial

1. Abre una carpeta Git. Comienza en inspección segura: historial y objetos, sin terminal, red ni cambios en archivos.
2. Revisa la carpeta y concede confianza para habilitar operaciones locales. Las credenciales y la confianza son independientes.
3. Selecciona **Pendientes** para preparar archivos y **Preparados** para revisar el índice y crear el commit. Las ramas ofrecen acciones en su menú contextual.
4. Selecciona un commit para revisar sus diferencias; selecciona dos para comparar sus árboles. El tercero conserva el par. La dirección es siempre del commit inferior al superior en el historial, independientemente del orden de selección. Puedes copiar el SHA completo.
5. Para Bitbucket, usa SSH/credenciales heredadas o agrega un API token en **Conexiones**. El catálogo necesita lectura de workspace y repositorios; publicar requiere permiso de escritura. El token se guarda en Keychain.
6. Clona en una carpeta nueva. La aplicación realiza `--no-checkout` y solicita confianza antes de materializar archivos.
7. **Editar mensaje de HEAD** presenta un plan que caduca a los 60 segundos. Publicarlo exige que HEAD coincida con la punta remota y utiliza un lease exacto. La referencia de recuperación se conserva incluso si el envío falla.
8. **Terminal** abre el panel; **Nueva sesión** inicia una shell. Ocultarlo conserva la sesión. Cerrar una sesión activa presenta confirmación. Los cambios se consultan al volver al foco y cada cuatro segundos.

El repositorio ocupa todo el espacio disponible incluso sin seleccionar commits. Selecciona un commit (o dos para comparar A→B) y haz clic en un archivo para abrir su diff. El compare se abre en una ventana independiente a pantalla completa, conservando la vista del repositorio. **Volver al repositorio**, `Esc` o cerrar la ventana recuperan la vista anterior; cambiar la selección de commits cierra el visor.

Las preferencias guardan distribución de paneles, terminal, registro y pestañas; al reiniciar no se restauran procesos vivos. Quitar un registro conserva los archivos del repositorio. Los remotos de otros proveedores mantienen disponibles las funciones locales; la integración de red del MVP se limita a Bitbucket Cloud.

## Validación y límites

El [estado del MVP](docs/11-estado-mvp.md) registra pruebas reales, trazabilidad y pendientes. Las pruebas Git usan carpetas temporales, remoto bare y dos clones, sin modificar repositorios personales.

Pruebas optativas:

```sh
EFBY_BENCHMARK=1 EFBY_BENCHMARK_REPORT="$PWD/.build/benchmark.json" bash scripts/test.sh --filter PerformanceTests
EFBY_KEYCHAIN_TEST=1 bash scripts/test.sh --filter KeychainTests
```

La prueba de Keychain crea y elimina únicamente un valor ficticio con identificador aleatorio. Nunca contiene tokens reales. El benchmark genera 100.000 commits y elimina su fixture al terminar.

El terminal implementa interacción y secuencias VT básicas; no ofrece aún compatibilidad completa con aplicaciones de pantalla completa ni todos los atributos ANSI. Los worktrees vinculados, clones shallow/parciales y submódulos abiertos individualmente se limitan a inspección; bare y sparse checkout se rechazan con diagnóstico. El diff textual tiene un límite visible de 2 MB y conserva el inventario de archivos.

La conexión contra una cuenta real de Bitbucket, el acceso del helper a Keychain dentro de un paquete de distribución, la aceptación con VoiceOver, macOS 14/Intel y la notarización siguen pendientes. Esta versión se entrega para pruebas de desarrollo; todavía no cumple el criterio de release de H6.

- [Documentación](docs/README.md)
- [Plan de desarrollo](docs/07-plan-de-desarrollo.md)
- [Decisiones adoptadas](docs/11-estado-mvp.md)
- [Instrucciones del proyecto](AGENTS.md)

Repositorio de desarrollo: [efby/EFBY-GIT-DESK](https://github.com/efby/EFBY-GIT-DESK). Las claves de autenticación permanecen fuera del repositorio y nunca se versionan.

El icono reutiliza el logotipo y el diseño de EFBY_POSTMAN, con la etiqueta inferior **#GitDesk**. El vector está en `Resources/Brand/EfbyLogo.ai`; `scripts/generate-icon.sh` regenera el PNG y el icono macOS `.icns`, que el empaquetado incorpora al bundle.

El selector **Formato de código** detecta Python, JavaScript/JSX, TypeScript/TSX, Swift, Java/Kotlin, C/C++, C#, Go, Rust, Ruby, Shell, SQL, JSON, YAML/TOML, HTML/XML, CSS y Markdown. Permite elegir manualmente el lenguaje o texto plano. El resaltado léxico distingue cadenas, comentarios, palabras clave, números y llamadas; los fondos y signos de diff se conservan. Es una ayuda de lectura básica, sin ejecutar código ni ofrecer análisis de compilador.
