const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("zig_grizzly", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
    });

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "zig_grizzly",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "zig_grizzly" is the name you will use in your source code to
                // import this module (e.g. `@import("zig_grizzly")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "zig_grizzly", .module = mod },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // NOTE: Sprint3 demo temporarily disabled due to Zig 0.15 API changes
    // (std.io.getStdOut removed, std.time.sleep changed)
    // See .agents/ZIG_015_COMPATIBILITY.md for details
    // Core database functionality works perfectly - only demo affected
    // const sprint3_exe = b.addExecutable(.{
    //     .name = "zig_grizzly_sprint3",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/main_sprint3.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //         .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
    //     }),
    // });
    // b.installArtifact(sprint3_exe);

    const cardinality_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_cardinality_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_cardinality_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(cardinality_demo_exe);

    const explain_exe = b.addExecutable(.{
        .name = "zig_grizzly_explain",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main_explain.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });

    const phase3_exe = b.addExecutable(.{
        .name = "zig_grizzly_sprint10_phase3",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_sprint10_phase3.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(phase3_exe);

    const scheduler_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_scheduler_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_scheduler_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(scheduler_demo_exe);

    const create_type_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_create_type_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_create_type_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(create_type_demo_exe);

    const test_function_exe = b.addExecutable(.{
        .name = "zig_grizzly_test_function",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_test_function.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(test_function_exe);

    const test_pipe_exe = b.addExecutable(.{
        .name = "zig_grizzly_test_pipe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_test_pipe.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(test_pipe_exe);

    const attach_test_exe = b.addExecutable(.{
        .name = "zig_grizzly_attach_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_attach.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(attach_test_exe);

    const attach_no_semicolon_test_exe = b.addExecutable(.{
        .name = "zig_grizzly_attach_no_semicolon_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test_attach_no_semicolon.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(attach_no_semicolon_test_exe);

    const test_secrets_exe = b.addExecutable(.{
        .name = "zig_grizzly_test_secrets",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_secrets.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(test_secrets_exe);

    const storage_abstraction_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_storage_abstraction_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_storage_abstraction_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(storage_abstraction_demo_exe);

    const memory_store_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_memory_store_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main_memory_store_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(memory_store_demo_exe);

    const column_store_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_column_store_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/column_store_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(column_store_demo_exe);

    const row_store_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_row_store_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/row_store_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(row_store_demo_exe);

    const graph_store_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_graph_store_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/graph_store_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(graph_store_demo_exe);

    const hybrid_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_hybrid_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/hybrid_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(hybrid_demo_exe);

    const secrets_perf_demo_exe = b.addExecutable(.{
        .name = "zig_grizzly_secrets_perf_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/secrets_perf_demo.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
        }),
    });
    b.installArtifact(secrets_perf_demo_exe);

    // const optimization_demo_exe = b.addExecutable(.{
    //     .name = "zig_grizzly_optimization_demo",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("examples/optimization_demo.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //         .imports = &.{.{ .name = "zig_grizzly", .module = mod }},
    //     }),
    // });
    // b.installArtifact(optimization_demo_exe);
    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // NOTE: Sprint3 demo disabled due to Zig 0.15 API changes (std.io.getStdOut removed, std.time.sleep changed)
    // See .agents/ZIG_015_COMPATIBILITY.md for details
    // Run command and artifacts commented out below to avoid errors
    // const run_sprint3_step = b.step("run-sprint3", "Run Sprint 3 demo");
    // const run_sprint3_cmd = b.addRunArtifact(sprint3_exe);
    // run_sprint3_cmd.step.dependOn(b.getInstallStep());
    // run_sprint3_step.dependOn(&run_sprint3_cmd.step);

    const run_cardinality_step = b.step("run-cardinality", "Run Cardinality Estimation demo");
    const run_cardinality_cmd = b.addRunArtifact(cardinality_demo_exe);
    run_cardinality_cmd.step.dependOn(b.getInstallStep());
    run_cardinality_step.dependOn(&run_cardinality_cmd.step);
    if (b.args) |args| {
        run_cardinality_cmd.addArgs(args);
    }

    const run_explain_step = b.step("run-explain", "Run Query Explain demo");
    const run_explain_cmd = b.addRunArtifact(explain_exe);
    run_explain_cmd.step.dependOn(b.getInstallStep());
    run_explain_step.dependOn(&run_explain_cmd.step);
    if (b.args) |args| {
        run_explain_cmd.addArgs(args);
    }

    const run_phase3_step = b.step("run-sprint10-phase3", "Run Sprint 10 Phase 3 - Dependency DAG demo");
    const run_phase3_cmd = b.addRunArtifact(phase3_exe);
    run_phase3_cmd.step.dependOn(b.getInstallStep());
    run_phase3_step.dependOn(&run_phase3_cmd.step);
    if (b.args) |args| {
        run_phase3_cmd.addArgs(args);
    }

    const run_scheduler_step = b.step("run-scheduler-demo", "Run Scheduler demo");
    const run_scheduler_cmd = b.addRunArtifact(scheduler_demo_exe);
    run_scheduler_cmd.step.dependOn(b.getInstallStep());
    run_scheduler_step.dependOn(&run_scheduler_cmd.step);
    if (b.args) |args| {
        run_scheduler_cmd.addArgs(args);
    }

    const run_create_type_step = b.step("run-create-type-demo", "Run CREATE TYPE demo");
    const run_create_type_cmd = b.addRunArtifact(create_type_demo_exe);
    run_create_type_cmd.step.dependOn(b.getInstallStep());
    run_create_type_step.dependOn(&run_create_type_cmd.step);
    if (b.args) |args| {
        run_create_type_cmd.addArgs(args);
    }

    const run_attach_test_step = b.step("run-attach-test", "Run ATTACH SQL test");
    const run_attach_test_cmd = b.addRunArtifact(attach_test_exe);
    run_attach_test_cmd.step.dependOn(b.getInstallStep());
    run_attach_test_step.dependOn(&run_attach_test_cmd.step);
    if (b.args) |args| {
        run_attach_test_cmd.addArgs(args);
    }

    const run_attach_no_semicolon_test_step = b.step("run-attach-no-semicolon-test", "Run ATTACH SQL test without semicolon");
    const run_attach_no_semicolon_test_cmd = b.addRunArtifact(attach_no_semicolon_test_exe);
    run_attach_no_semicolon_test_cmd.step.dependOn(b.getInstallStep());
    run_attach_no_semicolon_test_step.dependOn(&run_attach_no_semicolon_test_cmd.step);
    if (b.args) |args| {
        run_attach_no_semicolon_test_cmd.addArgs(args);
    }

    const run_test_secrets_step = b.step("run-test-secrets", "Run secrets manager tests");
    const run_test_secrets_cmd = b.addRunArtifact(test_secrets_exe);
    run_test_secrets_cmd.step.dependOn(b.getInstallStep());
    run_test_secrets_step.dependOn(&run_test_secrets_cmd.step);
    if (b.args) |args| {
        run_test_secrets_cmd.addArgs(args);
    }

    const run_storage_abstraction_demo_step = b.step("run-storage-abstraction-demo", "Run Storage Abstraction Layer demo");
    const run_storage_abstraction_demo_cmd = b.addRunArtifact(storage_abstraction_demo_exe);
    run_storage_abstraction_demo_cmd.step.dependOn(b.getInstallStep());
    run_storage_abstraction_demo_step.dependOn(&run_storage_abstraction_demo_cmd.step);
    if (b.args) |args| {
        run_storage_abstraction_demo_cmd.addArgs(args);
    }

    const run_memory_store_demo_step = b.step("run-memory-store-demo", "Run Memory Store demo");
    const run_memory_store_demo_cmd = b.addRunArtifact(memory_store_demo_exe);
    run_memory_store_demo_cmd.step.dependOn(b.getInstallStep());
    run_memory_store_demo_step.dependOn(&run_memory_store_demo_cmd.step);
    if (b.args) |args| {
        run_memory_store_demo_cmd.addArgs(args);
    }

    const run_column_store_demo_step = b.step("run-column-store-demo", "Run Column Store demo");
    const run_column_store_demo_cmd = b.addRunArtifact(column_store_demo_exe);
    run_column_store_demo_cmd.step.dependOn(b.getInstallStep());
    run_column_store_demo_step.dependOn(&run_column_store_demo_cmd.step);
    if (b.args) |args| {
        run_column_store_demo_cmd.addArgs(args);
    }

    const run_row_store_demo_step = b.step("run-row-store-demo", "Run Row Store demo");
    const run_row_store_demo_cmd = b.addRunArtifact(row_store_demo_exe);
    run_row_store_demo_cmd.step.dependOn(b.getInstallStep());
    run_row_store_demo_step.dependOn(&run_row_store_demo_cmd.step);
    if (b.args) |args| {
        run_row_store_demo_cmd.addArgs(args);
    }

    const run_graph_store_demo_step = b.step("run-graph-store-demo", "Run Graph Store demo");
    const run_graph_store_demo_cmd = b.addRunArtifact(graph_store_demo_exe);
    run_graph_store_demo_cmd.step.dependOn(b.getInstallStep());
    run_graph_store_demo_step.dependOn(&run_graph_store_demo_cmd.step);
    if (b.args) |args| {
        run_graph_store_demo_cmd.addArgs(args);
    }

    const run_hybrid_demo_step = b.step("run-hybrid-demo", "Run Hybrid Storage Integration demo");
    const run_hybrid_demo_cmd = b.addRunArtifact(hybrid_demo_exe);
    run_hybrid_demo_cmd.step.dependOn(b.getInstallStep());
    run_hybrid_demo_step.dependOn(&run_hybrid_demo_cmd.step);
    if (b.args) |args| {
        run_hybrid_demo_cmd.addArgs(args);
    }

    const run_secrets_perf_demo_step = b.step("run-secrets-perf-demo", "Run Secrets Performance Benchmark");
    const run_secrets_perf_demo_cmd = b.addRunArtifact(secrets_perf_demo_exe);
    run_secrets_perf_demo_cmd.step.dependOn(b.getInstallStep());
    run_secrets_perf_demo_step.dependOn(&run_secrets_perf_demo_cmd.step);
    if (b.args) |args| {
        run_secrets_perf_demo_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}
