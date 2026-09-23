# Ritmo

Prototipo funcional de agenda inteligente para gestionar actividades con horarios reales, conflictos y recuperación médica.

## Ejecutar

Instala las dependencias y levanta el servidor de desarrollo:

```powershell
npm install
npm run dev
```

La conexión inicial con Supabase usa `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY` en `.env.local`. No uses una clave `service_role` en el navegador.

El esquema completo de Supabase está en [supabase-schema.sql](AUTIMATIZADOR/supabase-schema.sql). Pégalo completo en **Supabase → SQL Editor** y pulsa **Run**.

### Autenticación

La aplicación ya incluye:

- Inicio de sesión con correo y contraseña.
- Registro de nuevas cuentas.
- Recuperación de contraseña por correo.
- Sesión persistente en el navegador.
- Cierre de sesión.
- Bloqueo de la agenda hasta autenticar al usuario.

En Supabase activa únicamente **Authentication → Providers → Email**. En **Authentication → URL Configuration** agrega como Site URL y Redirect URL la URL final de Netlify, por ejemplo `https://tu-sitio.netlify.app/`.

En Netlify configura estas variables en **Site configuration → Environment variables**:

```text
VITE_SUPABASE_URL=https://gkyhlveuooxjdodyiztp.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=tu_clave_publishable
```

## Desplegar en Netlify

Este proyecto ya incluye `netlify.toml` con la configuración de Vite:

- Build command: `npm run build`
- Publish directory: `dist`
- Redirección SPA hacia `index.html`

En Netlify ve a **Site configuration → Environment variables** y agrega:

```text
VITE_SUPABASE_URL=https://gkyhlveuooxjdodyiztp.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=tu_clave_publishable
```

Después conecta el repositorio desde **Add new site → Import an existing project**. Netlify detectará `netlify.toml` automáticamente.

Después abre la URL que muestra Vite, normalmente `http://localhost:5173`.

También puedes abrir `index.html` directamente en el navegador para usar la versión sin servidor.

## Incluye

- Vista semanal responsive con actividades, espacios libres y períodos de recuperación.
- Base de conocimiento de actividades con nombre libre, categoría, hora de inicio y hora de fin.
- Duración calculada automáticamente como `horaFin - horaInicio`.
- Recuperación automática únicamente para procedimientos médicos, con sugerencias editables.
- Categorías nuevas con color persistente y colores distintos por nombre al filtrar una sola categoría.
- Categorías fijas Estudio, Gym y Salud, más categorías personalizadas eliminables con borrado en cascada.
- Categoría fija Otros para actividades sin categoría específica.
- Creación de categorías desde la barra lateral con nombre y color.
- Actividades Otros recurrentes por días de la semana y rango de fechas.
- Indicador de margen semanal sincronizado con la vista de disponibilidad.
- Modal de actividades con altura máxima y desplazamiento interno para formularios extensos.
- Selector horario de 15 minutos en formato 24 horas.
- Calendario de 24 horas con indicador de hora actual y scroll automático.
- Actividades agrupadas cronológicamente por día.
- Eliminación protegida mediante confirmación y alcance para bloques recurrentes.
- Módulo de semestres para generar clases de teoría y laboratorios en fechas semanales.
- Cada ocurrencia académica queda vinculada a su materia y semestre para eliminarla en bloque.
- Alta de actividades con comprobación de conflictos.
- Sugerencia de la fecha libre más cercana cuando no existe disponibilidad.
- Resumen de horas por categoría.
- Persistencia local mediante `localStorage`.

## Próxima etapa para producción

Para sincronización en tiempo real entre computador y teléfono habría que conectar este frontend a una API y una base de datos (por ejemplo, Supabase o Firebase), añadir autenticación y reemplazar `localStorage` por suscripciones a cambios.
