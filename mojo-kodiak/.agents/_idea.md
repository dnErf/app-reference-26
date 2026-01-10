using mojo create database with two store with real code and implementation
    - in memory
    - block
        - stored in wal

- use pyarrow feather for data format
- for storage
    - use b plus tree for indexing
    - use fractal tree to manages write buffers and metadata indexing

- create cli command
    - to open repl
    - see list of extensions

- enchance pl-grizzly
    - a new sql dialect
    - as small as lua
    - type receivers like go programming language
```
-- can now set variables
set myvar1 = "mytable"
SELECT myvar FROM {mytable} WHERE id = 1

-- support different basic data types
set myjson = {
    -- i can make a comment
    "key1ofjson": "myvaalue"
}

-- select and from can interchange its position
SELET * FROM mytable WHERE id = 1
FROM mytable SELECT * WHERE id = 1

CREATE TYPE MyStruct AS STRUCT(k : SomeType, l : SomeType);
CREATE TYPE MyStruck AS STRUCT {
    k: SomeType,
    l: SomeType
}
CREATE TYPE ValidationError AS EXCEPTION ("Data validation failed");

-- MyReceiver 
CREATE FUNCTION [MyReceiver] myfunctionname (argname : MyStruct)
RETURNS FLOAT
RAISE MyNewException
{
    -- i am a funtion here
    price * 0.8
}
```

- #file:_plan.md plan to be full featured and comparable to https://docs.getdbt.com/docs/introduction and https://sqlmesh.readthedocs.io/en/stable/ . take note to focus on that for now.

- plan to have an scm extension, simple like fossil (https://fossil-scm.org/home/doc/tip/www/fossil-v-git.wiki) and merculiar (https://www.mercurial-scm.org/)
    - will use ORC data format
    - can be pack or unpack into a database
    - after user `kodiak extension install scm`. user will be able to use `kodiak scm ini`. and this will setup the virtual schema workspace environment
    - implement ULID
    - implement UUID v5 
    - implement BLOB comparable to S3 features and ADS Lake Gen2 feature this will be also the BLOB that will be used in lakehouse extension 
    - implement project structure with models, seeds, tests and sqls
    - implement virtual schema workspace environments for development isolation
    - create package management for shared models and macros

- lakehouse extension
    - will use PARQUET
    - compatible with apache iceberg (https://iceberg.apache.org/) wuth apache hudi features (https://hudi.apache.org/)
