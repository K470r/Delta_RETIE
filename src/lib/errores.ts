/**
 * Mensajes en español para los errores de la base de datos y de Supabase Auth.
 * Las reglas 17020 de la base de datos ya responden en español: se muestran tal cual.
 */
type ErrorBD = { code?: string; message?: string; details?: string | null; hint?: string | null; status?: number };

const TABLAS: Record<string, string> = {
  organismos: "organismos", sedes: "sedes", alcance_acreditado: "alcance acreditado", personas: "personas",
  certificados_competencia: "certificados de competencias", certificado_categorias: "categorías del certificado",
  formacion: "formación", experiencias: "experiencia", vinculaciones: "vinculaciones", designaciones: "designaciones",
  designacion_actividades: "actividades autorizadas", declaraciones: "declaraciones", revisiones_sg: "revisiones del SG",
  objects: "los logos del organismo (solo la gerencia o el responsable del SG)",
};

const RESTRICCIONES: [RegExp, string][] = [
  [/personas_documento_key/, "Ya existe una persona registrada con ese número de documento (puede estar vinculada a otro organismo)"],
  [/personas_usuario_id_key/, "Ese usuario de acceso ya está enlazado a otra persona"],
  [/personas_check/, "El documento debe escribirse sin puntos ni espacios"],
  [/organismos_nit_key/, "Ya existe un organismo con ese NIT"],
  [/organismos_codigo_acreditacion_key/, "Ya existe un organismo con ese código de acreditación"],
  [/certificados_competencia_certificador_numero_key/, "Ese certificado (certificador y número) ya está registrado"],
  [/sedes_una_principal/, "El organismo ya tiene una sede principal"],
  [/designaciones_organismo_id_rol/, "Ya hay otra persona vigente en ese rol en esas fechas: solo puede haber un representante legal y un responsable del SG a la vez (17020 §5.2 / §8). Finalice primero la designación actual"],
  [/vinculaciones_organismo_id_persona_id/, "La persona ya tiene una vinculación con el organismo que se cruza con esas fechas"],
  [/alcance_acreditado_pkey/, "Esa actividad ya está en el alcance del organismo"],
  [/documentos_organismo_check/, "Faltan datos del documento: revise el número, las fechas y la vigencia (el vencimiento debe ser posterior al inicio)"],
  [/designacion_actividades_pkey/, "Esa actividad ya está autorizada"],
  [/certificado_categorias_pkey/, "Esa categoría ya está en el certificado"],
];

export function mensajeError(e: unknown): string {
  if (!e) return "Error desconocido";
  if (typeof e === "string") return e;
  const err = e as ErrorBD;
  const msg = err.message ?? String(e);
  const todo = `${msg} ${err.details ?? ""}`;

  switch (err.code) {
    case "P0001": // raise exception de las reglas (ya en español)
      return msg;
    case "23505": case "23P01": case "23514": {
      const r = RESTRICCIONES.find(([re]) => re.test(todo));
      if (r) return r[1];
      return err.code === "23514" ? `Dato no válido según las reglas de la base de datos (${restriccion(todo)})`
        : `Registro duplicado o que se cruza con otro (${restriccion(todo)})`;
    }
    case "23503":
      return "El registro hace referencia a un dato que no existe o que usted no puede ver";
    case "23502":
      return `Falta un dato obligatorio (${/column "([^"]+)"/.exec(msg)?.[1] ?? "campo"})`;
    case "22P02": case "22007": case "22008":
      return "Formato de dato no válido (revise fechas y números)";
    case "42501": {
      const t = /table "([^"]+)"/.exec(msg)?.[1];
      return `No tiene permiso para registrar o modificar ${t ? TABLAS[t] ?? t : "este dato"}. ` +
        "Solo la gerencia, el responsable del SG o la dirección técnica vigentes del organismo pueden hacerlo (o el administrador de la plataforma al crear el organismo)";
    }
    case "42703": case "PGRST204":
      return "La base de datos no tiene una migración reciente (por ejemplo 0004_logos.sql). Ejecútela en el SQL Editor de Supabase";
    case "PGRST202": case "42883":
      return "La base de datos no tiene la migración 0003_autenticacion.sql. Ejecútela en el SQL Editor de Supabase";
    case "PGRST301": case "PGRST303":
      return "La sesión venció. Vuelva a ingresar";
  }
  if (/Failed to fetch|NetworkError|Load failed/i.test(msg)) return "Sin conexión con la base de datos. Revise su internet e intente de nuevo";
  return mensajeAuth(msg);
}

/** Errores de Supabase Auth (vienen en inglés). */
export function mensajeAuth(msg: string): string {
  const m: [RegExp, string][] = [
    [/invalid login credentials/i, "Correo o contraseña incorrectos"],
    [/password should be at least (\d+)/i, "La contraseña es muy corta (mínimo 8 caracteres)"],
    [/new password should be different/i, "La contraseña nueva debe ser distinta de la actual"],
    [/weak|pwned|leaked/i, "La contraseña es muy débil o conocida públicamente. Use otra"],
    [/rate limit|too many|over_email_send_rate_limit/i, "Se enviaron demasiados correos. Espere unos minutos (Supabase limita los envíos por hora) e intente de nuevo"],
    [/For security purposes, you can only request this after (\d+) seconds?/i, "Por seguridad, espere unos segundos antes de pedir otro correo"],
    [/expired|invalid.*(token|otp)|otp_expired|token.*invalid/i, "El código o enlace es inválido o ya venció. Pida uno nuevo"],
    [/signups? not allowed|signup is disabled|user not found/i, "Ese correo no tiene usuario en la plataforma. Pida al administrador que se lo cree"],
    [/invalid.*email|unable to validate email/i, "El correo no es válido"],
    [/email.*not.*confirmed/i, "El correo aún no está confirmado"],
    [/redirect/i, "La dirección de regreso no está autorizada en Supabase (Authentication → URL Configuration)"],
  ];
  return m.find(([re]) => re.test(msg))?.[1] ?? msg;
}

function restriccion(texto: string) {
  return /constraint "([^"]+)"/.exec(texto)?.[1] ?? "restricción";
}
