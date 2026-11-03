/**
 * Estructura de requisitos de NTC-ISO/IEC 17020:2012 (numerales 4 a 8).
 * Se usa como columna vertebral del tablero de cumplimiento: cada control
 * del sistema se asocia a uno de estos numerales.
 */
export type Numeral = {
  codigo: string;
  titulo: string;
  capitulo: string;
  resumen: string;
};

export const CAPITULOS: Record<string, string> = {
  "4": "Requisitos generales",
  "5": "Requisitos relativos a la estructura",
  "6": "Requisitos relativos a los recursos",
  "7": "Requisitos de los procesos",
  "8": "Requisitos del sistema de gestión",
};

export const NUMERALES_17020: Numeral[] = [
  { codigo: "4.1", capitulo: "4", titulo: "Imparcialidad e independencia",
    resumen: "Identificar y gestionar riesgos a la imparcialidad; compromiso de la dirección; independencia según tipo A, B o C." },
  { codigo: "4.2", capitulo: "4", titulo: "Confidencialidad",
    resumen: "Acuerdos jurídicamente exigibles para proteger la información obtenida en las inspecciones." },
  { codigo: "5.1", capitulo: "5", titulo: "Requisitos administrativos",
    resumen: "Entidad legal identificable, documentación de servicios y seguro de responsabilidad civil adecuado." },
  { codigo: "5.2", capitulo: "5", titulo: "Organización y gestión",
    resumen: "Estructura, director técnico y suplente, descripciones de cargo y responsabilidades definidas." },
  { codigo: "6.1", capitulo: "6", titulo: "Personal",
    resumen: "Competencia, autorización formal, formación, supervisión y monitoreo en sitio de los inspectores." },
  { codigo: "6.2", capitulo: "6", titulo: "Instalaciones y equipos",
    resumen: "Equipos identificados, calibrados con trazabilidad metrológica, verificados y mantenidos." },
  { codigo: "6.3", capitulo: "6", titulo: "Subcontratación",
    resumen: "Subcontratistas competentes, evaluados y con consentimiento del cliente." },
  { codigo: "7.1", capitulo: "7", titulo: "Métodos y procedimientos de inspección",
    resumen: "Métodos definidos y vigentes, revisión de solicitudes y contratos, uso de formatos controlados." },
  { codigo: "7.2", capitulo: "7", titulo: "Manipulación de ítems y muestras",
    resumen: "Identificación inequívoca de los ítems inspeccionados y registro de anomalías." },
  { codigo: "7.3", capitulo: "7", titulo: "Registros de inspección",
    resumen: "Registros suficientes para evaluar la inspección e identificar a quien la realizó." },
  { codigo: "7.4", capitulo: "7", titulo: "Informes y certificados de inspección",
    resumen: "Contenido mínimo, revisión y autorización, control de modificaciones y emisión oportuna." },
  { codigo: "7.5", capitulo: "7", titulo: "Quejas y apelaciones",
    resumen: "Proceso documentado y disponible para recibir, evaluar y decidir quejas y apelaciones." },
  { codigo: "7.6", capitulo: "7", titulo: "Proceso de quejas y apelaciones",
    resumen: "Acuse de recibo, seguimiento, decisión por personal no involucrado y notificación formal." },
  { codigo: "8.1", capitulo: "8", titulo: "Opciones del sistema de gestión",
    resumen: "Opción A (requisitos 8.2 a 8.8) u opción B (ISO 9001)." },
  { codigo: "8.2", capitulo: "8", titulo: "Documentación del sistema de gestión",
    resumen: "Políticas y objetivos documentados, comunicados y entendidos." },
  { codigo: "8.3", capitulo: "8", titulo: "Control de documentos",
    resumen: "Aprobación, revisión, versiones vigentes disponibles y obsoletos identificados." },
  { codigo: "8.4", capitulo: "8", titulo: "Control de registros",
    resumen: "Identificación, almacenamiento, protección, recuperación, retención y disposición." },
  { codigo: "8.5", capitulo: "8", titulo: "Revisión por la dirección",
    resumen: "Revisión planificada con entradas y salidas definidas." },
  { codigo: "8.6", capitulo: "8", titulo: "Auditorías internas",
    resumen: "Programa que cubra todos los requisitos, auditores independientes del área auditada." },
  { codigo: "8.7", capitulo: "8", titulo: "Acciones correctivas",
    resumen: "Análisis de causa, acciones oportunas y verificación de eficacia." },
  { codigo: "8.8", capitulo: "8", titulo: "Acciones preventivas",
    resumen: "Identificar no conformidades potenciales y tomar acciones para evitarlas." },
];
