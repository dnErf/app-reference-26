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
