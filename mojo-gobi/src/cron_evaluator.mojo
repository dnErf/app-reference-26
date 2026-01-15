"""
Cron Expression Evaluator for PL-GRIZZLY Job Scheduling Engine
Supports standard cron syntax: * * * * *
- Minute (0-59)
- Hour (0-23)
- Day of month (1-31)
- Month (1-12)
- Day of week (0-6, Sunday=0)
"""

from python import Python, PythonObject
from collections import List
from sys import argv

struct CronExpression:
    """Represents a parsed cron expression."""
    var minute: List[Int]
    var hour: List[Int]
    var day_of_month: List[Int]
    var month: List[Int]
    var day_of_week: List[Int]

    fn __init__(out self, expression: String) raises:
        """Parse cron expression string into components."""
        self.minute = List[Int]()
        self.hour = List[Int]()
        self.day_of_month = List[Int]()
        self.month = List[Int]()
        self.day_of_week = List[Int]()
        
        var parts = expression.split(" ")
        if len(parts) != 5:
            raise Error("Invalid cron expression: must have 5 parts")

        self.minute = self._parse_field(String(parts[0]), 0, 59)
        self.hour = self._parse_field(String(parts[1]), 0, 23)
        self.day_of_month = self._parse_field(String(parts[2]), 1, 31)
        self.month = self._parse_field(String(parts[3]), 1, 12)
        self.day_of_week = self._parse_field(String(parts[4]), 0, 6)

    fn _parse_field(self, field: String, min_val: Int, max_val: Int) raises -> List[Int]:
        """Parse a single cron field (supports *, numbers, ranges, lists)."""
        var result = List[Int]()

        if field == "*":
            for i in range(min_val, max_val + 1):
                result.append(i)
        elif field.find(",") != -1:
            # List of values
            var values = field.split(",")
            for val in values:
                var parsed = self._parse_single_value(String(val), min_val, max_val)
                result.append(parsed)
        elif field.find("-") != -1:
            # Range
            var range_parts = field.split("-")
            if len(range_parts) != 2:
                raise Error("Invalid range in cron field: " + field)
            var start = atol(range_parts[0])
            var end = atol(range_parts[1])
            if start < min_val or end > max_val or start > end:
                raise Error("Invalid range values in cron field: " + field)
            for i in range(start, end + 1):
                result.append(i)
        else:
            # Single value
            var parsed = self._parse_single_value(field, min_val, max_val)
            result.append(parsed)

        return result ^

    fn _parse_single_value(self, value: String, min_val: Int, max_val: Int) raises -> Int:
        """Parse a single numeric value."""
        var num = atol(value)
        if num < min_val or num > max_val:
            raise Error("Value out of range: " + value)
        return num

    fn matches(self, minute: Int, hour: Int, day: Int, month: Int, weekday: Int) -> Bool:
        """Check if the given time matches this cron expression."""
        return (minute in self.minute and
                hour in self.hour and
                day in self.day_of_month and
                month in self.month and
                weekday in self.day_of_week)

fn evaluate_cron(expression: String, current_time: PythonObject) raises -> Bool:
    """Evaluate if current time matches the cron expression."""
    var cron = CronExpression(expression)

    # Extract time components from Python datetime
    var py_int = Python.import_module("builtins").int
    var minute = atol(String(py_int(current_time.minute)))
    var hour = atol(String(py_int(current_time.hour)))
    var day = atol(String(py_int(current_time.day)))
    var month = atol(String(py_int(current_time.month)))
    var weekday = atol(String(py_int(current_time.weekday())))  # Monday=0, Sunday=6

    return cron.matches(minute, hour, day, month, weekday)

fn get_next_run_time(expression: String, from_time: PythonObject) raises -> PythonObject:
    """Calculate the next run time for a cron expression."""
    var datetime_mod = Python.import_module("datetime")
    var timedelta_mod = Python.import_module("datetime").timedelta

    var cron = CronExpression(expression)
    var current = from_time

    # Simple implementation: check next 24 hours in minute intervals
    # In production, this should be more efficient
    for i in range(1440):  # 24 hours * 60 minutes
        var py_int = Python.import_module("builtins").int
        var minute = atol(String(py_int(current.minute)))
        var hour = atol(String(py_int(current.hour)))
        var day = atol(String(py_int(current.day)))
        var month = atol(String(py_int(current.month)))
        var weekday = atol(String(py_int(current.weekday())))

        if cron.matches(minute, hour, day, month, weekday):
            return current

        # Add one minute
        current = current + timedelta_mod(minutes=1)

    raise Error("No matching time found within 24 hours")
