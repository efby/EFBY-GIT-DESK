# Plan de desarrollo y guía del equipo

Versión 0.1 · 6 de octubre de 2026 · Plan propuesto para macOS y Bitbucket Cloud.

## 1. Cómo iniciar

Esta entrega documenta el programa; no contiene su implementación. Antes de abrir desarrollo de funcionalidades, crear el repositorio del proyecto, trasladar esta documentación a `docs/`, registrar el stack que se adopte y preparar un proyecto macOS con paquetes Swift separados. La primera tarea es comprobar los riesgos técnicos en un prototipo pequeño y descartable.

Clean Architecture, Bitbucket Cloud, macOS, comparación de dos commits y edición del último mensaje publicado son decisiones confirmadas. SwiftUI, macOS mínimo, arquitecturas de CPU, SQLite y biblioteca de terminal son propuestas. El prototipo debe confirmar una versión estable de Swift/Xcode y las APIs necesarias, sin convertir una dependencia candidata en una decisión implícita.

## 2. Hitos y dependencias

| Hito | Entregable revisable | Requisitos principales | Condición para avanzar |
|---|---|---|---|
| **H0 — Viabilidad nativa** | Ventana macOS, ejecución Git con pipes, shell PTY redimensionable, prueba Keychain y build firmado de laboratorio | RNF-01/02/06 | Git y terminal funcionan al abrir desde Finder; documentación de límites y dependencias elegidas |
| **H1 — Repositorios y confianza** | Registro, rutas, pestañas, grupos, favoritos, recientes, estado de confianza y persistencia | RF-01/04/16 | Abrir/cerrar/quitar registro no modifica archivos; rutas no confiables no ejecutan scripts |
| **H2 — Historial y diff** | Historial paginado, grafo, detalle, copia de SHA, comparación A/B e inventario completo | RF-10/11/12 | Pasa fixtures de merge, ramas diferentes, raíz, rename/binarios y límites visibles |
| **H3 — Conexiones y clonación** | Perfil token/SSH/heredado, pruebas por capacidad, catálogo API y clone sin checkout inicial | RF-02/03/06 | Token fuera de URLs/logs; catálogo paginado; clone fallido no sobrescribe carpetas |
| **H4 — Trabajo y sincronización** | Ramas, stage/unstage, commit, pull ff-only, push y terminal conectado al refresco | RF-05/07/08/09/14/15 | Integridad verificada en repos temporales y carreras; no integración/descarte automático |
| **H5 — Edición publicada** | Plan, confirmación, backup ref, amend solo mensaje, lease y recuperación | RF-13 | Carrera con segundo clon y rama protegida fallan conservando estado recuperable |
| **H6 — Beta y distribución** | Instalador macOS, pruebas de accesibilidad/rendimiento, manual y reporte QA | RNF-03/04/05/07/08 | Criterios P0 y matriz completos; artefacto firmado/notarizado probado desde descarga |

H2 y parte de H3 pueden desarrollarse en paralelo sobre los puertos definidos. H4 depende de la coordinación de operaciones y confianza. H5 depende de conexiones, push, journal y recuperación; no se implementa como atajo que llame `--force`.

No se asignan fechas ficticias. Después de H0, estimar cada hito con el tamaño del equipo, experiencia Swift, restricciones corporativas y disponibilidad de cuentas de prueba. La compatibilidad con Intel se valida antes de prometer una distribución universal.

## 3. Backlog inicial de historias

| Historia | Resultado para el usuario | Requisito / prioridad |
|---|---|---|
| US-01 | Como desarrollador, abro una carpeta Git existente y recupero sus preferencias de navegación | RF-01/04, P0 |
| US-02 | Organizo repositorios mediante grupos locales y favoritos, sin mover sus carpetas | RF-01, P0 propuesto |
| US-03 | Reutilizo SSH/helpers de mi clon sin copiar claves privadas | RF-02, P0 |
| US-04 | Conecto un API token para elegir un repositorio Cloud y clonarlo | RF-02/03, P0 |
| US-05 | Clono mediante URL conocida con SSH aunque no tenga acceso al catálogo API | RF-03, P0 |
| US-06 | Creo/cambio una rama y entiendo qué cambios impiden hacerlo | RF-05, P0 |
| US-07 | Obtengo referencias y veo si los contadores remotos están actualizados | RF-06, P0 |
| US-08 | Traigo cambios fast-forward o recibo una explicación clara de la divergencia | RF-07, P0 |
| US-09 | Preparo archivos completos y creo un commit con el contenido previsto | RF-09, P0 |
| US-10 | Publico la rama elegida con su destino visible | RF-08, P0 |
| US-11 | Copio el SHA completo de un commit desde el historial | RF-10, P0 |
| US-12 | Selecciono exactamente A y B, veo todas las rutas cambiadas y comparo del commit inferior al superior | RF-11/12, P0 |
| US-13 | Corrijo el mensaje del último commit publicado con una revisión del efecto y recuperación | RF-13, P0 |
| US-14 | Uso comandos en el terminal inferior y la vista se actualiza tras mis cambios | RF-14/15, P0 |
| US-15 | Trabajo sin red con mis datos locales y reconozco operaciones remotas pendientes | RF-04, P0 |
| US-16 | Opero las funciones principales por teclado y VoiceOver | RF-16/RNF-05, P0 |

Cada historia se descompone en tarea de dominio/caso de uso, adaptador y presentación. Un cambio vertical pequeño debe mostrar una acción real verificable, evitando construir meses de infraestructura sin un flujo útil.

## 4. Normas de implementación

**Dominio:** valores inmutables, invariantes comprobadas en constructores/casos de uso; no acceso a Git, filesystem, red ni UI. No inventar entidades para datos que solo sirven a una vista.

**Aplicación:** métodos async con errores estables, protocolos de salida y eventos. Inyectar tiempo, IDs y servicios donde permitan comprobar comportamiento. Los casos de uso de mutación revalidan precondiciones y solicitan la cola correspondiente.

**Infraestructura:** una implementación por mecanismo: Git CLI, REST Cloud, Keychain, SQLite, PTY. Parsear formatos de máquina como bytes; mantener las salidas completas necesarias fuera del hilo de UI. No usar un shell para los comandos de la interfaz.

**Presentación:** organizar por funcionalidad. Modelos observables en MainActor; tareas con cancelación y resultados identificados por generación. El cuerpo de las vistas no ejecuta Git, filtra 100.000 registros ni construye el grafo completo. La identidad del terminal se conserva cuando cambia el layout.

**Persistencia:** migraciones pequeñas y reversibilidad documentada cuando sea viable. Ninguna migración modifica un repositorio Git del usuario. No eliminar backups de reescrituras pendientes para cumplir un límite de caché.

**Configuración:** detectar Git ejecutable y sus capacidades. No suponer el PATH de una shell al abrir desde Finder. La shell de terminal y los procesos Git de la UI son contextos diferentes; una configuración del terminal no se importa ejecutando scripts sin conocimiento del usuario.

## 5. Flujo de trabajo del equipo

La rama principal permanece construible. Usar ramas breves por historia, cambios revisables y pull requests en el repositorio de desarrollo. La elección de nombres de ramas y convención de mensajes se documenta al crear el repositorio; Conventional Commits es opcional, no una exigencia del producto.

Toda revisión comprueba comportamiento observable, regla de dependencia, efecto sobre archivos/referencias y evidencia de pruebas. Cambios a seguridad, política de pull o edición publicada actualizan el ADR correspondiente antes de liberar. Una funcionalidad no se considera terminada porque su pantalla esté dibujada.

## 6. Integración continua propuesta

Pipeline en un runner macOS compatible con el Xcode fijado: resolver dependencias, compilar paquetes y app, comprobar imports prohibidos y strict concurrency, ejecutar pruebas de dominio/aplicación, integración Git local y UI. Los repositorios de prueba usan configuración aislada y no requieren acceso a los repositorios personales del runner.

Las pruebas Cloud con credenciales se ejecutan en un entorno separado y con una cuenta dedicada. No se exponen secretos a contribuciones externas ni a logs. Un build de release añade firma/notarización, hashes, instalación limpia y pruebas de arranque desde Finder. Los certificados de distribución no son parte del repositorio.

Swift Testing o XCTest pueden servir para unidades e integración según el toolchain adoptado; XCTest cubre pruebas de interfaz. La elección final se fija en H0, priorizando soporte estable y ejecución reproducible sobre preferencias personales.

## 7. Definición de terminado

Una historia termina cuando satisface sus criterios RF, tiene pruebas relevantes en la matriz, comunica carga/vacío/error, funciona con teclado, conserva el trabajo ante fallos y actualiza documentación/ADR cuando cambia un contrato. No hay tokens ni datos privados en fixtures o diagnósticos.

Una release termina cuando pasa QA sobre el artefacto distribuible, tiene fuentes y versiones verificadas, manual vigente, reporte de límites, respaldo de metadatos y recuperación ensayada. Publicar instaladores será una actividad posterior al desarrollo y requiere los recursos de firma del propietario.

## 8. Entregables por versión

Conservar código, documentos versionados, ADR, matriz RF→pruebas, reporte de resultados, notas de versión, lista de dependencias/licencias, instalador y hashes. El reporte debe separar pruebas ejecutadas, fallidas y pendientes. Esta entrega solo verifica la documentación; las prestaciones del programa no se consideran probadas.
