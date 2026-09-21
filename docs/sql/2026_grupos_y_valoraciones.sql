-- Campus Innovate — grupos, valoraciones, vistas y comentarios.
--
-- Ejecutar una sola vez en la Consola SQL de ROBLE, con el contrato del
-- proyecto seleccionado. La consola elimina los comentarios SQL antes de
-- ejecutar y permite correr varias sentencias juntas.
--
-- Nada de esto borra datos: las tres tablas que ya existen (listings,
-- listing_members, join_requests) siguen igual, y a listings solo se le agregan
-- dos columnas que pueden quedar nulas en las filas viejas.

-- ---------------------------------------------------------------- grupos

CREATE TABLE groups (
  _id UUID PRIMARY KEY NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  owner_id text NOT NULL,
  owner_name text NOT NULL,
  created_at timestamp NOT NULL
);

CREATE TABLE group_members (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  group_id text NOT NULL,
  user_id text NOT NULL,
  user_name text NOT NULL,
  joined_at timestamp NOT NULL,
  UNIQUE (group_id, user_id)
);

CREATE TABLE group_requests (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  group_id text NOT NULL,
  applicant_id text NOT NULL,
  applicant_name text NOT NULL,
  message text NOT NULL,
  status text NOT NULL,
  created_at timestamp NOT NULL,
  UNIQUE (group_id, applicant_id)
);

-- ------------------------------------------- el proyecto pertenece al grupo

ALTER TABLE listings ADD COLUMN group_id text;
ALTER TABLE listings ADD COLUMN group_name text;

-- ------------------------------- valoraciones, vistas y comentarios

CREATE TABLE listing_reactions (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  group_id text NOT NULL,
  user_id text NOT NULL,
  value int4 NOT NULL,
  created_at timestamp NOT NULL,
  UNIQUE (listing_id, user_id)
);

CREATE TABLE listing_views (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  group_id text NOT NULL,
  user_id text NOT NULL,
  viewed_at timestamp NOT NULL,
  UNIQUE (listing_id, user_id)
);

CREATE TABLE listing_comments (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  group_id text NOT NULL,
  author_id text NOT NULL,
  author_name text NOT NULL,
  body text NOT NULL,
  created_at timestamp NOT NULL
);
