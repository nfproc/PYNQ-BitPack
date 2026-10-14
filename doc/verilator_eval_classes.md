# Verilator テストベンチのクラス設計

この文書は，[`verilator_eval_spec.md`](verilator_eval_spec.md) に従って `verilator`
フォルダに作成する C++ テストベンチ（`bitpack_test.cpp`）のクラス構成を定義するものである．
`bitpack_lib_rand.hpp` / `bitpack_lib_rand.cpp`（`BitPackRandom`）は既存のため，
ここでは触れない．

## 全体構成

```
testbench/
├── bitpack_test.cpp        # main()：評価ループ本体
├── bitpack_eval_config.hpp # EvalConfig
├── bitpack_eval_uut.hpp    # UserWrapper（UUT ドライバ）
├── bitpack_lib_io.hpp      # EvalInput, EvalInputVector, EvalOutput, EvalOutputVector
└── bitpack_lib_rand.{hpp,cpp}  # 既存
```

実装はヘッダ内インライン（テンプレートなしの単一 TU 構成）にする想定であり，
`.cpp` を増やさずに `bitpack_test.cpp` から `#include` する．
（規模が大きくなったら `.cpp` 化してもよい．）

```
main (bitpack_test.cpp)
 ├── EvalConfig        : eval.json の読み込み・検証，組合せ枚数の算出
 ├── EvalInputVector   : 入力の抽象化（実数値 ⇔ binary_value/seed）
 ├── EvalOutputVector  : 出力の抽象化（カウンタ値 → 実数値）
 ├── UserWrapper       : Vuser_wrapper のラップ（クロック・リセット・
 │                       GO/DONE ハンドシェイク・FIFO への直接アクセス）
 └── (標準ライブラリ)  : std::ofstream で results.txt / input.txt / output.txt を出力
```

ログ出力は `std::ofstream` 3 つを `main` が直接管理する（`times` 回ループの中で
逐次書き出すため，専用のログクラスは設けない）．

## EvalConfig（bitpack_eval_config.hpp）

`eval.json` のパースと検証を行う．`nlohmann/json` を用いる．

```cpp
struct EvalInputDesc {
    std::string name;          // "name"
    bool        has_negative;  // "has_negative"
    double      denominator;   // "denominator"
    bool        random;        // "random"
    std::vector<double> values;  // "values"（random が偽の場合のみ使用）
};

struct EvalOutputDesc {
    std::string name;
    bool        has_negative;
    double      denominator;
};

class EvalConfig {
public:
    // eval.json を読み込み・検証する．失敗時は例外（std::runtime_error）を送出
    explicit EvalConfig(const std::string& filename);

    const std::vector<EvalInputDesc>&  inputs()  const;
    const std::vector<EvalOutputDesc>& outputs() const;
    int  cycle() const;   // "cycle"  → SIZE
    int  times() const;   // "times"
    uint32_t seed() const;  // "seed"

    // 1 周の評価回数 = 各入力の候補集合のデカルト積の大きさ
    // （random が真の入力は候補 1 つ = USE_RANDOM）
    size_t combos_per_round() const;

private:
    std::vector<EvalInputDesc>  m_inputs;
    std::vector<EvalOutputDesc> m_outputs;
    int        m_cycle;
    int        m_times;
    uint32_t   m_seed;
};
```

検証項目：`cycle` > 0，`times` > 0，`random` が偽の入力は `values` が空でない，
`denominator` > 0．

## EvalInput / EvalInputVector（bitpack_lib_io.hpp）

[`pynq/lib/bitpack_lib_io.py`](../pynq/lib/bitpack_lib_io.py) の `BitPackInput` /
`BitPackInputVector` の C++ 版．1 回の回路動作に対する入力の値（実数値または
`USE_RANDOM`）と，`user_wrapper` が読み取る 2 ワード（`binary_value`, `seed`）
の生成を担当する．

```cpp
// USE_RANDOM を表す特別な値（enum クラス）
enum class UseRandom { USE_RANDOM };
using InputValue = std::variant<double, UseRandom>;

class EvalInput {
public:
    EvalInput(bool has_negative, double denominator);

    // 値の設定．USE_RANDOM ならランダム値を要求
    void set_value(InputValue v);

    // 疑似乱数源の設定（USE_RANDOM の値と seed の生成に使う）
    void set_rng(BitPackRandom* rng);

    // binary_value の計算
    //  - USE_RANDOM: 抽選結果（has_negative が偽なら上位 1 ビットをクリア）
    //  - 固定値: value/denominator * 0x7fffffff（負なら 0x80000000 を加算）
    //    範囲外は端に丸める
    uint32_t binary_value();

    // seed の計算（抽選結果が 0 なら再抽選して 0 を避ける）
    uint32_t seed();

    // 実数値（results.txt 出力用）
    //  - USE_RANDOM: binary_value から逆変換した値
    //  - 固定値: 設定された値（丸め前）
    double real_value() const;

private:
    bool   m_has_negative;
    double m_denominator;
    bool   m_random;
    double m_value;      // 固定値
    uint32_t m_binary;   // binary_value() のキャッシュ
    uint32_t m_seed;     // seed() のキャッシュ
    BitPackRandom* m_rng;
};

class EvalInputVector {
public:
    explicit EvalInputVector(const std::vector<EvalInputDesc>& descs);

    void set_rng(BitPackRandom* rng);
    EvalInput& operator[](size_t i);
    size_t size() const;

    // 1 回の回路動作で user_wrapper が読み取る 2*size() ワードの配列を生成する．
    // 順序: 入力の i 番目の binary_value の直後に i 番目の seed が続く
    // （input_port_t の配列としてのレイアウト）
    std::vector<uint32_t> as_words() const;

private:
    std::vector<EvalInput> m_ins;
};
```

`as_words()` 内部の疑似乱数の消費順序（仕様「入力の組合せについて」に従う）：

1. 入力の順序で `binary_value()` を呼び，`USE_RANDOM` の入力はここで疑似乱数を消費
2. 入力の順序で `seed()` を呼び，疑似乱数を消費

なお，ワード配列への格納は 1 の結果を `words[2*i]` に，2 の結果を `words[2*i+1]` に
行う（`user_wrapper` は `count == i*2` で `binary_value` を，`count == i*2+1` で
`seed` を各入力の SNG に書き込むため）．

## EvalOutput / EvalOutputVector（bitpack_lib_io.hpp）

`BitPackOutput` / `BitPackOutputVector` の C++ 版．

```cpp
class EvalOutput {
public:
    EvalOutput(bool has_negative, double denominator);

    // カウンタ値（32 ビット符号付き）から実数値へ変換
    // value = count / (cycle * denominator)
    // （has_negative は変換式に影響しないが，results.txt の表示範囲の
    //   確認用に保持する）
    void set_from_count(int32_t count, int cycle);
    double real_value() const;

private:
    bool   m_has_negative;
    double m_denominator;
    double m_value;
};

class EvalOutputVector {
public:
    explicit EvalOutputVector(const std::vector<EvalOutputDesc>& descs);
    EvalOutput& operator[](size_t i);
    size_t size() const;
    void set_from_counts(const std::vector<int32_t>& counts, int cycle);
    std::vector<double> real_values() const;
};
```

## UserWrapper（bitpack_eval_uut.hpp）

`Vuser_wrapper` のラップ．テストベンチは AXI_FIFO の「相手側」（スレーブ側）として
FIFO の 4 チャネル相当の信号を直接操作する．

```cpp
class UserWrapper {
public:
    explicit UserWrapper(int cycle);  // Vuser_wrapper を生成，SIZE = cycle

    // リセット解除後に呼び，回路がアイドル（DONE=1）になるまで待つ
    void reset();

    // 1 回の回路動作を実行する．
    //  - words: 2*src_size ワードの入力（EvalInputVector::as_words() の結果）
    //  - counts: 戻り値，dst_size 個のカウンタ値
    // 内部処理:
    //   1. DONE=1 を確認し GO=1 にする
    //   2. READ_REQ=1（READ_BUSY=0 のとき成立）→ READ_READY=1 で
    //      READ_DATA = words[0..] を 2*src_size ワード送出
    //   3. GO=0 にして DONE=1 になるまで待つ（この間に WRITE チャネルを処理）
    //   4. WRITE_REQ=1（WRITE_BUSY=0 のとき成立）→ WRITE_READY=1 で
    //      dst_size ワードの WRITE_DATA を受信
    void run(const std::vector<uint32_t>& words,
             std::vector<int32_t>& counts);

    // 1 クロック進め（クロックは内部で生成）
    void tick();

private:
    Vuser_wrapper* m_dut;
    int m_cycle;
    // FIFO チャネルのテストベンチ側状態
    std::vector<uint32_t> m_read_words;  // 送出待ちの入力ワード
    size_t m_read_pos;
    std::vector<int32_t>  m_write_counts;
    size_t m_write_pos;
};
```

クロックは `tick()` 内で `CLK` を反転し，`eval()` を呼ぶことで同期する．
リセットは `RST_X = 0` を数サイクル与えてから `1` に戻す．

注意：`user_wrapper` は `READ_REQ = DONE & GO` であり，`GO` を立上げたサイクルに
READ_REQ が立上がる．テストベンチは READ_REQ を見て READ_READY を立て，
READ_VALID/READ_READY がともに 1 のサイクルで 1 ワード送出する．
WRITE チャネルも同様に WRITE_REQ を見て WRITE_READY を立て，
WRITE_VALID/WRITE_READY がともに 1 のサイクルで 1 ワード受信する．

## main（bitpack_test.cpp）

```
1. EvalConfig cfg("eval.json");
2. BitPackRandom rng(cfg.seed());
3. EvalInputVector  srcs(cfg.inputs());  srcs.set_rng(&rng);
   EvalOutputVector dsts(cfg.outputs());
4. UserWrapper uut(cfg.cycle());
   uut.reset();
5. ファイルオープン:
   results.txt, input.txt, output.txt（すべて "w" モード，新規作成）
6. for round in 0..times-1:
     for combo in 0..combos_per_round-1:
       a. combo 番目の入力の組合せを各入力に設定
          （itertools.product と同じ順序：最後の入力が最も速く回る）
       b. auto words = srcs.as_words();
          input.txt に各ワードを "%08x\n" で書き出し
       c. uut.run(words, counts);
       d. output.txt に各カウントを "%08x\n"（符号付き 32 ビットの
          2 の補数表現）で書き出し
       e. dsts.set_from_counts(counts, cfg.cycle());
          results.txt に，入力の real_value() 群と出力の real_value() 群を
          半角空白区切りで 1 行書き出し
7. ファイルクローズ，終了コード 0 を返す
```

組合せの生成は，`std::vector<size_t>` によるインデックスの逐次インクリメント
（最後の要素が最も速く増える）で行い，`itertools.product(values_0, values_1, ...)`
の順序と一致させる．`random` が真の入力は候補集合を `{USE_RANDOM}` とみなす．

## 実装上の注意事項

- `binary_value` の変換は，Python ドライバ
  [`bitpack_lib_io.py`](../pynq/lib/bitpack_lib_io.py) の `asarray()` と
  同一の式を用いる（実数値 → `value/denominator * 0x7fffffff`，負の場合は
  `0x100000000 + value/denominator * 0x80000000` の 32 ビット下位）
- `results.txt` の実数値表示は `%.10g`（または同程度の精度）とする
- `input.txt` / `output.txt` は 16 進 8 桁・小文字（`%08x`）とする．
  `output.txt` のカウンタ値は符号付き 32 ビット整数を 2 の補数表現で
  符号なしとして書き出す
- Verilator のバージョン差による `Vuser_wrapper` の API 差異（`eval()` の
  引数など）は，Makefile の `VERILATOR_FLAGS` で `-Wall -O2` 程度に固定し，
  生成コードの形が変わっても `tick()` / `run()` の内部だけで吸収できるようにする
