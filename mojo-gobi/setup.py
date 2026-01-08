
from cx_Freeze import setup, Executable

setup(
    name="gobi",
    version="0.1.0",
    description="Mojo Gobi CLI",
    options={
        "build_exe": {
            "packages": ["rich", "cx_Freeze"],
            "include_files": [],
        }
    },
    executables=[Executable("gobi")],
)
