# ResetPls — banco de interfaz, 2026-11-03

42 PNGs: 2 idiomas × 3 escenarios × 7 superficies. Abrir index.html para comparar.

- green: Claude sesión 28%, semana 32%; Codex semana 37%, margen.
- amber: Claude sesión 78%, semana 32%; Codex semana 76%, riesgo.
- red: Claude sesión 96%, semana 32%; Codex semana 94%, riesgo alto.
- App: 1320×2868. Widgets: exportación a escala 3×.
- Datos de muestra, historial sintético y vistas SwiftUI actuales. Sin cuentas ni datos personales.
- Son recursos nativos para montar la ficha; no capturas completas de SpringBoard. App sin barra de estado del sistema. Widgets de bloqueo sobre transparencia, sin reloj/fondo/controles del sistema. Validar la apariencia final en su host WidgetKit al montar la pantalla de bloqueo.
- Se respetan los colores del código: el aro pequeño se mantiene verde y el riesgo cambia el mensaje; los widgets de bloqueo son monocromos. No se han recoloreado imágenes.
- Renderizado UIKit para dashboard y SwiftUI ImageRenderer para widgets; inyección de familia únicamente en copia temporal del código de widgets.
- Archivos de la app y pruebas restaurados tras la exportación. Ningún cambio de producto ni nueva build publicada por esta tarea.
- Log: /tmp/resetpls-interface-capture.log. Test InterfaceCaptureTests completado correctamente.

Actualización aprobada: las capturas amber-app ES/EN combinan Claude sesión 78% (ámbar) y Codex semana 37% (verde). Las demás variantes se conservan.
