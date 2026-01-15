## Godi Idea Concept
- an embeded lakehouse like hudi (https://hudi.apache.org/docs/overview) but with capabilities of sqlmesh (https://sqlmesh.readthedocs.io/en/stable/#core-features) to act as a transformation staging area
    - uses pyarrow ORC
    - uses dynamic merkle b+ tree with universal compaction strategy
    - uses sha-256
    - uses BLOB comparable to Azure ADS Lake Gen 2 (https://docs.azure.cn/en-us/hdinsight/overview-data-lake-storage-gen2)
    - saved database to lakehouse format
        - `[name].gobi`
        - schema
        - tables
        - files
        - etc
- cli application that uses rich
    - when `gobi repl` it will launch repl
    - when `gobi init [folder]` it will initialize the root folder or targer folder the database
        - `gobi pack [folder]` will make the folder be on a accessible single file like sqlite `.db` files
        - `gobi unpack` the lakehouse will be shown as folder and files
        - like zip and unzip

- sql dailect: programming language PL-GRIZZLY
    - lexer
    - parser
    - interpreter
        - semantics analysis
        - profiler
    - jit compiler
    - python like
    - linq query (https://learn.microsoft.com/en-us/dotnet/csharp/linq/get-started/introduction-to-linq-queries)

- type secret
```
INSTALL httpfs;
LOAD io, math, httpfs;

-- Attach Files
ATTACH 'other_database.db'
ATTACH 'same_folder.sql'

-- highly secured encrypted secret text
TYPE SECRET AS Github_Token (kind: 'https', key: 'authentication', value: 'bearer ghp_your_github_token_here');

WITH (select * from CTE) SELECT * FROM 'https://api.github.com/repos/owner/repo/issues' WITH SECRET ['github_token','other_secret']

-- Export data to authenticated endpoint
COPY (SELECT * FROM users WHERE active = true) 
TO 'https://api.example.com/upload' WITH SECRET ['one_value_secret_like_array']

-- List all secrets
SHOW SECRETS

-- Delete a secret
DROP SECRET secret_name 
```

- Basic Imports
```pl-grizzly
INSTALL other_maker_extension
LOAD math, io, other_maker_extension
```

- Struct Definitions
    - it would be nice if type inference would be good as go programming language
        - https://go.dev/blog/type-inference
```pl-grizzly
-- Struct Literals (Object Syntax)
-- the type is struct unless was able to infer a type Person
let user = {name: "John", age: 30, active: true}

-- 1
type struct as Person(name string, age int, active boolean)

-- 2
type struct as Person(name string, age int, active boolean) {
    name: "John", 
    age: 30, 
    active: true
}

-- 3
let user = type struct as Person {
    name: "John", 
    age: 30, 
    active: true
}

-- 4
let user = type struct :: Person {
    name: "John", 
    age: 30, 
    active: true
}
```

- @TypeOf
    - special temporarary function to check the type of variable or column that return the string value of the type
    - @TypeOf(column) or @TypeOf(variable)

- THEN
```
from query
select index_row_number, target
then
    -- statements
    if row_number == target then
        -- catch like match
        x = try complicated(target) catch {
            SomeException => ...
        }
    elif target != target then
        --- statements
    else
        --- statements

-- or using pattern matching

from query
select index_row_number, target
then
    -- pattern matching
    match target {
        ... 
    }  
```

- match expression
```
let some_var = MATCH user.tier {
    "premium" -> "VIP",
    "basic" -> "Standard",
    _ -> "Unknown"
}

from plans
select tier match {
    "premium" -> "vip",
    "basic" -> "standard",
    _ -> "unknow"
}
where user == "john"
```

- read supported pyarrow format
    - installed by default extension
    - can infer the type of what has been read
```
select * from '/folder/file.orc'
select * from 'file.parquet'
select * from 'file.feather'
select * from 'file.json'

type struct as Person (id int, name string)
let x = select name from 'employees.json'
@TypeOf(x) -- this should automatically infer the type if the type has been declared
```

- COPY supported pyarrow format
    - can infer the type of what has been read
    - orc, parquet, feather
```
--- imports data from an external file into an existing table
COPY 'test.orc' TO test_table

-- exports data from Table to an external CSV, Parquet, JSON or BLOB file
COPY test_table TO 'test.orc'
```

- CTE Basic
```
-- basic
WITH cte AS (SELECT 42 AS x)
SELECT * FROM cte

WITH cte AS (SELECT 42 AS x)
FROM cte SELECT * 
```

- JOIN
```
SELECT n.*, r.*
FROM l_nations n
JOIN l_regions r ON (n_regionkey = r_regionkey);

SELECT n.*, r.*
FROM l_nations n
LEFT JOIN l_regions r ON (n_regionkey = r_regionkey);

SELECT n.*, r.*
FROM l_nations n
RIGHT JOIN l_regions r ON (n_regionkey = r_regionkey);

SELECT n.*, r.*
FROM l_nations n
FULL JOIN l_regions r ON (n_regionkey = r_regionkey);

SELECT n.*, r.*
FROM l_nations n
ANTI JOIN l_regions r ON (n_regionkey = r_regionkey);
```

- WHERE
```
SELECT *
FROM tbl
WHERE id = 3 OR id = 7
```

-- ORDER BY
```
SELECT zip_code
FROM addresses
ORDER BY DESC zip_code

SELECT zip_code
FROM addresses
ORDER BY DSC zip_code

SELECT zip_code
FROM addresses
ORDER BY ASC 
```

- global Lakehouse Daemon
    - `gobi mount <folder>`

- IPC Communication Layer
    - https://arrow.apache.org/docs/python/ipc.html


- function declaration
```
-- aync by default
function name <ReceiverType> () 
raises Exception
returns void|type
as async|sync
{

}

-- `as` is optional
function name <ReceiverType> () 
raises Exception
returns void|type
{

}
```

- Stored Procedures Engine
```
upsert procedure procedure_name as 
-- procedure type
<{
    -- to to have a basic kind and applicable from https://sqlmesh.readthedocs.io/en/stable/concepts/models/overview/
    kind: ''
    sched: ['procedure_can_declare_schedule_using_its_name','and_also_refence_a_shedule']
}> 
(param1 TryToInferType, param2 type)
raises SomeException 
returns void|type
{

}
```

- Triggers System
```sql
-- fix behaviour `FOR EACH ROW`
upsert TRIGGER as trigger_name (
    timing: 'before|after',
    event: 'insert|update|delete|upsert',
    target: 'collections',
    -- can only execute pipeline or procedure
    exe: 'pipeline|procedure' 
)
```

- Cron Scheduler
```sql
-- cron syntax
upsert SCHEDULE as schedule_name (
    -- can be pre-configured word or cron
    sched: '0 0 * * *',
    exe: 'pipeline|procedure',
    call: 'function',
)
```

- Pipeline
```sql
-- pipeline syntax
-- all schedule or procedure mention the name are automatically belongs to the pipeline
-- for now Pipeline will provide isolated configurations and resources
upsert Pipeline as pipeline_name ( ... )
```

- text based user interface
    - simillar to https://duckdb.org/2025/03/12/duckdb-ui
