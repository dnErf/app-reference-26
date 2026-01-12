"""
Test Gobi File Format pack/unpack functionality
"""

from gobi_file_format import GobiFileFormat
from python import Python

fn test_gobi_pack_unpack() raises:
    """Test packing and unpacking a simple folder."""
    var os = Python.import_module("os")
    var builtins = Python.import_module("builtins")

    # Create a test directory with some files
    var test_dir = "test_gobi_pack"
    var gobi_file = test_dir + ".gobi"

    try:
        # Create test directory
        os.makedirs(test_dir, exist_ok=True)

        # Create some test files
        var file1 = builtins.open(os.path.join(test_dir, "file1.txt"), "w")
        file1.write("Hello World 1")
        file1.close()

        var file2 = builtins.open(os.path.join(test_dir, "file2.txt"), "w")
        file2.write("Hello World 2")
        file2.close()

        # Create a subdirectory
        var sub_dir = os.path.join(test_dir, "subdir")
        os.makedirs(sub_dir, exist_ok=True)

        var file3 = builtins.open(os.path.join(sub_dir, "file3.txt"), "w")
        file3.write("Hello World 3")
        file3.close()

        print("Created test directory with files")

        # Pack the directory
        var gobi_format = GobiFileFormat()
        var pack_success = gobi_format.pack(test_dir, gobi_file)

        if pack_success:
            print("Successfully packed directory to .gobi file")

            # Unpack the .gobi file
            var unpack_dir = test_dir + "_unpacked"
            var unpack_success = gobi_format.unpack(gobi_file, unpack_dir)

            if unpack_success:
                print("Successfully unpacked .gobi file")

                # Verify files exist
                var unpacked_file1 = os.path.join(unpack_dir, "file1.txt")
                var unpacked_file2 = os.path.join(unpack_dir, "file2.txt")
                var unpacked_file3 = os.path.join(unpack_dir, "subdir", "file3.txt")

                if os.path.exists(unpacked_file1) and os.path.exists(unpacked_file2) and os.path.exists(unpacked_file3):
                    print("All files successfully unpacked!")

                    # Check file contents
                    var f1 = builtins.open(unpacked_file1, "r")
                    var content1 = f1.read()
                    f1.close()

                    var f2 = builtins.open(unpacked_file2, "r")
                    var content2 = f2.read()
                    f2.close()

                    var f3 = builtins.open(unpacked_file3, "r")
                    var content3 = f3.read()
                    f3.close()

                    if content1 == "Hello World 1" and content2 == "Hello World 2" and content3 == "Hello World 3":
                        print("File contents verified - test PASSED!")
                    else:
                        print("File contents do not match - test FAILED!")
                else:
                    print("Some files missing after unpack - test FAILED!")
            else:
                print("Unpack failed - test FAILED!")
        else:
            print("Pack failed - test FAILED!")

    except:
        print("Test failed with exception")

    # Cleanup
    try:
        import shutil
        var shutil_mod = Python.import_module("shutil")
        if os.path.exists(test_dir):
            shutil_mod.rmtree(test_dir)
        if os.path.exists(gobi_file):
            os.remove(gobi_file)
        if os.path.exists(test_dir + "_unpacked"):
            shutil_mod.rmtree(test_dir + "_unpacked")
        print("Cleanup completed")
    except:
        print("Cleanup failed")

fn main() raises:
    print("Testing Gobi File Format...")
    test_gobi_pack_unpack()
    print("Test completed")