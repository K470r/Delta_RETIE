# Decisiones del proyecto

Registro de lo acordado con el usuario (ingeniero electricista, director técnico de un
organismo de inspección). Antes de cambiar algo de esta lista, se propone y se confirma.

## Forma de trabajo

- **Primero se propone, se analiza y se confirma; después se hace.** No se ejecutan pasos
  que no hayan sido aprobados.
- Las explicaciones para el usuario van en español, paso a paso y numeradas.
- Los cambios de base de datos se entregan como archivo SQL en `supabase/migrations/` para
  pegar en el SQL Editor de Supabase. Nunca se piden contraseñas ni claves secretas en el chat.

## Etapa actual: prueba

- Estamos iniciando: se va a repetir y ajustar mucho. **Los datos que se cargan ahora son de
  prueba**, aunque se tomen de los reales.
- **Antes de la operación real se borra todo** y el sistema arranca limpio (pendiente: un
  script de reinicio total, probado antes de usarlo).

## Producto

- **El producto se llama "Ultra RETIE"** (antes "Delta RETIE", nombre código del proyecto; el
  repositorio conserva ese nombre). El nombre está en un solo lugar del código
  (`src/lib/producto.ts`) y en `public/manifest.webmanifest`.
- Objetivo: la operación del organismo del usuario, y en el futuro **venderlo o donarlo al
  Ministerio de Minas y Energía** para todos los organismos. Por eso:
  - Una sola base de datos multi-organismo con seguridad por filas.
  - Nada de datos personales del usuario escritos en el código (pendiente: el correo del
    administrador en `0003_autenticacion.sql` debe pasar a ser un paso de configuración).
  - Código portable (Next.js + Supabase, ambos instalables en servidores propios).
  - Protección de datos personales (Ley 1581 de 2012) desde el diseño.
  - Licencia del código: por definir antes de entregarlo.
- Escala esperada: unas **20 personas por organismo**, en todo el país.

## Costos

- **Ahora: todo en planes gratuitos**, eligiendo servicios donde pasar a pago sea fácil.
  - Supabase Free → Supabase Pro (mismo proyecto). El plan gratuito no hace copias de
    seguridad y se pausa tras una semana sin uso: no sirve para la operación real.
  - Vercel Hobby (solo uso no comercial: sirve para la prueba) → Vercel Pro u otro
    hospedaje que permita uso comercial.
- Operación real estimada: 25 a 50 USD/mes para todos los organismos juntos.

## Diseño visual (aprobado con la muestra)

- **Panel lateral fijo** a la izquierda; el contenido se desplaza y el panel queda quieto.
- **La sección actual queda iluminada** (fondo ámbar suave, barra ámbar e ícono ámbar).
- Organización **opción B**:
  - Inicio.
  - OPERACIÓN: Cotizaciones y solicitudes (§7.1) · Órdenes y asignación (§7.1, §6.1.6) ·
    Inspecciones (§7.2, §7.3) · Revisión IA (apoyo a §7.4) · Revisión técnica y dictámenes
    (§7.4) · Quejas y apelaciones (§7.5, §7.6).
  - SISTEMA 17020: Imparcialidad y confidencialidad (§4) · Organismo y alcance acreditado
    (§5) · Personal y competencia (§6.1) · Equipos y calibraciones (§6.2) · Sistema de
    gestión (§8) · Configuración · Plataforma (solo el administrador de la plataforma).
- Cada persona ve en el menú solo lo que le corresponde según su rol.
- En el celular: menú inferior con íconos.
- Colores: azul petróleo profundo (panel), ámbar eléctrico (activo, electricidad e
  iluminación), verde energía (cumple, sostenibilidad), naranja (alertas), azul agua (datos).
- Más íconos y menos texto; secciones fáciles de leer. El contenido de cada sección se
  diseña cuando se trabaje en ella.

## Logos

- Al crear o editar un organismo se carga su **logo**. Arriba del panel va el logo del
  organismo con su nombre.
- El **símbolo de acreditado de ONAC** se carga en el organismo y **solo aparece en la
  entrega de resultados: el informe de no conformidades y el dictamen**. En todo lo demás va
  únicamente el logo del organismo. Su uso debe seguir las reglas de ONAC para el uso del
  símbolo de acreditado.
- **En el informe de no conformidades y en el dictamen van juntos**: símbolo ONAC a la
  izquierda y logo del organismo a la derecha, alineados arriba, separados exactamente **el
  diámetro de la "O" de la palabra ONAC** (en el archivo del usuario: símbolo de 759×312 px y
  separación de 84 px, es decir, 11 % del ancho del símbolo). El símbolo va con el texto
  "ISO/IEC 17020:2012" y el código de acreditación debajo, y se usa la versión **sin fondo
  blanco** porque la hoja del dictamen es blanca.
- Corrección pendiente en el archivo del usuario: el texto dice `17-0IN-032` (con cero); el
  código del certificado es `17-OIN-032` (con la letra O).

## Prueba de concepto (por fases)

| Fase | Contenido |
|---|---|
| 0 | Decisiones, diseño aplicado, limpieza de datos PRUEBA, publicación gratuita |
| 1 | Organismo real: datos, personal, alcance de cada persona, alcance acreditado (revisión 17020) |
| 2 | Inspecciones reales de cada tipo de actividad acreditada y carga de evidencias (fotos, PDF, video corto) |
| 3 | Revisor IA: informe al inspector, subsanación y nuevo informe, en ciclo hasta cerrar |
| 4 | Revisión humana (aprueba o niega) y dictamen de prueba con marca "PRUEBA – SIN VALIDEZ" |

## Revisor IA

- **Apoyo, no reemplazo**: la revisión técnica y la decisión son humanas (17020 §7.4). Cada
  informe de la IA queda registrado con la versión de criterios y del modelo usados.
- **Criterios escritos por ítem** de la lista de verificación (versionados), no un modelo
  entrenado a la medida.
- Prioridades del usuario: fotos faltantes, firmas faltantes, certificados de producto
  faltantes, formatos y mediciones sin diligenciar o mal diligenciados, y no conformidades
  que se ven en fotos o documentos y el inspector no identificó.
- Pieza intercambiable: **IA en la nube o local** con los mismos criterios. El usuario acepta
  la nube con contrato que impida usar los datos para entrenar, sin descartar lo local.
  Equipo disponible: GTX 1080 Ti (11 GB) para pruebas; puede comprar una tarjeta más actual.
- Videos (por ejemplo, arranque de generador en menos de 10 s): la IA verifica que exista y
  su duración; la medición la registra el inspector y la confirma el revisor.

## Acceso

- Aplicación publicada en **https://ultra-retie.vercel.app** (Vercel Hobby, equipo GCEI, proyecto
  `ultra-retie`; se publica sola cada vez que cambia `main`). La dirección anterior,
  `delta-retie.vercel.app`, se redirige a la nueva.
- Ingreso con **correo y contraseña** o con **enlace al correo**. Cada persona cambia su
  contraseña en "Mi cuenta".
- **Nadie puede crearse una cuenta por su cuenta.** Los usuarios los crea el administrador
  (Supabase → Authentication → Users → Add user). La aplicación no crea usuarios al pedir el
  enlace, y en Supabase está desactivado *Allow new users to sign up*.
- Revisores de la aplicación (aliados): **opción B**, entran al organismo real con su rol real
  y firman el acuerdo de confidencialidad al ser designados. Roles: Luisa, gerente;
  Nelson, gerente e inspector; Eimi, inspectora. El segundo correo del usuario
  no se usa. Por ahora solo se crea el usuario de Eimi.
- **Acceso de revisión temporal** (`0006_acceso_revision.sql`): para que alguien vea todo el
  organismo en solo lectura por un tiempo limitado, sin designaciones falsas. Lo otorga solo el
  administrador de la plataforma, con fecha y hora de vencimiento, y queda en la bitácora.
  Primer uso: Eimi, hasta el 6 de noviembre de 2026 (hoy y mañana).

## Quién ve qué (aprobado)

Todos los archivos están en carpetas privadas (incluidos los logos) y se abren con enlaces
que vencen en minutos; la base de datos solo los entrega si el rol lo permite. Nadie más.

| Información | La persona misma | Gerencia | Responsable SG | Director técnico | Revisor asignado | Inspector asignado | Otros inspectores |
|---|---|---|---|---|---|---|---|
| Hoja de vida y sus soportes | ✅ | ✅ | ✅ | ✅ | — | — | ❌ |
| Procedimientos, manual y formatos vigentes | ✅ (todo el personal vinculado) | ✅ | ✅ editar | ✅ | ✅ | ✅ | ✅ |
| Registros del SG (auditorías, revisión por la dirección, acciones) | — | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Evidencias de una inspección (fotos, videos, PDF) | — | ❌ | ✅ (auditoría) | ✅ | ✅ | ✅ | ❌ |
| Informe de no conformidades y dictamen | — | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Cotizaciones y datos del cliente | — | ✅ | ✅ | ✅ | ❌ | solo la orden asignada | ❌ |

- "Gerencia" = representante legal, gerente y miembros de la gerencia. Los logos los ve el
  personal vinculado al organismo.
- Hecho en `0005_acceso_por_rol.sql`: hoja de vida y soportes, logos privados. Las demás filas
  se aplican al construir cada módulo.

## Competencia del personal (cómo trabaja GC&I)

- El usuario es **director técnico e inspector**. Cuando él inspecciona, la revisión técnica la
  hace el **director técnico suplente** (la base de datos impide que el revisor sea el inspector, §7.4).
- **Evalúan y califican a los inspectores** el director técnico y el suplente; pueden **delegar**
  en un inspector experimentado que trabaja bajo su tutela (supervisión y seguimientos).
  *Pendiente:* la delegación en la aplicación (hoy solo verifican soportes la gerencia, el SG y la
  dirección técnica).
- **La gerente revisa los soportes y autoriza las actividades** del inspector.
- Se puede designar director técnico, suplente o inspector **con las actividades pendientes**; se
  autorizan después con "+ Autorizar actividades", cuando otra persona haya verificado los soportes.
  Mientras tanto la persona no puede ejercer.
- Arranque de GC&I: el director técnico (el usuario) se designa con las actividades pendientes;
  antes de designarse carga logos, póliza y declaración de independencia (después solo la
  gerencia o el SG modifican el organismo); luego designa a la gerente.

## Documentos del organismo (con historial)

- Certificado de acreditación ONAC (con su anexo), póliza de responsabilidad civil y
  declaración de independencia del organismo tipo A (Anexo A.1), en PDF
  (`0008_documentos_organismo.sql`).
- Cada carga es una versión nueva; la anterior queda **reemplazada** y se conserva con su PDF,
  quién y cuándo (no se modifica ni se borra). La versión vigente actualiza los datos del
  organismo (fechas de acreditación, renovación, última actualización, póliza, declaración).
- Los cargan la gerencia y el responsable del SG. El certificado lo ve todo el personal; la póliza
  y la declaración, la gerencia, el SG y la dirección técnica.

## Alcance acreditado (diseño aprobado)

- Dos columnas, RETIE y RETILAP; títulos de cada actividad en mayúsculas y nombre completo
  justificado debajo. Al tocar una actividad se abre su detalle: procedimientos y formatos de
  inspección, directores técnicos e inspectores autorizados, equipos de medición y referencias
  del reglamento; ahí también "Cambiar estado" y "Quitar (registrada por error)".
- "Agregar actividad" solo muestra las que aún no están en el alcance.

## Quién hace qué en el organismo (`0009_permisos_alcance.sql`)

| Acción | Quién |
|---|---|
| Todo, mientras nadie esté designado (arranque) | El creador del organismo |
| Cambiar el estado de una actividad del alcance (acreditada, en trámite, suspendida, retirada) | Solo la gerencia |
| Agregar actividades (quedan en trámite) y quitarlas por error | La gerencia y el responsable del SG |
| Datos, logos y documentos del organismo | La gerencia y el responsable del SG |
| Documentos de cada alcance (procedimientos y formatos, cuando existan) | El director técnico, el responsable del SG y la gerencia |

- "Gerencia" = representante legal, gerente y miembros de la gerencia.
- **Los suplentes pueden lo mismo que el titular**, y queda indicado que actuó el suplente: la
  bitácora guarda en qué calidad actuó cada persona; el alcance muestra quién fijó el estado y
  como qué.
- "Retirar" un documento = marcarlo obsoleto (se conserva); "modificar" = cargar versión nueva.
- La bitácora de un organismo la lee solo quien lo administra.

## Correcciones

- Nada se borra (17020 §8.4). Excepción: **"Quitar (registrada por error)"** para una actividad
  del alcance del organismo o una actividad autorizada a un director técnico o inspector, solo si
  nunca se usó (nadie la tiene autorizada / no hay órdenes de servicio). Lo hace quien administra
  el organismo, con motivo obligatorio, y queda en la bitácora (`0007_quitar_por_error.sql`).
- Lo que sí se usó no se quita: se cambia de estado (actividad retirada) o se finaliza la designación.

## Matrícula profesional (`0010_matricula_ingeniero.sql`)

- Director técnico e inspector exigen matrícula de **ingeniero**: **CPNIEMPA** (Consejo Profesional
  Nacional de Ingenierías Eléctrica, Mecánica y Profesiones Afines, Ley 51 de 1986), el más
  frecuente, o **COPNIA** (Ley 842 de 2003).
- El **CONTE** (técnicos electricistas) y el **CONALTEL** (tecnólogos, Ley 1264 de 2008) no sirven
  para esos cargos: no cumplen de inmediato y no se pueden aceptar a mano.
- **Otra entidad** (un consejo poco común): solo cuenta si la **gerencia la acepta a mano**, con
  motivo; nadie acepta la suya; si cambian la entidad o el número, la aceptación se pierde.

## Botones

- **Principal** (relleno, color de la aplicación): agregar certificado, experiencia o formación,
  autorizar actividades, registrar seguimiento, generar documento, firmar, guardar.
- **Contorno** (borde de color, fondo claro): ver soporte, cambiar soporte, aceptar matrícula,
  ver documento, editar.
- **Pequeños en rojo**: anular, finalizar, quitar por error (se mantienen discretos).

## Seguimiento del mes 30 (`0011_seguimiento_y_asistente.sql`)

- A 60 días o menos de la fecha máxima: **franja naranja** con los días que faltan y el botón
  grande "Registrar seguimiento". También aparece arriba de todas las páginas para la persona.
- Vencida la fecha sin registrarlo: **franja roja**; el certificado no cuenta y la persona **no
  puede ejercer** sus actividades.
- Se puede registrar después, pero el certificado vuelve a contar **solo desde el día del
  registro** (o de la fecha del seguimiento, la que sea posterior). El periodo intermedio queda
  como **no habilitado**, para siempre. La fecha de registro la pone la base de datos.
- El seguimiento no puede tener fecha futura ni anterior a la emisión.

## Generación según la tensión (`0012_generacion_por_tension.sql`)

Para generación con FNCE, AGPE y GD y generación con varias fuentes:

| Instalación | Se inspecciona como | Competencia del inspector y del director técnico |
|---|---|---|
| Conectada a la red, más de 1.000 V AC o más de 1.500 V DC | Generación | Categoría **a** |
| Conectada a la red, hasta 1.000 V AC y 1.500 V DC (incluidos) | Generación | Categoría **g** |
| No conectada a la red, hasta 1.000 V AC y 1.500 V DC | Uso final (autogeneración) | Categoría **g** |
| No conectada a la red, más de 1.000 V AC o 1.500 V DC | Generación | Categoría **a** |

- Al autorizar al personal, cada una de esas actividades aparece **dos veces**: "más de
  1.000 V AC o 1.500 V DC" (categoría a) y "hasta 1.000 V AC y 1.500 V DC" (categoría g).
  La segunda no se acredita aparte: la cubre la misma línea del alcance.
- En la fase 2, al registrar la inspección se pedirán la tensión AC y DC y si está conectada a la
  red, y solo se podrá asignar personal con la competencia que corresponde.

## Documentos del personal con firma (`0013_documentos_personal.sql`)

| Documento | Firman |
|---|---|
| Designación de gerente | El gerente designado (autodesignación). Si lo designó una junta de socios, se indica en el acto y se carga el acta firmada a mano |
| Designación de responsable del SG | El gerente (puede designarse a sí mismo) |
| Autorización del director técnico principal | El gerente |
| Autorización del director técnico suplente | El gerente y el director técnico principal |
| Autorización de inspector | El gerente y el director técnico (principal o suplente) que lo evaluó |
| Designación de asistente de dirección técnica | El gerente |

- La junta directiva o de socios no es un rol del sistema: el rol es el gerente.
- **Firma electrónica en la aplicación** (opción b): el firmante lee el documento, confirma su
  contraseña (vale 10 minutos) y firma. Queda la fecha y hora, el usuario, el correo, el navegador,
  la IP y la huella SHA-256 del texto (si el texto cambiara, la firma no valdría). Ley 527 de 1999
  y Decreto 2364 de 2012 (compilado en el Decreto 1074 de 2015).
- **Respaldo** (opción a): imprimir, firmar a mano, escanear y cargar el PDF. Lo carga la gerencia
  o el SG y queda quién y cuándo.
- Para firmar, el firmante debe tener su propia designación firmada (el gerente firma primero la
  suya). Nadie firma su propia autorización como director técnico ni se evalúa a sí mismo.
- **Sin el documento firmado, el director técnico o el inspector no puede ejercer** (no se le
  asignan servicios) y el tablero lo marca. Si se le autorizan más actividades, se genera un
  documento actualizado; los firmados se conservan y siguen valiendo para sus actividades.
- Los textos son **provisionales**: se adecuarán a los formatos del organismo cuando lleguen.

## Desvincular del OEC

- El botón **DESVINCULAR DEL OEC** de cada tarjeta termina **solo ese rol** desde hoy, con motivo
  obligatorio. Los demás roles de la persona y su vinculación con el organismo siguen vigentes.
- No se puede deshacer: para volver a darle el rol hay que designarla de nuevo.

## Asistente de dirección técnica

- Pide las evidencias de las inspecciones y revisa que estén completas antes de pasarlas al
  director técnico (parte de lo que hará la revisión con IA, fase 3).
- Hace seguimiento a que las inspecciones se realicen.
- Atiende a los inspectores: formatos, procedimientos, dónde encontrar algo en el sistema.
- Hace el control metrológico; documentos, tablas y decisiones los aprueba un director técnico.
- Acompaña a los inspectores como personal de apoyo cuando se requiera.
- Por ahora ve lo mismo que un inspector (su hoja de vida y su documento); sus permisos sobre
  inspecciones, evidencias y equipos se definen con las fases 2 y 3.

## Datos personales (Ley 1581 de 2012)

- El personal del organismo ya autorizó el tratamiento de sus datos.
- Clientes: el organismo les está informando. No se publica nada. Antes de cargar inspecciones
  reales (fase 2), el aviso debe cubrir también el almacenamiento de evidencias y, si se usa,
  su revisión con IA en la nube.
- Las plantillas de correo de Supabase solo se editan con un servidor de correo propio (SMTP);
  queda para cuando se configure el correo con el dominio del organismo.
