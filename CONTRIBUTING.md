# Contributing

This document describes the conventions and required steps for working with this repository.

## Cloning

```bash
git clone https://github.com/friscv/friscv.git
cd friscv
./setup.sh
```

See [Setup](README.md#setup) for what `setup.sh` does.

## Working with git

`main` is the stable branch and should only contain known-good code. **Never commit or open a pull request into `main`.** All work goes into the `dev` branch first.

When starting to work on a new feature, create a branch from `dev` where you can freely commit work-in-progress or untested changes:

```bash
# switch to dev, then create and switch to a new branch
git checkout dev
git checkout -b my-new-feature
```

When the feature works and all tests pass, open a pull request into `dev`. CI runs the linters and all tests on every push, and they must pass before merging.

To pick up changes others made on `dev`, merge `dev` into your branch and make sure all tests pass on the merged version too. If you have git-related problems, Google or an AI agent may be able to help you.

> [!CAUTION]
> **Always recreate the Vivado project after switching to another branch** (`python3 fpga.py project` in `target/xilinx/pynq-z2/`). Using the block design of a different branch can corrupt the Vivado project.

## Adding New RTL Files

Source files are listed in [`Bender.yml`](Bender.yml), in compile order. The simulation, the linters and the Vivado project all read their file list from there.

1. Create the file in the right directory:
   - `rtl/` for core RTL (pipeline, MMU, CSRs, ...)
   - `target/xilinx/pynq-z2/src/` for PYNQ-Z2 SoC RTL (remapper, CLINT, wrappers, ...)
2. Add it to `Bender.yml`. Core files go in the main list, PYNQ-Z2 files under `target: xilinx`.
3. Run `make lint` to check that it is picked up.

**Never create new source files from within Vivado.** Vivado writes them into `build/`, which is not tracked by git.

## Modifying the Block Design

After making any change to the block design in the Vivado GUI, you **must** export it back to Tcl before committing. Only `target/xilinx/pynq-z2/bd/design1.tcl` is tracked, everything in `build/` is thrown away.

```bash
cd target/xilinx/pynq-z2
python3 fpga.py export-bd
```

> [!CAUTION]
> **Never commit without running export-bd after a block design change.** If the Tcl is out of date, other contributors will get a different design when they recreate the project.

## Adding Tests

Every new feature or bug fix needs a test that checks it. Add a directed test in `verif/directed/src/integration_test_<name>.S`. It is picked up automatically by `make run-directed`. A test passes by writing `0xAABBCCDD` to GPIO 0 (`0x4000_0000`), see [docs/TESTING.md](docs/TESTING.md#directed-tests). Look at the existing tests for examples.

## Checklist Before Committing

### 1. Lint

```bash
make lint
```

### 2. Run all tests

```bash
make run-all
```

Every directed and architecture test must pass. See [docs/TESTING.md](docs/TESTING.md) for details. If you changed something Linux uses (MMU, interrupts, atomics, ...), also run `make run-linux`.

### 3. Check that the Vivado project can be recreated

If you changed anything under `target/xilinx/`, clean the project and create it from scratch. This confirms that nothing depends on files that exist only on your machine:

```bash
cd target/xilinx/pynq-z2
python3 fpga.py clean
python3 fpga.py bitstream
```

## Summary of Rules

| Rule | Command |
| ---- | ------- |
| Add new source files to `Bender.yml`, never from the Vivado GUI | — |
| Export the block design after any change to it | `python3 fpga.py export-bd` |
| Add tests for every new feature | — |
| Lint and make sure all tests pass before committing | `make lint && make run-all` |
| Check that the FPGA project builds from a clean state | `python3 fpga.py clean && python3 fpga.py bitstream` |
