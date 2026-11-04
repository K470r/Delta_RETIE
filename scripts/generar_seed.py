"""Genera supabase/seed.sql: reglamentos, categorías de competencia y actividades acreditables.

Fuentes (versionadas, para comparar con RETIE/RETILAP 2026):
  datos/alcances/*.json   — actividades acreditables (notas técnicas ONAC)
  datos/requisitos/*.json — categorías y requisitos del personal técnico
Uso:  python3 scripts/generar_seed.py > supabase/seed.sql
"""
import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def lit(t):
    if t is None:
        return "null"
    if isinstance(t, bool):
        return "true" if t else "false"
    if isinstance(t, (int, float)):
        return str(t)
    return "'" + str(t).replace("'", "''") + "'"


def arr(xs):
    return "array[" + ", ".join(lit(x) for x in xs) + "]::text[]"


print("-- Generado por scripts/generar_seed.py — no editar a mano\n")
for archivo in sorted((RAIZ / "datos/alcances").glob("*.json")):
    d = json.loads(archivo.read_text(encoding="utf-8"))
    rq = json.loads((RAIZ / "datos/requisitos" / archivo.name).read_text(encoding="utf-8"))
    dt = rq["directorTecnico"]
    print(f"-- {archivo.name}")
    print("""insert into reglamentos (id, nombre, acto, fuente_alcances, fuente_requisitos, exige_certificado,
  vigencia_certificado_anios, seguimiento_mes, matricula_requerida, requiere_posgrado_iluminacion,
  experiencia_por_categoria, tipos_experiencia_tecnica, dt_experiencia_total, dt_total_estricta,
  dt_experiencia_direccion, dt_tipos_direccion, dt_por_categoria) values""")
    print("  (" + ", ".join([
        lit(d["reglamento"]), lit(d["nombre"]), lit(d["acto"]), lit(d["fuente"]), lit(rq["fuente"]),
        lit(rq["exigeCertificado"]), lit(rq["vigenciaCertificadoAnios"]), lit(rq["seguimientoMes"]),
        lit(rq["matriculaRequerida"]), lit(rq["formacionEspecializada"] is not None),
        lit(rq["experienciaPorCategoria"]), arr(rq["tiposExperienciaTecnica"]),
        lit(dt["experienciaTotalAnios"]), lit(dt["experienciaTotalEstricta"]),
        lit(dt["experienciaDireccionAnios"]), arr(dt["tiposExperienciaDireccion"]), lit(dt["porCategoria"]),
    ]) + ")")
    print("on conflict (id) do nothing;\n")
    print("insert into categorias_competencia (reglamento_id, codigo, nombre, experiencia_inspector_anios, requiere_categoria_vigente) values")
    print(",\n".join(
        f"  ({lit(d['reglamento'])}, {lit(c['codigo'])}, {lit(c['nombre'])}, {lit(c['experienciaInspectorAnios'])}, {lit(c.get('requiereCategoriaVigente'))})"
        for c in rq["categorias"]))
    print("on conflict do nothing;\n")
    cat_de = {a: c["codigo"] for c in rq["categorias"] for a in c["actividades"]}
    area_de = rq.get("profundizacionPorActividad", {})
    print("insert into actividades (codigo, reglamento_id, grupo, nombre, referencias, categoria, area_profundizacion) values")
    print(",\n".join(
        f"  ({lit(a['codigo'])}, {lit(d['reglamento'])}, {lit(a['grupo'])}, {lit(a['nombre'])}, {arr(a['referencias'])}, "
        f"{lit(cat_de[a['codigo']])}, {lit(area_de.get(a['codigo']))})"
        for a in d["actividades"]))
    print("on conflict (codigo) do nothing;\n")

print("insert into reglamentos (id, nombre) values ('RETIE-2026', 'Reglamento Técnico de Instalaciones Eléctricas – RETIE 2026')")
print("on conflict (id) do nothing;")
