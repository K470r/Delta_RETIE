"""Genera supabase/seed.sql: reglamentos y catálogo de actividades acreditables.

Fuentes: datos/alcances/*.json (extraídos de las notas técnicas de ONAC).
Uso:  python3 scripts/generar_seed.py > supabase/seed.sql
"""
import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def lit(t):
    return "null" if t is None else "'" + str(t).replace("'", "''") + "'"


def arr(xs):
    return "array[" + ", ".join(lit(x) for x in xs) + "]::text[]"


print("-- Generado por scripts/generar_seed.py — no editar a mano\n")
for archivo in sorted((RAIZ / "datos/alcances").glob("*.json")):
    d = json.loads(archivo.read_text(encoding="utf-8"))
    print(f"-- {archivo.name}")
    print("insert into reglamentos (id, nombre, acto, fuente_alcances) values")
    print(f"  ({lit(d['reglamento'])}, {lit(d['nombre'])}, {lit(d['acto'])}, {lit(d['fuente'])})")
    print("on conflict (id) do update set nombre = excluded.nombre, acto = excluded.acto, fuente_alcances = excluded.fuente_alcances;\n")
    print("insert into actividades (codigo, reglamento_id, grupo, nombre, referencias) values")
    filas = [f"  ({lit(a['codigo'])}, {lit(d['reglamento'])}, {lit(a['grupo'])}, {lit(a['nombre'])}, {arr(a['referencias'])})"
             for a in d["actividades"]]
    print(",\n".join(filas))
    print("on conflict (codigo) do update set grupo = excluded.grupo, nombre = excluded.nombre, referencias = excluded.referencias;\n")

print("insert into reglamentos (id, nombre) values ('RETIE-2026', 'Reglamento Técnico de Instalaciones Eléctricas – RETIE 2026')")
print("on conflict (id) do nothing;")
