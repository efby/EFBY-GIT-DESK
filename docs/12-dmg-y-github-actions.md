# DMG y GitHub Actions

Se adopta el flujo de EFBY_POSTMAN: app universal, DMG con enlace a Applications,
CI y versiones por tags. Los secretos usan los mismos nombres. Los archivos de
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
No se exportaron certificados ni se cargaron secretos desde esta sesión.

La configuración sigue la [guía de certificados de GitHub](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).
No necesita provisioning profile: distribución Developer ID fuera de App Store.
El runner es `macos-26`, según las [etiquetas oficiales de runners](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).
El script selecciona un Xcode disponible y exige Swift 6.2+.

CI ejecuta pruebas y sube DMG de desarrollo universal ante push a main/master/feature/mvp,
PR o ejecución manual. No consume credenciales Apple. Release DMG exige los cinco
secretos, ejecuta pruebas, firma/notariza y sube el artefacto; falla si falta configuración,
sin sustituirlo por una versión sin notarizar. Las contraseñas persistentes entran
por entorno/stdin y no por argumentos. El .p12 temporal se elimina tras importarlo;
el Keychain temporal se elimina al terminar, también si falla el workflow.

Tras subir y configurar, ir a [Actions](https://github.com/efby/EFBY-GIT-DESK/actions):
primero validar CI; después ejecutar **Release DMG** manualmente sobre la rama
`feature/mvp`. Esto produce un artefacto notarizado sin crear versión pública.
El workflow manual debe existir en la rama predeterminada para aparecer en la UI de
GitHub; si todavía no está integrado, aprobar primero el PR correspondiente.

Crear un tag `vX.Y.Z` sobre el commit que se quiere distribuir genera el DMG y un
**borrador** de GitHub Release con checksum. El tag también fija la versión del
bundle; la publicación pública queda para revisión. No se creó ni publicó un tag
como parte de esta preparación.

## Estado verificado

DMG local universal generado y montado; firma ad hoc de la app y auxiliar válidas.
Certificado Developer ID local detectado. Notarización pendiente por HTTP 401 del
perfil actual. Configuración de secretos y ejecución en GitHub pendientes: el
navegador integrado bloqueó el acceso al no poder verificar la política de seguridad.
No se ensayó el instalador descargado en otro Mac ni el runtime de Intel/macOS 14.
