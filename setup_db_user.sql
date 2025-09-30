-- Create Azure AD user for the managed identity
SELECT * FROM pgaadauth_create_principal('azidxxm5ylfv2vwj6', false, false);

-- Grant connect privilege to the database
GRANT CONNECT ON DATABASE assetmanager TO "azidxxm5ylfv2vwj6";

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO "azidxxm5ylfv2vwj6";

-- Grant create privileges on schema public
GRANT CREATE ON SCHEMA public TO "azidxxm5ylfv2vwj6";

-- Grant all privileges on all tables in public schema
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "azidxxm5ylfv2vwj6";

-- Grant all privileges on all sequences in public schema
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "azidxxm5ylfv2vwj6";

-- Set default privileges for future tables and sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "azidxxm5ylfv2vwj6";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "azidxxm5ylfv2vwj6";