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