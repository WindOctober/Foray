# Foray

Attack Synthesis for DeFi Apps

## Workspace layout

When reproducing the Flare + Foray pipeline, keep the repositories side by side instead of nesting one inside the other:

```text
<workspace>/
  Flare/
  Foray/
```

Flare writes the TFG JSON into this repository's benchmark directory, and Foray consumes it from there.

## Initial Benchmark Collection

We use [DeFiHackLabs](https://github.com/SunWeb3Sec/DeFiHackLabs/tree/main) as the benchmark records.

## Setup by command line (If you are using a Macbook)

Install python 3.11.

```bash
brew install python@3.11
```

Install dependencies.

```bash
pip3 install -q --upgrade pip && pip3 install -q -r ./requirements.txt && \
solc-select install 0.8.21 && solc-select use 0.8.21 && npm install --quiet --save-dev
```

Install Local Foundry

```bash
cd foundry-nightly-20b3da1f22e9f62f6e3406a5d582ad4aa509122c
cargo build --release
```

Add built forge to $PATH

```bash
export PATH="$(pwd)/target/release:$PATH"
```

## Evaluation

### Flare + Foray AES example

From `Flare/`:

```bash
FLARE_SOLC_PATH=.solc-select/artifacts/solc-0.8.22 \
cargo run -- \
  ../Foray/benchmarks/AES/AES.sol \
  --output-tfg ../Foray/benchmarks/AES/aes_tfg.json \
  --extra-compiler-arg=--base-path \
  --extra-compiler-arg="$(cd .. && pwd)" \
  --extra-compiler-arg=--allow-paths \
  --extra-compiler-arg="$(cd .. && pwd)" \
  --extra-compiler-arg=@utils=Flare/benchmark/lib/contracts/@utils \
  --extra-compiler-arg=@openzeppelin=Flare/benchmark/lib/contracts/@openzeppelin \
  --extra-compiler-arg=@uniswapv2=Flare/benchmark/lib/contracts/@uniswapv2 \
  --extra-compiler-arg=@halmos=Flare/benchmark/lib/contracts/@halmos/src \
  --extra-compiler-arg=forge-std=Flare/benchmark/lib/forge-std/src \
  --extra-compiler-arg=ds-test=Flare/benchmark/lib/forge-std/lib/ds-test/src \
  --extra-compiler-arg=benchmarks=Foray/benchmarks
```

From `Foray/`:

```bash
python3 main.py \
  -i benchmarks/AES \
  --tfg benchmarks/AES/aes_tfg.json \
  --tfg-output-bmk benchmarks/AES
```

### Foray eval

This command will evaluate all sketches of a benchmark.

```bash
python3 ./main.py -e -i ./benchmarks/Discover
```

Ablation study

```bash
python3 ./main.py -e --fixed -i ./benchmarks/Discover
```

### Forge eval

This test is for testing whether the ground truth works or not.

```bash
forge test -vvv --match-path ./benchmarks/Discover/Discover.t.sol
```

### Halmos eval

This command will evaluate all sketches of a benchmark.

```bash
python3 ./main.py -ha -i ./benchmarks/Discover
```

(It works with cached results and if you don't want to cache, run `rm ./benchmarks/Discover/result/*.json`)

### Use anvil

```bash
anvil --no-mining --timestamp 0 --base-fee 0 --gas-price 0
```

## Citations

This work is accepted by ACM CCS '24. [Link](https://www.sigsac.org/ccs/CCS2024/program/accepted-papers.html)

## Tips

### Halmos cache

Halmos will use the same cache directory as `foundry.toml`.

Supported cheating codes: [Check this file](https://github.com/a16z/halmos/blob/6be83f77b9b4775c4c27fd262fc4b7faaf8a1a22/src/halmos/sevm.py#L1828)

### Prepare code (We have already prepared it for you, no need to re-run it)

```bash
python3 ./main.py -p -i ./benchmarks/Discover
python3 ./main.py -p -i all
```

### Clean result

```bash
rm ./benchmarks/**/result/eurus_*.json
rm ./benchmarks/**/result/record.json
```

### Clean compile cache

```bash
rm -rf ./.cache
```
