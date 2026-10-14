# eval.json loader for BitPack Pynq evaluation
# 2026-10-14 Naoki F., AIT
# New BSD license is applied. See COPYING for more details.

"""bitpack_eval_config.py

Loader and validator for the eval.json configuration file
(see doc/eval_json_spec.md).

Equivalent to the C++ implementation in
verilator/testbench/bitpack_eval_config.hpp (EvalConfig).
"""

import json
from typing import List


class BitPackEvalInputDesc:
    """Description of one input signal in eval.json."""

    def __init__(self, name: str, has_negative: bool, denominator: float,
                 random: bool, values: List[float] = None) -> None:
        self.name = name
        self.has_negative = has_negative
        self.denominator = denominator
        self.random = random
        # used only when random is False
        self.values = values if values is not None else []

    def __repr__(self) -> str:
        return ("BitPackEvalInputDesc(name={!r}, has_negative={!r}, "
                "denominator={!r}, random={!r}, values={!r})"
                .format(self.name, self.has_negative, self.denominator,
                        self.random, self.values))


class BitPackEvalOutputDesc:
    """Description of one output signal in eval.json."""

    def __init__(self, name: str, has_negative: bool, denominator: float) -> None:
        self.name = name
        self.has_negative = has_negative
        self.denominator = denominator

    def __repr__(self) -> str:
        return ("BitPackEvalOutputDesc(name={!r}, has_negative={!r}, "
                "denominator={!r})"
                .format(self.name, self.has_negative, self.denominator))


class BitPackEvalConfig:
    """Loads and validates eval.json (see doc/eval_json_spec.md).

    Raises RuntimeError on failure (file not found, parse error,
    or invalid content).
    """

    def __init__(self, filename: str) -> None:
        try:
            with open(filename, "r", encoding="utf-8") as f:
                j = json.load(f)
        except OSError as e:
            raise RuntimeError(f"failed to open {filename}: {e}") from e
        except json.JSONDecodeError as e:
            raise RuntimeError(f"failed to parse {filename}: {e}") from e

        if not isinstance(j, dict):
            raise RuntimeError(f"invalid top-level structure in {filename}")

        # "input"
        if not isinstance(j.get("input"), list):
            raise RuntimeError(f'missing or invalid "input" in {filename}')
        self._inputs: List[BitPackEvalInputDesc] = []
        for item in j["input"]:
            d = BitPackEvalInputDesc(
                name=item["name"],
                has_negative=item["has_negative"],
                denominator=item["denominator"],
                random=item["random"],
            )
            if isinstance(item.get("values"), list):
                d.values = [float(v) for v in item["values"]]
            if d.denominator <= 0.0:
                raise RuntimeError(f'invalid "denominator" for input {d.name}')
            if not d.random and not d.values:
                raise RuntimeError(
                    f'input {d.name} has no "values" although "random" is false')
            self._inputs.append(d)

        # "output"
        if not isinstance(j.get("output"), list):
            raise RuntimeError(f'missing or invalid "output" in {filename}')
        self._outputs: List[BitPackEvalOutputDesc] = []
        for item in j["output"]:
            d = BitPackEvalOutputDesc(
                name=item["name"],
                has_negative=item["has_negative"],
                denominator=item["denominator"],
            )
            if d.denominator <= 0.0:
                raise RuntimeError(f'invalid "denominator" for output {d.name}')
            self._outputs.append(d)

        # "cycle", "times", "seed"
        self._cycle = int(j["cycle"])
        self._times = int(j["times"])
        self._seed = int(j["seed"]) & 0xFFFFFFFF
        if self._cycle <= 0:
            raise RuntimeError(f'invalid "cycle" in {filename}')
        if self._times <= 0:
            raise RuntimeError(f'invalid "times" in {filename}')

    @property
    def inputs(self) -> List[BitPackEvalInputDesc]:
        return self._inputs

    @property
    def outputs(self) -> List[BitPackEvalOutputDesc]:
        return self._outputs

    @property
    def cycle(self) -> int:
        return self._cycle

    @property
    def times(self) -> int:
        return self._times

    @property
    def seed(self) -> int:
        return self._seed

    def combos_per_round(self) -> int:
        """Number of evaluations per round: the size of the Cartesian
        product of the candidate sets of all inputs (a random input
        contributes exactly one candidate)."""
        n = 1
        for d in self._inputs:
            n *= (1 if d.random else len(d.values))
        return n


if __name__ == "__main__":
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else "../../verilator/eval.json"
    cfg = BitPackEvalConfig(path)
    print(f"cycle: {cfg.cycle}")
    print(f"times: {cfg.times}")
    print(f"seed:  {cfg.seed}")
    print(f"combos per round: {cfg.combos_per_round()}")
    print("inputs:")
    for d in cfg.inputs:
        print(f"  {d.name}: has_negative={d.has_negative}, "
              f"denominator={d.denominator}, random={d.random}, "
              f"values={d.values}")
    print("outputs:")
    for d in cfg.outputs:
        print(f"  {d.name}: has_negative={d.has_negative}, "
              f"denominator={d.denominator}")
