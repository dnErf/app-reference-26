## basic struct
```
struct User:
    var id: Int
    var name: String
    var age: Int

    fn __init__(out self, id: Int, name: String, age: Int):
        self.id = id
        self.name = name
        self.age = age

    fn display(self):
        print("id: ", self.id, "| name: ", self.name, "| age: ", self.age)

@fieldwise_init
struct User:
    var id: Int
    var name: String
    var age: Int

    fn display(self):
        print("id: ", self.id, "| name: ", self.name, "| age: ", self.age)

@fieldwise_init
struct MyPair:
    var first: Int
    var second: Int

    # expression needs to be mutable
    fn increment_with_error(self):
        self.first += 1 
    fn increment_corrected(mut self):
        self.first += 1
        self.second += 1
```

## not movable & copyable by default
```
# 
var a = MyPair(1,1)
# error a not ImplicitlyCopyable
var b = a
# error a not Copyable
var c = a.copy()
# error a not Movable
var d = a^

# this will error: bind type 'User' to trait 'Copyable & Movable'
var users = List[User]()

# declare User struct as
struct User(Copyable, Movable):
    var id: Int
    var name: string
    # ...

# other traits possible
#   ImplicitlyCopyable -> removes the use of .copy()

```

## receiving arguments
```
@fieldwise_init
struct SimpleDb(Copyable, Movable):
    var storage: List[User]
    fn insert(mut self, var user: User):
        for i in range(len(self.storage)):
            if self.storage[i].id == user.id:
                print("error: duplicate id")
                return
        self.storage.append(user^)

var db = SimpleDb(List[User]())
db.insert(User(1,"alice",20))

# or
var a = User(2, "alice", 20)
db.insert(a^)
```
