# Simulation Quick Start

## Available tests
- `instructions_test`: RV32I instruction sanity (ALU, load/store, branch/jump, interrupt return path).
- `fibonacci`: Generates first 10 Fibonacci numbers to DMEM; ISR overwrites `fib[0]` with `fib[2]+fib[4]`.
- `sort_dmem`: Writes unsorted values to DMEM, counts frequencies, and writes sorted output to DMEM.

## Run simulation

### Optional: rebuild imem.hex from source (test.S/test.c)
```bash
make hex TEST=instructions_test
```

### Build and run selected test
```bash
make run TEST=instructions_test
```

## Notes
- `make run TEST=...` now syncs both files before build/run:
  - `sim/tests/<TEST>/imem.hex`
  - `sim/tests/<TEST>/tb.sv`
- If your tool is not in `PATH`, set it explicitly, e.g.:
  - `make VERILATOR=/path/to/verilator run TEST=fibonacci`
