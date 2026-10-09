## eval.json の仕様

この文書は，bitpack_gen.py により生成され，Verilator によるシミュレーションや
実機動作による評価を行う際に参照される，eval.json の仕様を定義するものである．

### トップレベル

以下のキーをもつ辞書とする．

- `"input"`: 辞書のリスト．ユーザ回路の（クロックを除く）入力に関する情報を保持する（後述）．
- `"output"`: 辞書のリスト．ユーザ回路の出力に関する情報を保持する（後述）．
- `"cycle"`: 整数．各評価で，何クロックサイクル回路を動作させるか（つまり，Stochastic Number の長さ）
- `"times"`: 整数．入力の各組合せに対して，何回の評価を行うか
- `"seed"`: 整数．疑似乱数のシード値．

### 入力に関する情報

`"input"` には，以下のキーをもつ辞書のリストを格納する．

- `"name"`: 文字列．信号名
- `"maximum"`: 浮動小数点数．その信号の実数値がとりうる値の最大値
- `"minimum"`: 浮動小数点数．その信号の実数値がとりうる値の最小値
- `"random"`: 真理値．評価においてその信号の値としてランダムな値を使うかどうか
- `"values"`: 浮動小数点数のリスト．`"random"` が偽の場合，その信号の値として使う値の候補．
              `"random"` が真の場合は無視される（通常，空のリストとしておく）

`"name"` がビットベクタの一部の場合は，添字を [] で囲んだものが続く．
また，2つの信号をペアで扱う場合（twoline モードなど）は，`"name"` からは接尾辞（twoline モードならば _p と _m）を省略する．

リストの順序は，ユーザ回路の SystemVerilog 記述における出現順とする．
ただし，入出力がビットベクタの場合は添字が小さいものを先とする．

### 出力に関する情報

`"output"` にも辞書のリストを格納する．
辞書のキーの定義は，`"random"` と `"values"` をもたないことを除き，入力に関する情報と同様である．
リストの順序も，入力のときと同様である．

### bitpack_gen.py が生成する場合

上述した辞書のうち，`"cycle"`，`"times"`，`"random`"，`"values"`，`"seed"` の値は，
評価の前にユーザが変更することを想定している．
そのため，bitpack_gen.py では以下のデフォルト値を入れておく．
（入力すべてをシード 12345 を使ったランダム値として，1,000 サイクルの評価を 1,000 回行う）

- `"cycle"`: `1000`
- `"times"`: `1000`
- `"random"`: `true`
- `"values"`: `[]`
- `"seed"`: `12345`

### bitpack_gen.py が生成する json の例

例えば，ユーザ回路が以下のように定義されている（すなわち，2入力の重みつき平均を求める，
ユニポーラ型 Stochastic Computing 回路である）とする．

```SystemVerilog
module bit_avg (
    input  logic       CLK,
    input  logic [1:0] A,
    input  logic       SEL,
    output logic       AVG);

    assign AVG = (SEL == 1'b0) ? A[0] : A[1];

endmodule
```

このとき期待される json 出力は，以下の通りとなる．

```json
{
    "input": [
        {
            "name": "A[0]",
            "maximum": 1.0,
            "minimum": 0.0,
            "random": true,
            "values": []
        },
        {
            "name": "A[1]",
            "maximum": 1.0,
            "minimum": 0.0,
            "random": true,
            "values": []
        },
        {
            "name": "SEL",
            "maximum": 1.0,
            "minimum": 0.0,
            "random": true,
            "values": []
        }
    ],
    "output": [
        {
            "name": "AVG",
            "maximum": 1.0,
            "minimum": 0.0
        }
    ],
    "cycle": 1000,
    "times": 1000,
    "seed": 12345
}
```