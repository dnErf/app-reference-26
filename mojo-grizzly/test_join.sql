CREATE TABLE users (id INT, name TEXT);
INSERT INTO users VALUES (1, 'Alice');
INSERT INTO users VALUES (2, 'Bob');
INSERT INTO users VALUES (3, 'Charlie');
CREATE TABLE orders (id INT, user_id INT, product TEXT);
INSERT INTO orders VALUES (1, 1, 'Laptop');
INSERT INTO orders VALUES (2, 1, 'Mouse');
INSERT INTO orders VALUES (3, 2, 'Keyboard');
SELECT * FROM users JOIN orders ON users.id = orders.user_id;
