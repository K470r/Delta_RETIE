# Decisiones del proyecto

Registro de lo acordado con el usuario (ingeniero electricista, director técnico de un
organismo de inspección). Antes de cambiar algo de esta lista, se propone y se confirma.

## Forma de trabajo

- **Primero se propone, se analiza y se confirma; después se hace.** No se ejecutan pasos
  que no hayan sido aprobados.
- Las explicaciones para el usuario van en español, paso a paso y numeradas.
- Los cambios de base de datos se entregan como archivo SQL en `supabase/migrations/` para
  pegar en el SQL Editor de Supabase. Nunca se piden contraseñas ni claves secretas en el chat.

## Producto

- **"Delta RETIE" es el nombre código.** El nombre comercial se definirá después; el nombre
  está en un solo lugar del código (`src/lib/producto.ts`).
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

- Ingreso con **correo y contraseña** o con **enlace al correo**. Cada persona cambia su
  contraseña en "Mi cuenta".
- Las plantillas de correo de Supabase solo se editan con un servidor de correo propio (SMTP);
  queda para cuando se configure el correo con el dominio del organismo.
