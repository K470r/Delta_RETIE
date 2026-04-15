import pandas as pd
import json
import sys
import os
import unicodedata
import re

# -------- NORMALIZACIÓN --------

def normalize(text):
    if pd.isna(text):
        return ""
    return unicodedata.normalize('NFKD', str(text)) \
        .encode('ascii', errors='ignore') \
        .decode('utf-8') \
        .strip() \
        .upper()

# -------- LIMPIEZA DE TEXTO --------

def clean_text(text):
    if pd.isna(text):
        return ""

    text = str(text)

    text = text.replace("\n", " ")
    text = re.sub(r"\s+", " ", text)

    return text.strip()

# -------- CONFIGURACIÓN --------

COLUMN_MAP = {
    "codigo": ["CODIGO"],
    "articulo": ["REFERENCIA REGULATORIA"],
    "requisito": ["REQUISITO ESENCIAL"],
    "aspecto": ["ASPECTO A EVALUAR"],
    "actividad": ["ACTIVIDAD DE INSPECCION"],
    "descripcion": ["DESCRIPCION"]
}

# -------- FUNCIONES --------

def find_column(df, possible_names):
    for col in df.columns:
        if col in possible_names:
            return col
    return None

def convert_excel(file_path):

    # 🔍 Detectar encabezado
    df = None

    for i in range(10):
        temp_df = pd.read_excel(file_path, header=i)
        cols = [normalize(col) for col in temp_df.columns]

        if "CODIGO" in cols and "DESCRIPCION" in cols:
            df = temp_df
            print(f"Header detectado en fila: {i}")
            break

    if df is None:
        raise Exception("No se pudo detectar la fila de encabezados")

    # 🔥 Normalizar columnas
    df.columns = [normalize(col) for col in df.columns]

    # 🔍 Mapear columnas
    col_codigo = find_column(df, COLUMN_MAP["codigo"])
    col_articulo = find_column(df, COLUMN_MAP["articulo"])
    col_requisito = find_column(df, COLUMN_MAP["requisito"])
    col_aspecto = find_column(df, COLUMN_MAP["aspecto"])
    col_descripcion = find_column(df, COLUMN_MAP["descripcion"])
    col_actividad = find_column(df, COLUMN_MAP["actividad"]) or ""

    print("Columnas detectadas:", df.columns.tolist())

    if not col_codigo or not col_descripcion:
        raise Exception("No se encontraron columnas clave")

    items = []

    for _, row in df.iterrows():

        codigo = clean_text(row.get(col_codigo))

        # 🔹 SECCIÓN
        if codigo == "":
            titulo = clean_text(row.get(col_descripcion))

            if titulo != "" and titulo.lower() != "nan":
                items.append({
                    "tipo": "seccion",
                    "titulo": titulo
                })

        # 🔹 ITEM
        else:
            items.append({
                "tipo": "item",
                "codigo": codigo,
                "articulo": clean_text(row.get(col_articulo)),
                "requisito": clean_text(row.get(col_requisito)),
                "aspecto": clean_text(row.get(col_aspecto)),
                "actividad": clean_text(row.get(col_actividad)),
                "descripcion": clean_text(row.get(col_descripcion))
            })

    # -------- SALIDA --------

    nombre = os.path.splitext(os.path.basename(file_path))[0]

    output = {
        "formato": nombre,
        "version": "1.0",
        "items": items
    }

    output_file = f"{nombre}.json"

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"✔ JSON generado: {output_file}")

# -------- MAIN --------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python excel_to_json.py archivo.xlsx")
    else:
        convert_excel(sys.argv[1])