-- Campus Innovate — notificaciones, invitaciones a grupos, chat de grupo y
-- directorio de usuarios.
--
-- Ejecutar una sola vez en la Consola SQL de ROBLE, con el contrato del
-- proyecto seleccionado, DESPUÉS de 2026_grupos_y_valoraciones.sql. La consola
-- elimina los comentarios SQL antes de ejecutar y permite correr varias
-- sentencias juntas.
--
-- No toca ninguna tabla existente: son cuatro tablas nuevas.

-- ---------------------------------------------------- directorio de usuarios
-- ROBLE no permite listar cuentas, así que cada persona se registra aquí al
-- abrir la app. Es lo que busca la pantalla "Invitar al grupo".

CREATE TABLE app_users (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  user_id text NOT NULL UNIQUE,
  name text NOT NULL,
  email text NOT NULL,
  updated_at timestamp NOT NULL
);

-- ------------------------------------------------- invitaciones a un grupo
-- Una fila existe solo mientras espera respuesta: al aceptarla o rechazarla se
-- borra, y lo ocurrido le llega a quien invitó como notificación.

CREATE TABLE group_invitations (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  group_id text NOT NULL,
  group_name text NOT NULL,
  inviter_id text NOT NULL,
  inviter_name text NOT NULL,
  invitee_id text NOT NULL,
  invitee_name text NOT NULL,
  created_at timestamp NOT NULL,
  UNIQUE (group_id, invitee_id)
);

-- --------------------------------------------------------- chat del grupo

CREATE TABLE group_messages (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  group_id text NOT NULL,
  sender_id text NOT NULL,
  sender_name text NOT NULL,
  body text NOT NULL,
  created_at timestamp NOT NULL
);

-- ------------------------------------------------------- notificaciones
-- Una fila por destinatario. is_read es 0 (sin leer) o 1 (leída).

CREATE TABLE notifications (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  recipient_id text NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  is_read int4 NOT NULL,
  created_at timestamp NOT NULL
);
