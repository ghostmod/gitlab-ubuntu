-- ------------------------------------------------------------------
-- Create required data for GitLab
-- ------------------------------------------------------------------

SET sql_mode='ANSI_QUOTES';

-- Workaround: DROP USER IF EXISTS still not supported
GRANT USAGE ON *.* TO "gitlab"@"localhost";
DROP USER
	"gitlab"@"localhost";

-- Drop the database if exists
DROP DATABASE IF EXISTS
	"gitlabhq_production";

-- Create our user
CREATE USER
	"gitlab"@"localhost"
	IDENTIFIED BY 'gitlab,';

-- Create GitLab db
CREATE DATABASE  IF NOT EXISTS
	"gitlabhq_production"
	DEFAULT CHARACTER SET 'utf8'
	COLLATE 'utf8_unicode_ci';

-- Grant privileges
GRANT SELECT, LOCK TABLES,
	INSERT, UPDATE, DELETE,
	CREATE, DROP, INDEX, ALTER
	ON "gitlabhq_production".*
	TO "gitlab"@"localhost"

-- ------------------------------------------------------------------
-- EOF
-- ------------------------------------------------------------------
