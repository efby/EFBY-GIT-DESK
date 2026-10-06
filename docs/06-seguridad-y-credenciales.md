# 06. Seguridad y manejo de credenciales

Estado: requisitos de implementación y pruebas, consultados el **6 de octubre de 2026**. Complementa [05. Git y Bitbucket](05-git-y-bitbucket.md). Alcance confirmado: macOS y Bitbucket Cloud; propuesta técnica nativa Swift/SwiftUI, AppKit y SwiftTerm.

## 1. Límites de confianza

Los adaptadores nativos albergan Git, REST, PTY y Keychain; la UI recibe DTOs y capacidades acotadas. Separar módulos Swift con dependencias hacia dominio, aislar estado de operaciones/credenciales mediante actores y actualizar UI en `MainActor`. Los actores coordinan estado dentro de la aplicación; no aíslan procesos del sistema ni excluyen aplicaciones externas. [Concurrencia Swift](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html).

No incorporar webviews para renderizar diffs ni exponer una función genérica de ejecutar procesos a vistas, enlaces o contenidos de repositorio. Si se introduce un helper/XPC posteriormente, validar esquema, identidad del cliente y autorización de cada solicitud. Abrir enlaces externos solo tras validar protocolo y destino.

Nombres de ramas, commits, rutas, respuestas del servidor y texto del terminal son datos no confiables. Renderizarlos como texto; nunca convertirlos en HTML, comandos, atributos ni instrucciones de la aplicación. Una etiqueta del mockup no habilita automáticamente una capacidad nueva.

## 2. Secretos y almacenamiento

| Dato | Persistencia permitida |
|---|---|
| API token | macOS Keychain, con acceso restringido a la aplicación |
| Clave SSH privada | Archivo existente referenciado; EfbyGitDesk no importa su contenido a SQLite |
| Passphrase SSH | Agente/almacén autorizado; por defecto solo durante la solicitud |
| Cuenta, host y referencia de credencial | SQLite; sin secretos |
| Conexión heredada | Identificador/configuración necesaria; no copiar secretos del helper |

`SecretStorePort` encapsula Keychain Services. Guardar tokens como ítems de contraseña con service propio y account identificable, mediante `SecItemAdd`; recuperar con `SecItemCopyMatching`, actualizar y eliminar mediante sus APIs. Restringir acceso a la identidad firmada de EfbyGitDesk y no compartir grupos de acceso sin necesidad. Si Keychain está bloqueado, denegado o no disponible, explicar el fallo y ofrecer sesión en memoria; nunca degradar a SQLite/plist con texto plano. El almacén protege secretos en reposo, no frente a código comprometido autorizado a leerlos. [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [Gestión de secretos con Keychain](https://developer.apple.com/documentation/security/using-the-keychain-to-manage-user-secrets).

Nunca colocar token o passphrase en URL remota, argumentos del proceso, configuración Git, archivos temporales ordinarios, logs, telemetría, portapapeles ni historial del terminal. El campo de token no permite copia automática. La aplicación almacena solo lo que el usuario elige recordar y elimina su referencia local al desconectar; revocar en Atlassian es una acción distinta. Gestionar expiración con una solicitud de reemplazo, sin inventar renovación automática.

Para HTTPS gestionado, usar un programa askpass/helper propio, firmado y fijo, con canal local autenticado de una sola operación, vencimiento breve y acceso restringido al usuario. En modo token gestionado, aislar los credential helpers heredados mediante configuración solo de esa invocación, para evitar usar o almacenar la credencial en otro helper; el modo heredado mantiene sus auxiliares. No modificar configuración global. Pasar la referencia al canal, nunca el secreto, por entorno. El helper entrega la respuesta a Git por stdout **dedicado**, que el sistema de logs no captura. Eliminar canal y buffer al completar/cancelar; no prometer borrado perfecto de memoria. La UI no recibe secretos almacenados ni resultados del helper; el token introducido en el formulario se transfiere al almacén y se vacía el campo. El PTY no recibe el token. Git admite `GIT_ASKPASS`, cuya respuesta se lee de stdout. [Credenciales Git](https://git-scm.com/docs/gitcredentials).

## 3. Conexión heredada y destinos

Heredar significa usar el mecanismo ya configurado para el remoto escogido: credential helper, SSH agent, host alias, proxy y contexto de usuario. No leer/exponer una contraseña para probarla, no copiar claves y no cambiar archivos globales. Identidad de commit (`user.name`, `user.email`) no equivale a autenticación. [Identidad de commits](https://git-scm.com/docs/git-commit#_commit_information).

Una aplicación abierta desde el escritorio puede no recibir el mismo `PATH` o `SSH_AUTH_SOCK` que un terminal. Diagnosticar Git/agente disponible y pedir selección/configuración cuando falte; no ejecutar perfiles de shell para importar indiscriminadamente su entorno. Helpers y `core.sshCommand` pueden ejecutar código: revisar y autorizar esa confianza antes de usarlos. El modo heredado no garantiza seguridad frente a configuración maliciosa.

Cloud gestionado admite REST HTTPS a `api.bitbucket.org` y Git HTTPS/SSH al destino Bitbucket validado. Rechazar userinfo con secretos, protocolos como `ext::`, destinos locales involuntarios y saltos de origen que recibirían Authorization. Validar host, esquema, puerto y ruta tras resolver aliases/rewrite; un host alias heredado requiere revisar su destino. No enviar credenciales REST a URLs de avatar, enlaces o redirecciones. Seguir `next` solo tras validación de origen/base API; todo cambio de host falla cerrado. No desactivar validación TLS para superar un error de certificado.

Mantener `known_hosts` y verificación de host SSH. Ante host nuevo, mostrar huella y mecanismo para contrastarla con la publicación oficial; ante cambio, detener y explicar. No usar `StrictHostKeyChecking=no` ni borrar entradas automáticamente. Añadir claves públicas a Bitbucket es distinto de confiar en el host. [Configuración SSH y claves del host](https://support.atlassian.com/bitbucket-cloud/docs/configure-ssh-and-two-step-verification/).

## 4. Repositorios, scripts y operaciones

Git no es un sandbox. Una operación aparentemente de lectura puede invocar fsmonitor, filtros o helpers configurados. Abrir una carpeta nueva activa un estado «Confianza pendiente». Permitir únicamente lectura endurecida de objetos/historial: sin extdiff, textconv, verificación de firmas que invoque programas, pager, fsmonitor ni red. Desactivar lazy fetch con `GIT_NO_LAZY_FETCH=1` y sustitución de objetos con `--no-replace-objects`; verificar esas capacidades del Git disponible antes de admitir lectura restringida. No ejecutar status/diff del working tree, checkout, hooks, filtros o terminal hasta autorizar la confianza necesaria. No considerar esta lista una garantía de sandbox frente a repositorios hostiles. [Configuración Git](https://git-scm.com/docs/git-config), [Entorno y seguridad Git](https://git-scm.com/docs/git).

El adaptador aplica política por operación; en consultas de diff usa `--no-ext-diff --no-textconv`, ejecuta sin shell, limita protocolos y no añade `safe.directory=*`. Para clonar, transferir primero con `--no-checkout`, hooks de la aplicación vacíos y transporte autorizado; revisar la confianza antes del checkout, que puede ejecutar filtros. Submódulos y LFS no se descargan recursivamente por defecto; si hacen falta, explicar que requieren otros destinos/programas y habilitarlos explícitamente.

Después de confiar, ofrecer política visible de hooks y firma. Respetar las validaciones requeridas por el proyecto; no usar `--no-verify` silenciosamente para lograr un commit/push. La modificación de mensaje debe firmar el nuevo commit si la política lo exige; la firma anterior no se transfiere. Si falta herramienta/clave o un hook falla, detener. Un hook autorizado puede modificar el working tree o índice; volver a comprobar invariantes antes de publicar. [Hooks de Git](https://git-scm.com/docs/githooks), [Firma de commits](https://git-scm.com/docs/git-commit#Documentation/git-commit.txt--Sltkey-idgt).

Todas las mutaciones gestionadas usan bloqueo por repositorio; operaciones que cambian referencias compartidas se coordinan también por git common directory. Revalidar HEAD, índice, rama y destino al confirmar una acción sensible. Las aplicaciones externas conservan capacidad de escritura y pueden generar carreras; no prometer exclusión total. Nunca borrar archivos `.lock` encontrados sin verificar su origen y ausencia de proceso activo.

## 5. Terminal inferior

La candidata SwiftTerm se evaluará mediante una prueba técnica de integración con AppKit, PTY real y shell del usuario; aún no está instalada ni fijada. El terminal se abre por acción expresa y muestra repositorio/ubicación activa. Ejecuta comandos arbitrarios con los permisos efectivos del proceso; los actores Swift **no** constituyen aislamiento del sistema operativo. No prometer una shell restringida por estar integrada en una ventana.

La propuesta de distribución v1 es Developer ID con firma/notarización; definir entitlements y hardened runtime en el diseño de distribución. Si se adopta App Sandbox, hacer una prueba específica de repositorios, Git externo, agentes SSH y PTY; no presuponer que notarización implica sandbox. App Sandbox limita acceso mediante entitlements y es obligatorio para Mac App Store. [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox).

No inyectar comandos, tokens ni mensajes de commit al terminal. Pegar texto multilínea requiere vista previa; validar enlaces y evitar que secuencias de terminal cambien el portapapeles, escriban archivos o disparen acciones nativas sin autorización. Durante preparación y ejecución de amend publicado, pausar nueva entrada al PTY gestionado, conservando salida y posibilidad de interrupción; liberar la pausa al completar/cancelar/fallar. Esto no detiene hijos activos ni aplicaciones externas. Refrescar Git ante cambios y foco, sin asumir que todos los comandos pueden clasificarse o que sus hijos se detienen con el PTY. Avisar cuando el estado cambie externamente y exigir nueva revisión del plan.

El historial y scrollback pertenecen a la sesión y no se exportan por defecto. El usuario puede ejecutar comandos que impriman secretos: redacción automática no es garantía. No capturar salida PTY en telemetría ni informes de fallos. La política de cancelación termina procesos gestionados y comprueba estado; matar un proceso no revierte operaciones ya aplicadas.

## 6. Registro, recuperación y verificación

Registrar identificador de operación, tiempos, resultado, fase y códigos normalizados. Sanitizar host/ruta cuando un diagnóstico pudiera revelar información personal; excluir cabeceras Authorization, entorno, cuerpos sensibles, patches, contenido del terminal y salida cruda de helpers. Los errores de autenticación muestran causa accionable sin repetir la credencial.

Conservar respaldo de OID antes de reescribir y registrar si la publicación fue verificada. Restablecer una referencia exige comprobar que su valor actual sigue siendo el esperado; el usuario revisa la recuperación. No combinar fallo de push con reset automático que pueda descartar cambios concurrentes.

Pruebas de salida obligatorias: cuenta/token ausente o expirado; Keychain bloqueado/denegado y actualización de aplicación firmada; secreto en URL/log redirigido; `next` a host ajeno; host SSH cambiado; configuración Git con helper/filtro/hook malicioso; nombres/rutas con controles; secuencia terminal que intenta copiar o abrir enlaces; terminal que imprime secreto; dos worktrees y mutación externa durante amend/push. La suite usa secretos ficticios y repositorios temporales. Esta documentación define el requisito; no certifica que exista una implementación segura.

## Fuentes primarias y vigencia

Consultadas el 6 de octubre de 2026: [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [concurrencia Swift](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html), [configuración Git](https://git-scm.com/docs/git-config) y [SSH Bitbucket Cloud](https://support.atlassian.com/bitbucket-cloud/docs/configure-ssh-and-two-step-verification/). Las políticas de EfbyGitDesk son requisitos propios; las capacidades de plataforma se atribuyen a estas fuentes.
