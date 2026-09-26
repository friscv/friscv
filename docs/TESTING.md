# Testing

All tests run on the Verilator model of the core in `target/sim/`. The tools come from the Nix shell (see [Setup](../README.md#setup)).

## Simulation Configurations

The core has parameters that turn features on or off. The simulation is built once per configuration, from the files in `target/sim/configs/`:

| Config | Description |
| ------ | ----------- |
| `full` | RV32IMA, M/S/U modes, Sv32, PMP, fast multiplier. Everything enabled |
| `full-itermul` | Same as `full`, but with the iterative (slow) multiplier |
| `embedded` | RV32IM, M/U modes, no MMU or PMP |
| `frisc` | RV32IM, M mode only |
| `minimal` | RV32E, M mode only |

To build one by hand:

```bash
make -C target/sim core CONFIG=embedded
```

## Directed Tests

Directed tests are RISC-V assembly programs in `verif/directed/src/integration_test_*.S`. Each one checks a part of the ISA (atomics, CSRs, paging, PMP, interrupts, etc.). A test passes when it writes `0xAABBCCDD` to GPIO 0 (`0x4000_0000`) and signals simulation end by writing anything to `0x5000_0000`.

From the repo root:

```bash
make run-directed
```

This assembles all tests and runs them on the `full` and `full-itermul` configs. It exits non-zero if any test fails.

To build a single test into `verif/directed/prog/prog.{elf,bin,dis}`:

```bash
make -C verif/directed prog TEST=integration_test_Zaamo
```

## Architecture Tests

The [riscv-arch-test](https://github.com/riscv/riscv-arch-test) suite checks the core against a reference model. The suite is cloned into `verif/arch-test/riscv-arch-test/` on the first build.

```bash
make build-act  # build the test ELFs (slow, only needed once)
make run-act    # run them on the core
```

Every run pairs a simulation config with a test config. By default all of `full:full full-itermul:full embedded:embedded frisc:frisc` are run. To run only one:

```bash
make run-act ACT_RUNS=embedded:embedded
```

All architecture tests should pass before a feature is considered complete.

## Everything

```bash
make run-all  # directed + architecture tests
```

The same tests, together with the [Linux and apheleiaOS boot](LINUX.md), run in CI on every push.
