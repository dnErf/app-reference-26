from collections import List

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

    fn get(self, id: Int) -> Optional[User]:
        for i in range(len(self.storage)):
            if self.storage[i].id == id:
                return self.storage[i].copy()
        return None

    fn insert(mut self, var user: User):
        for i in range(len(self.storage)):
            if self.storage[i].id == user.id:
                print("error: duplicate id")
                return
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
                
fn main():
    var alice = User(1, "alice", 30)
    alice.display()

    var users = List[User]()
    users.append(User(1, "bob", 25))
    users.append(User(2, "charlie", 35))

    for i in range(len(users)):
        users[i].display()

    var db = SimpleDb(List[User]())

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
