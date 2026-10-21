-- Campus Innovate — archivos del equipo y solicitudes de mentoría.
--
-- Ejecutar una sola vez en la Consola SQL de ROBLE, con el contrato del
-- proyecto seleccionado, DESPUÉS de 2026_gestion_de_proyectos.sql. La consola
-- elimina los comentarios SQL antes de ejecutar y permite correr varias
-- sentencias juntas.
--
-- No toca ninguna tabla existente: son dos tablas nuevas. El estado
-- "cancelado" de las tareas no necesita cambios: listing_tasks.status ya es
-- text y ahora también guarda 'cancelled'.

-- ------------------------------------------------- archivos del equipo
-- Una fila por archivo compartido. kind = 'file': los bytes están en el bucket
-- del proyecto (Configuración → Almacenamiento) y storage_id es su id en ROBLE.
-- kind = 'link': url es la dirección y storage_id queda vacío.

CREATE TABLE project_files (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  name text NOT NULL,
  kind text NOT NULL,
  storage_id text NOT NULL,
  url text NOT NULL,
  mime_type text NOT NULL,
  size_bytes int4 NOT NULL,
  uploader_id text NOT NULL,
  uploader_name text NOT NULL,
  created_at timestamp NOT NULL
);

-- ------------------------------------------- solicitudes de mentoría
-- Una fila por proyecto como máximo, y solo mientras espera respuesta: al
-- aceptar, la persona entra a listing_members con role = 'mentor' y la fila se
-- borra; al rechazar o cancelar, también se borra. El UNIQUE es lo que impide
-- dos solicitudes simultáneas para el mismo proyecto.

CREATE TABLE mentorship_requests (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL UNIQUE,
  listing_title text NOT NULL,
  requester_id text NOT NULL,
  requester_name text NOT NULL,
  mentor_id text NOT NULL,
  mentor_name text NOT NULL,
  message text NOT NULL,
  created_at timestamp NOT NULL
);
