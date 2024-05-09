CREATE TYPE calendar.location_kind AS ENUM (
    'physical',
    'virtual',
    'global'
);

ALTER TYPE calendar.location_kind OWNER TO :owner_role;