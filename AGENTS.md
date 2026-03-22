# Agent Notes (Foray)

## New Benchmark Onboarding

Use this workflow when wiring a benchmark into `Foray/benchmarks/<NAME>/` so it can consume a Flare-generated TFG.

### Backend input boundary

The current backend consumes:

- `Foray/benchmarks/<NAME>/_config.yaml` for harness metadata
- `Foray/benchmarks/<NAME>/flare_tfg.json` for frontend-derived graph input

It does not need `Foray/benchmarks/<NAME>/config.yaml` for the active Flare frontend path.

### `_config.yaml` purpose

`_config.yaml` is still required for the current harness and should contain only backend-facing setup data:

- `project_name`
- `ctrt_name2cls`
- `ctrt_name2deploy`
- `extra_deployments_before`
- `extra_deployments`
- `extra_statements`
- `attack_goal_str`
- `roles`
- `pattern` if needed

Keep this file as harness metadata, not as a semantic oracle.

### What not to add back

Do not introduce or preserve:

- `extra_actions`
- benchmark-specific manual candidate shortcuts
- groundtruth-driven candidate generation
- hand-authored frontend semantics that are already supposed to come from `flare_tfg.json`

If historical benchmark files still contain groundtruth, treat it as dead metadata unless the user explicitly asks for legacy reproduction.

### Minimum onboarding steps

1. Create `Foray/benchmarks/<NAME>/`.
2. Add `_config.yaml` with the minimum harness metadata needed to build the benchmark test harness.
3. Ensure the benchmark source / vendor files required by the harness are present.
4. Generate `flare_tfg.json` through the Flare runner, not by hand.
5. Run:
   - `bash Foray/scripts/run_flare_tfg_benchmark.sh <NAME>`
6. Confirm that candidate generation and later solver stages are reading `flare_tfg.json` rather than relying on removed manual action paths.

### Benchmark set registration

There is no separate benchmark list to update for the normal runner.

- `python3 main.py -i all ...` discovers benchmarks by scanning `Foray/benchmarks/*` for `_config.yaml`
- therefore adding a benchmark to the runnable set means creating a valid benchmark directory with `_config.yaml`

### Validation checklist

Before declaring the benchmark onboarded on the Foray side:

- `_config.yaml` exists
- `resolve_project_name` matches the benchmark directory name
- `bash Foray/scripts/run_flare_tfg_benchmark.sh <NAME>` reaches the prepare stage
- no dependency on `extra_actions`
- no dependency on groundtruth for candidate generation
