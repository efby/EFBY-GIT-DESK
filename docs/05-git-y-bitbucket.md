# 05. Contrato de integración con Git y Bitbucket

Estado: especificación de diseño; fuentes consultadas el **6 de octubre de 2026**. EfbyGitDesk es el nombre confirmado por el usuario. Alcance confirmado: **macOS y Bitbucket Cloud**, incluida la edición del mensaje del último commit publicado. Data Center queda fuera de v1 y requeriría otro adaptador, URL base, autenticación y pruebas.

## 1. Separación de responsabilidades

`GitRepositoryPort` ejecuta operaciones sobre el repositorio local con el Git instalado en el sistema. `HostingProviderPort` consulta el catálogo remoto. `SecretStorePort` conserva referencias a secretos. `ProcessRunner`/`GitCommandRunner` son detalles internos del adaptador Git para procesos y cancelación. Dominio y casos de uso no conocen SwiftUI/AppKit, REST ni comandos.

Git sigue siendo la fuente de verdad para ramas, objetos, índice y working tree. Bitbucket aporta workspaces, repositorios, permisos y URLs de clonación. SSH autentica el **transporte Git**; no proporciona una sesión REST. Un perfil puede tener Git por SSH y catálogo REST por API token. Sin token REST, se puede abrir un repositorio local o clonar una URL conocida mediante SSH; el catálogo remoto queda deshabilitado.

## 2. Autenticación Cloud y catálogo

| Modalidad | Uso Git | Uso REST | Datos solicitados |
|---|---|---|---|
| API token personal con scopes | HTTPS; usuario Bitbucket exacto o `x-bitbucket-api-token-auth`; token por canal de credenciales | Basic: correo Atlassian como usuario y token como contraseña | Correo Atlassian, token; usuario Bitbucket opcional para Git |
| SSH personal | URL `git@bitbucket.org:workspace/repositorio.git`, agente o clave seleccionada | Requiere credencial REST adicional | Referencia a agente/configuración/archivo de clave |
| Conexión heredada | Configuración Git y SSH existente, después de confiar en ella | No se infiere un token REST | Ruta del repositorio y remoto seleccionado |

REST y Git usan identificadores distintos en el modo API token. Las contraseñas de cuenta no sustituyen al token. [Autenticación REST](https://developer.atlassian.com/cloud/bitbucket/rest/intro/), [API tokens con Git](https://support.atlassian.com/bitbucket-cloud/docs/using-api-tokens/).

No ofrecer App passwords: el changelog oficial establece su retirada final el **28 de julio de 2026**, tras brownouts desde el 9 de junio. Algunas páginas de soporte conservan el calendario anterior; usar el changelog al resolver esa discrepancia. [Changelog Cloud](https://developer.atlassian.com/cloud/bitbucket/changelog/).

OAuth queda fuera de v1. Repository, project y workspace access tokens son tipos diferentes ligados al recurso, con permisos y disponibilidad propios; no tratarlos como API tokens personales. Su soporte se añade como modalidad explícita posterior. [Tipos de access token](https://support.atlassian.com/bitbucket-cloud/docs/access-tokens/).

Contrato inicial del catálogo, base `https://api.bitbucket.org/2.0`:

| Operación | Endpoint GET | Scope API token |
|---|---|---|
| Workspaces accesibles al usuario | `/user/workspaces` | `read:workspace:bitbucket` |
| Repositorios visibles en un workspace | `/repositories/{workspace}` | `read:repository:bitbucket` |
| Metadatos y enlaces de un repositorio | `/repositories/{workspace}/{repo_slug}` | `read:repository:bitbucket` |

El MVP utiliza el listado paginado de repositorios del workspace, sin inferir permiso de push de su presencia en el catálogo; también permite agregar una URL manualmente. Estas rutas se contrastaron con la referencia oficial durante la implementación, pero todavía no con credenciales reales. No depender de antiguos listados globales retirados en 2026. [Workspaces REST](https://developer.atlassian.com/cloud/bitbucket/rest/api-group-workspaces/), [Repositorios REST](https://developer.atlassian.com/cloud/bitbucket/rest/api-group-repositories/), [Retirada de APIs anteriores](https://community.developer.atlassian.com/t/bitbucket-cloud-announcing-end-of-life-for-cross-workspace-apis-timeline-next-steps-and-instructions-for-connect-apps/99972).

Para clone/fetch: `read:repository:bitbucket`. Para push: añadir `write:repository:bitbucket`; write no implica read. Añadir lectura de workspace solo para descubrimiento. No pedir administración, borrado, pipelines ni pull requests para este alcance. [Scopes API token](https://support.atlassian.com/bitbucket-cloud/docs/api-token-permissions/).

Consumir `values` y seguir `next` como URL opaca validada; no fabricar números de página ni asumir `size`. Cachear por cuenta/workspace y cargar bajo demanda. Ante 429, respetar `Retry-After` cuando exista y aplicar espera exponencial con variación y límite; esta política de reintentos es una decisión de EfbyGitDesk. No asumir una cuota fija ni que todos los tipos de token reciben las mismas cabeceras. Reintentar automáticamente solo lecturas idempotentes. [Paginación](https://developer.atlassian.com/cloud/bitbucket/rest/intro/#pagination), [Límites API](https://support.atlassian.com/bitbucket-cloud/docs/api-request-limits/).

## 3. Contrato del adaptador Git

Ejecutar Git mediante `Process.executableURL` y `Process.arguments`, sin intérprete de shell, con directorio explícito, límite de salida y timeout. Los comandos ilustrativos siguientes son contratos de argumentos; no concatenar texto del usuario en una línea de shell. Resolver commits a OID completo validado antes de operar; separar rutas con `--` y usar pathspec literal. Todas las lecturas de historial/objetos usan `--no-replace-objects` para corresponder al OID original; replacement refs quedan fuera de v1.

| Necesidad | Consulta/operación de referencia |
|---|---|
| Detectar repositorio | `rev-parse --is-inside-work-tree`; `--is-bare-repository`; `--is-shallow-repository` |
| Identificar almacenamiento | `rev-parse --absolute-git-dir`; `rev-parse --path-format=absolute --git-common-dir`; `--show-toplevel` para repositorios no bare |
| Algoritmo de objetos | `rev-parse --show-object-format` |
| Estado | `status --porcelain=v2 -z --branch` |
| Ramas/referencias | `for-each-ref` con formato estructurado |
| Comprobar lectura remota | `ls-remote` del destino validado; no fetch ni push |
| Pull v1 | Fetch explícito y actualización fast-forward; si diverge, informar y bloquear integración automática |
| Push v1 | `push --porcelain` con un destino y refspec explícito `OID:refs/heads/rama` |

No asumir que `.git` es un directorio: worktrees pueden compartir almacenamiento y usar un archivo de enlace. La identidad del working tree y la del directorio común son diferentes. No asumir OID de 40 caracteres: usar algoritmo detectado y capacidades del Git disponible. [rev-parse](https://git-scm.com/docs/git-rev-parse).

V1 detecta worktrees para identificar el repositorio y evitar cambiar/eliminar ramas en uso. Gestionar worktrees y mutar un working tree vinculado queda pendiente de una decisión y pruebas específicas; abrirlo informa esa limitación.

Parsear status como bytes separados por NUL, atendiendo registros ordinarios, renombres/copia —con segunda ruta—, conflictos, untracked y encabezados desconocidos. Conservar rutas originales, incluso espacios, tabulaciones y saltos de línea; la representación visible es otra capa. [status](https://git-scm.com/docs/git-status).

El grafo carga páginas de OIDs con orden topológico sobre las puntas capturadas al iniciar la consulta; un refresh inicia otra generación. Metadatos de log usan campos NUL y una codificación de visualización explícita. Para cuerpo completo o contenido que no pueda interpretarse, usar `cat-file --batch` con longitud declarada y presentar sustituciones de caracteres sin modificar el objeto. Cancelar resultados de generaciones viejas. [log](https://git-scm.com/docs/git-log), [rev-list](https://git-scm.com/docs/git-rev-list), [cat-file](https://git-scm.com/docs/git-cat-file).

## 4. Comparación entre exactamente dos commits

`CompareCommits(baseOid, targetOid)` exige dos OIDs distintos de tipo commit. A es base y B destino; la UI muestra ambos y permite invertirlos. El resultado es el cambio entre **los dos árboles finales**, aunque los commits no sean consecutivos ni compartan una rama. Referencia: `diff --no-ext-diff --no-textconv --name-status -z A B --`; cargar parches por archivo bajo demanda. No usar `A...B`, que cambia la base al ancestro común. [diff](https://git-scm.com/docs/git-diff).

La lista cubre agregados, eliminados, modificaciones, renombres/copia cuando se detecten, cambios de modo, enlaces y submódulos. La detección de rename es heurística; mostrar puntuación cuando corresponda. Binarios muestran metadatos; archivos grandes tienen límite y aviso de truncado. No ejecutar conversores externos para mejorar la vista.

Seleccionar un solo commit muestra sus cambios respecto de su primer padre. Para merges, indicar padre elegido y permitir otro; para el primer commit, comparar con árbol vacío obtenido por Git. Esto es otro caso de uso, separado de la selección de dos. Working tree e índice tienen vistas propias: cambios sin stage y con stage, más untracked; no presentarlos como comparación entre commits.

Si faltan objetos por shallow/partial clone, mostrar «No hay objetos suficientes» y ofrecer fetch explícito después de explicar qué se descargará. No sustituir silenciosamente un commit por otro. Bare queda fuera del flujo de trabajo v1 y se informa al abrirlo.

## 5. Editar el mensaje del último commit publicado

Un push no tiene mensaje propio. La función solicitada se denomina **Editar mensaje del último commit**. Publicar la edición crea otro OID y reescribe la punta remota; conservar árbol, padres y autor, con nuevo committer/fecha y nueva firma si corresponde.

1. Obtener bloqueo de operación del repositorio; bloquear nuevas mutaciones desde EfbyGitDesk y pausar peticiones de escritura del terminal gestionado. El bloqueo no impide que otra aplicación cambie el repositorio.
2. Exigir rama local, HEAD válido y ausencia de merge/rebase/cherry-pick/conflictos. Bloquear si hay cambios staged en v1. Resolver un único destino de push, hacer fetch previo y consultar después su punta con `ls-remote`. Capturar HEAD, padres, árbol, entradas staged del índice y ese destino/punta remota. Si existen varios push URLs, el usuario elige uno; no publicar a todos implícitamente. El destino de fetch puede diferir del de push: la lease se basa siempre en el destino de publicación fijado.
3. Para editar el commit ya publicado, exigir `HEAD == puntaRemotaEsperada`. Si hay commits locales posteriores o el remoto avanzó, bloquear esta función v1. Mostrar rama, OID y efecto de reescritura; solicitar confirmación específica.
4. Crear referencia local de recuperación `refs/gitdesk/backups/{operationId}` al HEAD original. Revalidar HEAD/rama/índice antes de escribir.
5. Ejecutar `commit --amend --only --file=-`, sin rutas, enviando el mensaje por stdin. `--only` evita incorporar cambios staged. La política de hooks y firma del documento 06 se aplica. Verificar árbol/padres/autor y contenido staged del índice —no igualdad byte a byte de sus metadatos de caché—; una diferencia inesperada produce fallo visible, sin publicación. [commit](https://git-scm.com/docs/git-commit).
6. Revalidar que HEAD sigue siendo el commit nuevo y que rama/destino coinciden con el plan. Publicar solo ese OID al destino capturado con `--force-with-lease=refs/heads/rama:OIDremotoEsperado` y refspec explícito. No usar `--force` ni una lease sin OID esperado. Las restricciones del servidor siguen aplicándose. [push](https://git-scm.com/docs/git-push).
7. Verificar la punta remota. Si hay timeout, consultar antes de reintentar: puede haber llegado al servidor. Si la lease falla, conservar commit nuevo y respaldo, refrescar y explicar la divergencia. No hacer reset automático ni rollback remoto.

La secuencia local/remota no es una transacción atómica. Registrar fases `prepared`, `amended`, `publishing`, `verified` o `needs-recovery` sin secretos. La recuperación requiere revalidar el estado actual y escoger una acción explícita. El respaldo se crea con `update-ref` y se conserva hasta que la operación sea verificable y la política de retención permita retirarlo. [update-ref](https://git-scm.com/docs/git-update-ref).

## 6. Errores y validación de integración

Normalizar errores: autenticación rechazada/expirada, scope insuficiente, host desconocido, permiso de rama, remoto avanzado, conflictos, Git ausente/incompatible, lock externo, cancelación y red. `ls-remote` valida acceso de lectura a un repositorio; no demuestra permiso de push. [ls-remote](https://git-scm.com/docs/git-ls-remote).

Antes de liberar: probar cuenta Cloud con permisos read y write separados, token expirado, SSH personal y clave de solo lectura, remote push URL diferente, lease rechazada, push recibido con timeout, cambios externos, worktree enlazado, SHA-256 local y shallow incompleto. Los proveedores remotos pueden no admitir todos los formatos de objetos locales; diagnosticar capacidad sin prometer soporte Cloud SHA-256. No se han ejecutado estas pruebas en esta fase documental.

## Fuentes primarias y vigencia

Consultadas el 6 de octubre de 2026: manuales [Git](https://git-scm.com/docs), referencia [REST Bitbucket Cloud](https://developer.atlassian.com/cloud/bitbucket/rest/), [changelog Cloud](https://developer.atlassian.com/cloud/bitbucket/changelog/) y soporte [API tokens](https://support.atlassian.com/bitbucket-cloud/docs/api-tokens/). Las políticas remotas se vuelven a verificar antes de implementación y liberación; los enlaces junto a cada contrato identifican su fuente específica.
