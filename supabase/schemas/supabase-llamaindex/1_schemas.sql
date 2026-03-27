-- This file includes SQL commands for the llamaindex schema.
-- This schema is used by services of the supabase-llamaindex package.

-- Ensure the schema exists
CREATE SCHEMA IF NOT EXISTS llamaindex;

-- Grant access privileges
GRANT USAGE ON SCHEMA llamaindex TO "anon";
GRANT USAGE ON SCHEMA llamaindex TO "authenticated";
GRANT USAGE ON SCHEMA llamaindex TO "service_role";

