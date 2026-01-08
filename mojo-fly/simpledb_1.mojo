from collections import Dict, List
from os import write_file, read_file
from python from Python

alias ColumnType = Variant[Int, String]

struct ColumnInfo:
    var name: String
    var type_name: String
    var is_primary_key: Bool

struct TableSchema:
    var columns: List[ColumnInfo]
    var column_order: List[String]
    var primary_key_index: Int

    fn __init__(out self):
        self.columns = List[Columninfo]()
        self.column_order = List[String]()
        self.primary_key_index = -1

@fieldwise_init
struct User(Movable, Copyable):
    var id: Int
    var name: String
    var age: Int

    fn display(self):
        print("id: ", self.id, "| name: ", self.name, "| age: ", self.age)

@fieldwise_init
struct SimpleDb(Copyable, Movable):
    var storage: List[User]
    var index: Dict[Int, Int]

    fn get(self, id: Int) -> Optional[User]:
        # for i in range(len(self.storage)):
        #     if self.storage[i].id == id:
        #         return self.storage[i].copy()
        # -
        if id in self.index:
            var idx = self.index[id]
            return self.storage[idx]
        return None

    fn insert(mut self, var user: User):
        for i in range(len(self.storage)):
            if self.storage[i].id == user.id:
                print("error: duplicate id")
                return
        var idx = len(self.storage)
        self.index[user.id] = idx
        self.storage.append(user^)
    
    fn update(mut self, id: Int, new_name: String, new_age: Int):
        for i in range(len(self.storage)):
            if self.storage[i].id == id:
                self.storage[i].name = new_name
                self.storage[i].age = new_age
                print("updated", id)
                return
        print("error: id not found")

    fn delete(mut self, id: Int):
        for i in range(len(self.storage)):
            if self.storage[i].id == id:
                _ = self.storage.pop(i)
                print("delete:", id)
                return
        print("error: id not found")
    
    fn display_all(self):
        print("database contents:")
        for user in self.storage:
            user.display()

    fn save(self, file_name: String):
        var content = ""
        for user in self.storage:
            content += user.to_string() + "\n"
        write_file(file_name, content)
        print("saved to", file_name)

    fn load(self, file_name: String):
        var content = read_file(file_name)
        var lines = content.split("\n")
        for line in lines:
            if line: 
                self.insert(User.from_string(line))

    fn execute_sql_file(self, sql_filename: String, db_filename: String = "mydatabase.db"):
        var sqlite3 = Python.import_module("sqlite3")
        var conn = sqlite3.connect(db_filename)
        var cursor = conn.cursor()

        # read and execute the entire .sql file
        var builtins = Python.import_module("builtins")
        var sql_content = builtins.open(sql_filename, "r").read()

        # runs all sql statements in the file
        cursor.executescript(sql_content)

        conn.commit()
        conn.close()
        print("executed sql file: ", sql_filename)

    fn query_example(self, db_filename: String = "mydatabase.db"):
        var sqlite3 = Python.import_module("sqlite3")
        var conn = sqlite3.connect(db_filename)
        var cursor = conn.cursor()
        cursor.execute("select * from users")
        var rows = cursor.fetchall()
        for row in rows:
            print(row)
        conn.close()    
                
fn main():
    var alice = User(1, "alice", 30)
    alice.display()

    var users = List[User]()
    users.append(User(1, "bob", 25))
    users.append(User(2, "charlie", 35))

    for i in range(len(users)):
        users[i].display()

    var db = SimpleDb(List[User](), Dict[Int, Int]())

    # by using var on insert declaration, this transfer the ownership this the initialize value
    db.insert(User(1,"alice",20))

    # it is the same as
    # var a = User(1, "alice", 20)
    # db.insert(a^)

    var found = db.get(1)
    if found:
        found.value().display()
    
    db.insert(User(2,"bob",30))
    db.update(1,"alicia",31)
    _ = db.get(1)
