# Triggers in Mojo Grizzly

Triggers allow automatic execution of SQL actions in response to table events like INSERT, UPDATE, DELETE.

## Syntax
CREATE TRIGGER name ON table FOR event EXECUTE action

- event: INSERT, UPDATE, DELETE
- action: SQL statement to execute

## Example
CREATE TRIGGER audit_insert ON users FOR INSERT EXECUTE INSERT INTO audit_log VALUES ('insert', NOW())

DROP TRIGGER audit_insert

## Implementation
- Stored in global triggers list
- Executed after INSERT INTO LAKE operations
- Uses execute_query for actions