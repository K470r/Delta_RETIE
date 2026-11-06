-- ============================================================================
-- Ultra RETIE — 0016 Generación hasta 1.000 V AC y 1.500 V DC: todo como la categoría g
--
-- Decisión (reemplaza la regla de experiencia de 0015): para generación con FNCE, AGPE y GD
-- y generación con varias fuentes hasta 1.000 V AC y 1.500 V DC sirve el certificado de la g y
-- CUALQUIER experiencia de la g, con los 2 años que exige la g (y para el director técnico, lo
-- que exige el RETIE en la g). Por encima de esos valores sigue la categoría a.
-- Se puede ejecutar más de una vez sin dañar nada.
-- ============================================================================

update actividades set experiencia_en_actividad = null, experiencia_anios = null
 where variante_de is not null and tension = 'hasta_1000ac_1500dc'
   and (experiencia_en_actividad is not null or experiencia_anios is not null);

select 'Migración 0016 aplicada: generación hasta 1.000 V con certificado y experiencia de la g' as resultado;
