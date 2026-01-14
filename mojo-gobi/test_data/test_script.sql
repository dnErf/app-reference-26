CREATE TABLE test_users (
    id INTEGER PRIMARY KEY,
    name TEXT,
    email TEXT
);

INSERT INTO test_users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO test_users (name, email) VALUES ('Bob', 'bob@example.com');

SELECT * FROM test_users;