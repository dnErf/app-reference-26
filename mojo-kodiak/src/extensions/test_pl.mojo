from database import Database

fn main() raises:
    print("Starting test")
    var db = Database()

    # Test arithmetic
    try:
        var result1 = db.eval_pl_expression("1 + 2 * 3")
        print("1 + 2 * 3 =", result1)
    except e:
        print("Error in arithmetic:", String(e))

    # Test array
    try:
        var result2 = db.eval_pl_expression("[1, 2, 3]")
        print("[1, 2, 3] =", result2)
    except e:
        print("Error in array:", String(e))

    # Test map
    try:
        var result3 = db.eval_pl_expression("{a: 1, b: 2}")
        print("{a: 1, b: 2} =", result3)
    except e:
        print("Error in map:", String(e))

    # Test variable
    db.variables["x"] = "42"
    try:
        var result4 = db.eval_pl_expression("x")
        print("x =", result4)
    except e:
        print("Error in variable:", String(e))

    # Test complex
    try:
        var result5 = db.eval_pl_expression("[1 + 2, x]")
        print("[1 + 2, x] =", result5)
    except e:
        print("Error in complex:", String(e))

    # Test receiver
    db.variables["arr"] = "[1,2,3]"
    try:
        var receiver_result = db.eval_pl_expression("arr.length()")
        print("arr.length() =", receiver_result)
    except e:
        print("Error with receiver:", String(e))