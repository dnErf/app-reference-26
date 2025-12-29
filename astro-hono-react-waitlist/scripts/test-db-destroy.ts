(async () => {
    await Bun.file("test.sqlite").delete()
    console.log("test db destroyed")
})();