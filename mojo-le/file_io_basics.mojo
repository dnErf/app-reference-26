"""
Mojo File I/O Basics Example

This file demonstrates basic file input/output operations in Mojo:
- Reading from files
- Writing to files
- Text processing
- File operations with error handling
- Python interop for file operations (current Mojo limitation)
"""

from python import Python

# 1. Basic file reading functions
fn read_text_file(filename: String) raises -> String:
    """Read entire text file content."""
    try:
        Python.add_to_path(".")
        var file = Python.evaluate("open('" + filename + "', 'r')")
        var content = file.read()
        file.close()
        return String(content)
    except:
        raise Error("Failed to read file: " + filename)

# 2. Basic file writing functions
fn write_text_file(filename: String, content: String) raises:
    """Write text content to file."""
    try:
        Python.add_to_path(".")
        var file = Python.evaluate("open('" + filename + "', 'w')")
        file.write(content)
        file.close()
    except:
        raise Error("Failed to write to file: " + filename)

fn append_text_file(filename: String, content: String) raises:
    """Append text content to file."""
    try:
        Python.add_to_path(".")
        var file = Python.evaluate("open('" + filename + "', 'a')")
        file.write(content)
        file.close()
    except:
        raise Error("Failed to append to file: " + filename)

# 3. Text processing functions
fn count_words(text: String) -> Int:
    """Count words in text."""
    if text == "":
        return 0

    # Simple word counting (split by spaces)
    var words = 0
    var in_word = False

    for i in range(len(text)):
        var char = text[i]
        var is_space = char == " "
        var is_newline = char == "\n"
        var is_tab = char == "\t"

        if not is_space and not is_newline and not is_tab:
            if not in_word:
                words += 1
                in_word = True
        else:
            in_word = False

    return words

fn count_lines(text: String) -> Int:
    """Count lines in text."""
    if text == "":
        return 0

    var lines = 1  # At least one line if text is not empty
    for i in range(len(text)):
        if text[i] == "\n":
            lines += 1

    return lines

fn find_word(text: String, word: String) -> Bool:
    """Check if word exists in text (case-sensitive)."""
    if word == "" or len(word) > len(text):
        return False

    # Simple substring search
    for i in range(len(text) - len(word) + 1):
        var found = True
        for j in range(len(word)):
            if text[i + j] != word[j]:
                found = False
                break
        if found:
            return True

    return False

# 4. File processing functions
fn process_text_file(filename: String) raises -> String:
    """Process a text file and return statistics."""
    var content = read_text_file(filename)
    var word_count = count_words(content)
    var line_count = count_lines(content)

    return "File: " + filename + "\n" +
           "Characters: " + String(len(content)) + "\n" +
           "Words: " + String(word_count) + "\n" +
           "Lines: " + String(line_count)

fn main() raises:
    print("=== Mojo File I/O Basics ===\n")

    # Create sample data files for demonstration
    print("Creating sample files...")

    # Create a sample text file
    var sample_text = """Hello World!
This is a sample text file.
It contains multiple lines.
Each line has some text.
Mojo is a programming language.
File I/O is important for data processing."""

    write_text_file("sample.txt", sample_text)
    print("Created sample.txt\n")

    # 1. Basic file reading
    print("1. Basic File Reading")
    try:
        var content = read_text_file("sample.txt")
        print("File content (first 100 chars):")
        print(content[:100] + "...\n")
    except e:
        print("Error reading file:", e)

    # 2. File statistics
    print("2. File Statistics")
    try:
        var stats = process_text_file("sample.txt")
        print(stats + "\n")
    except e:
        print("Error processing file:", e)

    # 3. Text search
    print("3. Text Search")
    try:
        var content = read_text_file("sample.txt")
        var found_mojo = find_word(content, "Mojo")
        var found_python = find_word(content, "Python")

        print("Word 'Mojo' found:", found_mojo)
        print("Word 'Python' found:", found_python, "\n")
    except e:
        print("Error searching file:", e)

    # 4. File appending
    print("4. File Appending")
    try:
        append_text_file("sample.txt", "\nThis line was appended!")
        var updated_content = read_text_file("sample.txt")
        print("File now ends with appended content")
        print("Total characters:", len(updated_content), "\n")
    except e:
        print("Error appending to file:", e)

    # 5. Error handling
    print("5. Error Handling")
    try:
        var _content = read_text_file("nonexistent.txt")
    except e:
        print("Expected error reading nonexistent file:", e)

    print("\n=== File I/O Examples Completed ===")
    print("Note: Current Mojo version uses Python interop for file operations")
    print("Native file I/O APIs may be available in future versions")

    # Cleanup
    print("\nCleaning up sample files...")
    try:
        Python.evaluate("import os; os.remove('sample.txt')")
        print("Sample files cleaned up")
    except:
        print("Could not clean up files")