# Dominio, datos y contratos

Versión 0.1 · 6 de octubre de 2026 · Diseño para implementación.

## 1. Lenguaje común

Un **repositorio local** es una carpeta de trabajo y su repositorio Git asociado. Un **worktree** puede compartir objetos y referencias con otros worktrees. Un **grupo** es organización local de la aplicación; un **workspace de Bitbucket** es un contenedor remoto de Bitbucket. No son equivalentes.

Un **commit** identifica una instantánea, padres y metadatos. Un **push** transfiere objetos y actualiza referencias remotas; no tiene un mensaje de commit propio editable. **Índice/staging** es el contenido preparado para el próximo commit. **Working tree** son los archivos actuales. **Upstream** es la relación de seguimiento de una rama.

Un **perfil de conexión** describe transporte y/o acceso API. **Heredado** significa usar mecanismos ya configurados para Git sin copiar sus secretos. **A** es la instantánea base de una comparación y **B** la instantánea destino. El orden se mantiene visible: A es el commit inferior y B el superior del historial, independientemente del orden de selección.

## 2. Entidades y valores

| Modelo | Campos principales | Invariantes |
|---|---|---|
| RepositoryRegistration | id, canonicalPath, gitDir, commonGitDir, displayName, groupId?, favorite, lastOpenedAt, trustState | Ruta validada por servicio; quitar registro no elimina archivos; confianza explícita |
| LocalRepositorySnapshot | repositoryId, generation, headOid?, symbolicHead?, state, upstream?, ahead?, behind?, capturedAt | Estado remoto incluye instante de última consulta; contador desconocido no es cero |
| Remote | name, fetchUrlSanitized, pushUrlSanitized, provider?, profileId? | Fetch y push pueden apuntar a destinos diferentes |
| Branch | fullRef, displayName, oid, local/remote, upstream?, checkedOutWorktree? | Nombre validado con Git; no borrar rama en uso |
| Commit | oid, parentOids[], treeOid, subject, body, author, committer, authoredAt, committedAt, signatureStatus? | OID completo; no longitud fija de 40 caracteres |
| ComparisonPair | baseOid, targetOid | Exactamente dos commits distintos, resueltos y pertenecientes al contexto abierto |
| ChangedFile | pathId, oldPath?, newPath?, status, oldMode?, newMode?, binary, additions?, deletions? | PathId opaco; ruta original preservada, no se reconstruye desde texto visible |
| ConnectionProfile | id, providerKind: bitbucketCloud, gitTransport, apiAuthMode, username?, accountEmail?, secretRef?, capabilities | SSH no concede capacidad API; secretos separados de DTO |
| Operation | id, repositoryId?, kind, status, start/end, phase, safeError?, recoveryRef? | No repetir una mutación inconclusa automáticamente |
| TerminalSession | id, repositoryId, initialCwd, shellId, dimensions, status | Sesión vinculada a una ventana/repositorio autorizado |

`ObjectId`, `RepositoryId`, `FullRef`, `OperationId` y `PathId` son tipos distinguibles. Los bytes de nombres de archivo que no tengan representación Unicode válida se conservan en el adaptador y se muestran escapados; la interfaz opera mediante pathId, nunca reinterpretando el nombre renderizado como una ruta. Los DTO entre actores son valores Sendable; las referencias a NSView y Process quedan en sus adaptadores.

## 3. Puertos de aplicación

| Puerto | Operaciones | Observaciones |
|---|---|---|
| GitRepositoryPort | discover, readSnapshot, listBranches, historyPage, listChanges, fileDiff | Resultados estructurados; no texto de terminal para reglas de negocio |
| GitClonePort | clone | Fuente/destino validados; reserva de carpeta, transferencia sin checkout inicial y progreso |
| GitMutationPort | stage, unstage, commit, checkout, create/deleteBranch, fetch, fastForward, push, amendMessage | Operaciones v1 enumeradas; no argumento shell libre |
| HostingProviderPort | connectionCapabilities, listWorkspaces, listRepositories, resolveCloneUrl | Proveedor soportado y permisos explícitos; cursores opacos |
| RepositoryRegistryPort | get, findByPath, save, remove, list, setFavorite, assignGroup | Transacciones de metadatos locales |
| SecretStorePort | put, use, delete, availability | No `getSecret` expuesto a vistas; uso dentro de adaptadores de autenticación |
| TerminalPort | create, write, resize, close, subscribeOutput | Flujo separado de operaciones Git y logs |
| OperationCoordinatorPort | acquire, release, progress, reconcile | Canonical commonGitDir, cancelación y generaciones |
| Clock/IdGenerator/EventPublisher | now, newId, publish | Inyección facilita pruebas deterministas |

Estos nombres son contratos de diseño, no nombres de APIs existentes. El ejecutor de procesos reside dentro del adaptador Git y no se expone como puerto invocable desde la UI.

## 4. Contratos de casos de uso, versión 1

Todas las llamadas validan entrada y acceso al contexto abierto. Una selección de carpeta devuelve un identificador validado por el servicio de repositorios. En operaciones ordinarias, las vistas envían repositoryId, no una ruta arbitraria. Son contratos internos Swift, no una API HTTP ni IPC obligatoria. La UI y los casos de uso se comunican por métodos async y streams de eventos.

```swift
// Esquemas ilustrativos; los tipos de identidad tendrán validación propia.
struct CompareInput: Sendable {
    let repositoryId: RepositoryID
    let baseOid: ObjectID
    let targetOid: ObjectID
}

struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    let nextCursor: String?
    let snapshotGeneration: UInt64
}

struct AppFailure: Error, Sendable {
    let code: String
    let messageKey: String
    let retryable: Bool
    let operationId: OperationID?
}
```

Los ejemplos son esquemas orientativos. El servicio resuelve OID y comprueba tipo commit, existencia, pertenencia al contexto y desigualdad. La lista de cambios puede paginar su entrega, pero debe declarar si está completa: `completeness: complete | partial | unavailable`, `nextCursor` y `reason`. Nunca presentar el primer lote como si fuera el conjunto total.

| Caso de uso | Entrada | Salida |
|---|---|---|
| repositories.open | registrationId o directoryGrantId | Registro y snapshot |
| repositories.clone | validatedSourceId/URL permitida, destinationGrantId, profileId | operationId |
| repositories.status | repositoryId | Snapshot y archivos |
| branches.create | repositoryId, name, startOid, checkout | operationId |
| sync.pull | repositoryId, remote, fullRef, strategy: ff-only | operationId; divergencia se resuelve explícitamente por terminal v1 |
| history.page | repositoryId, filter, cursor?, pageSize | Page de commits y referencias |
| comparisons.create | CompareInput | comparisonId, pair, resumen, completeness |
| comparisons.files | comparisonId, cursor? | Page de ChangedFile |
| comparisons.diff | comparisonId, pathId, contextLines, cursor? | Hunks, indicadores de límites y nextCursor |
| commits.copyOid | repositoryId, oid, format: full/short | Confirmación del portapapeles |
| commits.prepareAmend | repositoryId, expectedHeadOid, newMessage, publish | Plan sin secretos |
| commits.executeAmend | planId, confirmationId | operationId |
| terminal.create/write/resize/close | repositoryId o sessionId y parámetros específicos | Sesión/confirmación |

El usuario escribe comandos arbitrarios únicamente en su terminal interactivo. `terminal.write` autoriza entrada a una sesión existente y no crea procesos adicionales desde un DTO genérico.

## 5. Plan de edición de mensaje

`AmendPlan` contiene oldHeadOid, treeOid, parentOids, rama, remote y ref de push exactos, expectedRemoteOid si se va a publicar, oldMessage, newMessage, policy de hooks/firma, instante de preparación, estado de índice/working tree, acciones y recoveryRef prevista. El contenido del mensaje no se registra en el journal de diagnóstico.

El plan es de un solo uso y expira después de 60 segundos o ante un cambio observado. Su ejecución revalida todo lo relevante: una confirmación previa no vuelve seguros datos ya cambiados. Primero se crea una referencia local de recuperación; luego se modifica HEAD preservando árbol y padres. Antes de publicar se vuelve a comprobar que el nuevo HEAD es el resultado esperado. El lease protege la referencia remota exacta contra un valor diferente del observado. Si el push falla, el estado resultante se muestra y no se ejecuta un reset automático.

Las operaciones Git y la base local no conforman una transacción atómica distribuida. El journal permite reconciliar fallos; no promete rollback remoto. La opción de editar sin publicar genera un estado pendiente de publicación claramente visible.

## 6. Persistencia propuesta

| Tabla | Contenido y relaciones |
|---|---|
| schema_migrations | Versión, fecha y checksum de migración |
| repositories | Identidad, ruta canónica, gitDir/commonGitDir, nombre, fechas y estado de confianza |
| repository_groups | id, nombre, color opcional, orden |
| repository_preferences | repositoryId, groupId nullable, favorite, estado de paneles |
| connection_profiles | Proveedor, modo de transporte/API, usuario/correo, referencia de secreto |
| repository_connections | repositoryId, remoteName, uso fetch/push, profileId; vinculación opcional |
| preferences | Valores pequeños versionados: tema, idioma, tamaño de fuente, Git executable |
| operation_journal | Tipo, estado, OID esperados/resultantes cuando sea necesario, recoveryRef, error saneado |

Las tablas no contienen tokens ni claves SSH privadas. Los commits y el contenido del repositorio no se duplican como datos autoritativos. Los grupos locales no sincronizan con Bitbucket. La eliminación de un perfil no revoca un token en Atlassian: la UI explica la diferencia.

Política inicial: diagnóstico rotativo hasta 10 MB; journal de operaciones durante 30 días; caché descartable hasta 200 MB; scrollback terminal 5.000 líneas por sesión, sin persistencia de salida. Son límites de diseño ajustables tras medición, no prestaciones demostradas. Las referencias de recuperación no se eliminan de forma silenciosa; el usuario recibe una acción de limpieza con explicación.

## 7. Eventos

`RepositorySnapshotChanged`, `ReferencesChanged`, `OperationProgress`, `OperationFinished`, `ConnectionCapabilitiesChanged`, `TerminalOutput`, `TerminalExited` y `ComparisonInvalidated` llevan IDs y generación cuando corresponda. La UI ignora eventos antiguos y desuscribe listeners al cerrar una pestaña. Output de PTY usa lotes con backpressure y no se transmite dentro del journal.

## 8. Errores y recuperación

| Código | Significado y acción |
|---|---|
| GIT_NOT_AVAILABLE | Seleccionar una instalación Git válida o instalarla por separado |
| NOT_A_WORKING_REPOSITORY | Elegir carpeta válida; bare queda fuera del editor de trabajo v1 |
| AUTH_REQUIRED / AUTH_EXPIRED | Reautenticar el perfil correspondiente |
| PERMISSION_DENIED | Mostrar remoto/rama sin secretos y revisar permisos |
| HOST_KEY_UNVERIFIED | Verificar identidad SSH; no omitir comprobación |
| WORKTREE_DIRTY | Mostrar archivos que bloquean checkout/integración; elegir acción explícita |
| INTEGRATION_IN_PROGRESS | Continuar/abortar operación real o usar terminal |
| NON_FAST_FORWARD | Fetch y mostrar divergencia; no forzar push automáticamente |
| REMOTE_CHANGED / PLAN_STALE | Repreparar plan y pedir nueva confirmación |
| REPOSITORY_LOCKED | Esperar o inspeccionar proceso propietario; no borrar lock automáticamente |
| OBJECT_NOT_AVAILABLE | Explicar historial shallow/objeto faltante y ofrecer fetch explícito |
| LIMIT_REACHED | Mostrar límite y permitir cargar más/abrir archivo de otra forma |
| NETWORK_UNAVAILABLE / RATE_LIMITED | Conservar trabajo local y reintento explícito seguro |
| OPERATION_INTERRUPTED | Releer estado antes de ofrecer continuar |
| UNSUPPORTED_PROVIDER | Explicar que integración remota v1 admite Bitbucket |

Los mensajes completos de stderr no se entregan a presentación sin saneamiento. Un código no siempre determina un único diagnóstico: conservar detalles técnicos acotados y seguros para soporte cuando la clasificación sea incierta.
