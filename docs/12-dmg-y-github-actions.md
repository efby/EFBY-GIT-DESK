# DMG y GitHub Actions

Se adopta el flujo de EFBY_POSTMAN: app universal, DMG con enlace a Applications,
automatización por pull requests hacia main. Los secretos usan los mismos nombres. Los archivos de
EFBY_POSTMAN se consultaron como referencia y no se modificaron.

## Generar el DMG local

```bash
scripts/test.sh
scripts/build-dmg.sh --universal
```

Resultado: `dist/EFBY-Git-Desk-dev.dmg`, firma ad hoc, sin notarización.
Incluye `EFBY Git Desk.app`, enlace `Applications` e instrucciones de instalación.
El checksum está en `dist/EFBY-Git-Desk-dev.dmg.sha256`; se verifica desde esa carpeta.
`--universal` genera arm64 y x86_64 para la app y su auxiliar. No pasar esta opción
conserva la arquitectura del host. Compilar Intel no acredita ejecución en Intel.

## Firma y notarización local

```bash
scripts/build-dmg.sh --universal --sign
scripts/build-dmg.sh --universal --notarize
```

`--sign` produce `dist/EFBY-Git-Desk-signed.dmg`, sin ticket Apple.
`--notarize` produce `dist/EFBY-Git-Desk.dmg` únicamente tras la validación final.
La identidad predeterminada es Developer ID Application de EFBY, Team FYU5QTGXLB.
Se puede cambiar con `DEVELOPER_ID_APP` y `APPLE_TEAM_ID`.
`NOTARY_PROFILE` usa por defecto `efby-requestlabs-notary`, compartido con POSTMAN.
`NOTARY_KEYCHAIN` permite un Keychain específico.

Para registrar o renovar la credencial, ejecutar en el terminal propio:

```bash
xcrun notarytool store-credentials efby-gitdesk-notary
```

Introduce Apple ID, contraseña específica de app y Team en los prompts; no pegues
contraseñas en el chat ni las guardes en el repositorio. Después usar
`NOTARY_PROFILE=efby-gitdesk-notary scripts/build-dmg.sh --universal --notarize`.
El perfil antiguo devolvió HTTP 401 durante la comprobación del 6 de octubre de 2026.
No se renovó ni reemplazó automáticamente.

El script firma primero el auxiliar y luego la app con Hardened Runtime y timestamp;
notariza el ZIP de la app, verifica Accepted, adjunta y valida su ticket; crea el DMG,
lo notariza y adjunta/valida su ticket. No firma de nuevo el DMG. Verifica checksum,
monta solo lectura y comprueba la firma de la app contenida, el enlace Applications,
el ticket y Gatekeeper cuando está notarizado. Un fallo detiene la entrega del nuevo
artefacto. `dist/` permanece ignorado.

## Configurar GitHub

Abrir [Secrets and variables → Actions del repositorio](https://github.com/efby/EFBY-GIT-DESK/settings/secrets/actions).
Agregar estos cinco Repository secrets, con los valores que usa POSTMAN:

| Nombre | Valor |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | Certificado Developer ID Application y su clave exportados a .p12, codificados en Base64 |
| `MACOS_CERTIFICATE_PASSWORD` | Contraseña de ese .p12 |
| `APPLE_ID` | Cuenta Apple Developer autorizada |
| `APPLE_APP_SPECIFIC_PASSWORD` | Contraseña específica de app vigente de esa cuenta |
| `APPLE_TEAM_ID` | `FYU5QTGXLB` |

Si ya son secretos de organización, autorizar EFBY-GIT-DESK en su lista de
repositorios permitidos. GitHub no permite recuperar los valores de secretos
existentes; reutilizar el origen seguro, no intentar obtenerlos de logs.
Se configuraron los cinco nombres en GitHub. Se cargaron Apple ID, Team y el
certificado Developer ID Application con su contraseña tras autorización del
propietario. El .p12 de referencia incluía otras identidades: se aisló únicamente
la identidad de distribución y se eliminaron las copias temporales tras cargarla.
El propietario informó que también cargó la contraseña específica de Apple;
GitHub no permite leer su valor ni esta configuración acredita un release exitoso.

La configuración sigue la [guía de certificados de GitHub](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).
No necesita provisioning profile: distribución Developer ID fuera de App Store.
El runner es `macos-26`, según las [etiquetas oficiales de runners](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).
El script selecciona un Xcode disponible y exige Swift 6.2+.

**Merged PR DMG** se ejecuta únicamente al fusionar un PR hacia `main`:
`pull_request` de tipo `closed`, filtro de destino `main` y condición `merged == true`.
Abrir, actualizar o cerrar sin fusionar un PR no genera un DMG. Reutiliza
**Release DMG**, que exige los cinco secretos, ejecuta las pruebas y genera el DMG
universal firmado y notarizado. Se compila el SHA de merge del PR, aunque `main`
avance mientras el trabajo espera. El artefacto incluye DMG, checksum y resultados
de notarización. No se genera un paquete ad hoc.

No hacer push directo a `main`: trabajar en ramas y abrir PR para integrar cambios.
Los pushes a ramas o tags no disparan workflows de empaquetado. El flujo firmado
se activa por el evento de merge, no por un push. Se conserva **Release DMG → Run
workflow** para solicitudes manuales, publicando también en GitHub Releases cuando se ejecuta sobre main.
El trabajo de compilación mantiene permisos de lectura; la publicación tiene
contents: write para crear el tag y la Release. Esta norma de trabajo no equivale a una
regla de protección impuesta por GitHub; no se modificaron las reglas del repositorio.

La firma automática admite PR de ramas del mismo repositorio. Los PR externos
(forks) y Dependabot omiten el trabajo de firma porque GitHub no les entrega estos
secretos. No se usa `pull_request_target` para ejecutar código externo con claves.

Las contraseñas persistentes entran por entorno/stdin, nunca por argumentos.
El .p12 temporal se elimina tras importarlo y el Keychain temporal al terminar,
también si falla el workflow.

Consultar [Actions](https://github.com/efby/EFBY-GIT-DESK/actions) para descargar el
artefacto de un PR fusionado o iniciar **Release DMG** manualmente. El flujo manual debe
existir en la rama predeterminada para aparecer en la interfaz de GitHub.

## Estado verificado

DMG local universal generado y montado; firma ad hoc de la app y auxiliar válidas.
La recompilación posterior ejecutó 80 pruebas registradas (78 aprobadas y dos
optativas omitidas) y produjo `dist/EFBY-Git-Desk-signed.dmg`: app universal firmada
con Developer ID, Hardened Runtime y timestamp; firma estricta, checksum del DMG
y firma de la app montada verificados. Ambas arquitecturas declaran macOS 14.0
como mínimo en el binario. Este DMG firmado todavía no contiene tickets de Apple.
Certificado Developer ID local detectado. El intento posterior de registrar el
perfil `efby-gitdesk-notary`, usando la credencial local aportada por el propietario,
devolvió inicialmente HTTP 403 por un acuerdo pendiente. Se verificó en Brave el
equipo correcto y la aceptación por el Account Holder. Tras una comprobación
posterior, Apple validó las credenciales y se guardó el perfil en Keychain.

El 6 de octubre de 2026 se generó `dist/EFBY-Git-Desk.dmg` universal notarizado:
la aplicación fue aceptada en la solicitud `88dc33ef-f39f-42e4-907b-eaaf942541bf`
y el DMG en `b8275f2d-99ec-4f3f-aeb0-d5bc80b82fc9`. Los tickets se adjuntaron y
validaron. Pasaron la firma estricta de la app, checksum del DMG, montaje de solo
lectura, ticket de la app montada y evaluación Gatekeeper (`Notarized Developer ID`).
Los resultados JSON y checksum están en `dist/`, excluidos de Git. Esto verifica
el artefacto local; la instalación en otro Mac sigue pendiente.

El workflow remoto [Release DMG #6](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37562410880)
terminó correctamente el 6 de octubre de 2026 en 4 minutos 24 segundos, sobre
`76686b0`. Ejecutó 81 pruebas registradas (79 aprobadas, dos optativas omitidas)
en 18 suites, 14,449 segundos; el paso completo de pruebas tardó 1 minuto 20 segundos.
La importación del certificado exportado por Keychain requiere `-legacy` con
OpenSSL 3 para leer RC2 del contenedor PKCS#12 existente. La firma, notarización,
tickets y comprobaciones del DMG montado terminaron correctamente en el runner.
El artefacto [EFBY-Git-Desk-notarized-universal](https://github.com/efby/EFBY-GIT-DESK/actions/runs/37562410880/artifacts/11457059344)
ocupa 3,3 MB; digest del ZIP de Actions:
`be521d4258bdd4a1d3bbe5b35122175d4e7b09b0c11f5054da3bfb2b55281877`.
La descarga automática del navegador agotó su espera, por lo que no se verificó
localmente ese ZIP descargado. El disparo automático tras merge sigue pendiente
de integrar el PR #4; este ensayo utilizó la ejecución manual de `feature/mvp`.
Los archivos `.env`, `.env.*` y `.secretos/` están excluidos de Git.
No se ensayó el instalador descargado en otro Mac ni el runtime de Intel/macOS 14.

## Publicación en Releases

Flujo autorizado: merge de PR interno a main → pruebas → Developer ID →
notarización/tickets/verificación → artefacto → checksum del DMG descargado en
el trabajo de publicación → Release con DMG y checksum, notas automáticas y tag
sobre el SHA compilado. Primera versión v0.1.0; siguientes incrementan patch del
mayor tag semántico existente, respetando una versión base superior en Info.plist.
APP_VERSION se aplica a la app antes de firmar, de modo que coincide con el tag.
No se reemplazan Releases existentes. Compilación y publicación se serializan
para evitar que dos ejecuciones elijan la misma versión. Las pruebas manuales
en otras ramas solo producen artefactos; Run workflow en main también publica.
No se agregan disparadores push ni tag.

Implementación en el PR #4; pendiente de merge y primera ejecución de publicación.
El DMG remoto ya verificado de Release DMG #6 sigue disponible como artefacto,
pero no se ha publicado retroactivamente como una versión.
