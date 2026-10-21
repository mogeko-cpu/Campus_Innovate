-- Campus Innovate — gestión de proyectos: estado del proyecto, roles en el
-- equipo y tablero de tareas.
--
-- Ejecutar una sola vez en la Consola SQL de ROBLE, con el contrato del
-- proyecto seleccionado, DESPUÉS de 2026_notificaciones_invitaciones_chat.sql.
--
-- Solo agrega: tres columnas que pueden quedar nulas en las filas que ya
-- existen y una tabla nueva. Las filas viejas siguen funcionando sin tocarlas:
-- un proyecto sin estado se lee como "Idea" y un integrante sin rol se lee como
-- líder si es el creador e integrante si no.

-- ----------------------------------------------------- estado del proyecto
-- idea, inProgress, paused o done. Solo idea e inProgress reciben solicitudes.

ALTER TABLE listings ADD COLUMN status text;

-- --------------------------------------------------------- roles del equipo
-- leader, member o mentor. user_name viaja copiado porque ROBLE no hace JOIN y
-- la lista del equipo necesitaría una lectura por persona.

ALTER TABLE listing_members ADD COLUMN role text;
ALTER TABLE listing_members ADD COLUMN user_name text;

-- ------------------------------------------------------ tablero de tareas
-- Una fila por tarea: mover una tarjeta es actualizar su fila, y dos personas
-- moviendo dos tarjetas a la vez no se pisan. status es la columna del tablero
-- (todo, doing, done). due_date es solo el día (AAAA-MM-DD) en texto, para no
-- arrastrar la zona horaria de un timestamp. assignee_id vacío = sin asignar.

CREATE TABLE listing_tasks (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  title text NOT NULL,
  assignee_id text NOT NULL,
  assignee_name text NOT NULL,
  due_date text,
  status text NOT NULL,
  created_by text NOT NULL,
  created_at timestamp NOT NULL
);
