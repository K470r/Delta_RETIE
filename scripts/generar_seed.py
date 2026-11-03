"""Genera supabase/seed.sql a partir de los formatos en datos/formatos/.

Uso:  python3 scripts/generar_seed.py > supabase/seed.sql
"""
import json
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def literal(texto: str) -> str:
    return "'" + texto.replace("'", "''") + "'"


f229 = json.loads((RAIZ / "datos/formatos/F229.json").read_text(encoding="utf-8"))

print("-- Generado por scripts/generar_seed.py — no editar a mano")
print("insert into reglamentos (id, nombre, acto, vigente_desde) values")
print("  ('RETIE-2024', 'Reglamento Técnico de Instalaciones Eléctricas 2024', 'Resolución MinEnergía 40117 de 2024', null),")
print("  ('RETIE-2026', 'Reglamento Técnico de Instalaciones Eléctricas 2026', null, null)")
print("on conflict (id) do nothing;\n")
print("insert into formatos (codigo, version, titulo, reglamento_id, alcances, contenido, vigente) values (")
print(f"  {literal(f229['codigo_formato'])}, {literal(f229['version'])},")
print("  'Lista de verificación RETIE — instalaciones de uso final', 'RETIE-2024',")
print("  '{USO_FINAL_RESIDENCIAL,USO_FINAL_NO_RESIDENCIAL}',")
print(f"  {literal(json.dumps(f229['items'], ensure_ascii=False))}::jsonb, true")
print(") on conflict (codigo, version) do nothing;")
