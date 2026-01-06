LOAD JSONL '{"id": 1, "value": 10}
{"id": 2, "value": 20}
{"id": 3, "value": 30}';

CREATE FUNCTION classify(x int64) RETURNS int64 { match x { 0 => 0, 1..10 => 1, _ => 2 } };

CREATE FUNCTION safe_div(a int64, b int64) RETURNS int64 { try a / b catch 0 };

CREATE FUNCTION dynamic(x int64) RETURNS int64 { if x > 5 then 'x * 2' else 'x + 10' end };

SELECT * FROM table WHERE value > 15;

SELECT * FROM table WHERE classify(value) == 1;

SAVE 'table.ipc';