PYNQ-BitPack: An evaluation framework for stochastic computing circuits on PYNQ
===============================================================================

Abstract
--------

This repository contains an evaluation framework for stochastic computing
circuits, supposed to work on the PYNQ platform. It is composed of hardware
components (written in Verilog HDL and SystemVerilog), a code generator, and
a custom driver on PYNQ (written in Python).

A detailed explanation of this framework, which is not covered in this README
file, will be found in the following article:

> Naoki Fujieda: A Python-based evaluation framework for stochastic computing
> circuits on FPGA SoC, 9th International Workshop on Computer Systems and
> Architectures (CSA-9) held in conjunction with CANDAR '21, pp. 81-86
> (11/2021).

The author synthesized the hardware overlay by Xilinx Vivado 2020.2.
The target board is Digilent <a href="https://digilent.com/reference/programmable-logic/pynq-z1/start">PYNQ-Z1</a>, which is a low-end development board for
PYNQ. The version of PYNQ image was 2.6. The scripts were run on Python 3.6.9.

-----------------------------------------------------------------------

Organization of Repository
--------------------------

The hierarchy of the repository is as follows:

- `code_generator`: code generator for a wrapper circuit and a custom driver
  - `sample`: HDL description of sample circuit (stochastic adder/multiplier)
  - `template`: template of the circuit and the driver
- `fpga`: source files for the generation of a hardware overlay of PYNQ
  - `components`: hardware components of the framework IP core
  - `sample_ip`: IP core, generated with sample circuit
  - `script`: script to prepare a block design automatically
  - `testbench`: testbench for the framework IP core
- `pynq`: custom driver of the framework IP core on PYNQ
  - `lib`: a part of the driver that abstracts I/O ports
  - `sample`: driver and notebook for sample IP core

-----------------------------------------------------------------------

Getting Started with Vivado and PYNQ-Z1
---------------------------------------

The workflow of this framework consists of the following five steps:

1. With the code generator, generate a wrapper circuit, a stochastic number
   generator, a counter, and a custom driver for a user circuit.
2. With the IP packager tool of Vivado, package the user circuit, the circuits
   generated in Step 1, and the hardware components into an IP core.
3. Create a Vivado project and a block design with the packaged IP core, and
   then synthesize the design to obtain a hardware overlay.
4. Upload the hardware overlay and the custom driver, and then write a test
   program on Jupyter notebook on PYNQ. (Alternatively, you can upload an
   existing notebook.)
5. Run the test program on Jupyter notebook.

You can begin with a sample circuit, a stochastic adder and multiplier, in
the sample directories of this repository. Specific steps for the sample
circuits are as follows.

### Step 1

Execute the code generator on the `code_generator` directory.

>     $ cd code_generator
>     $ python3 bitpack_gen.py sample/bit_addmul.sv bit_addmul

The code generator will say that some input and output ports are detected,
and now you can find files specific to the sample circuit in the `bit_addmul`
directory.

### Step 2

(Since we prepare the packaged sample IP core in the `fpga/sample_ip` folder,
 you can skip this step.)

Create a folder that will contain a sample IP core. Create another folder
in the IP core folder and change its name to `hdl`. Copy the following files
to the `hdl` folder:

- all of the files in the `fpga/components` folder,
- bit_addmul.sv in the `code_generator/sample` folder, and
- all of the SystemVerilog files geneated in Step 1 (i.e., user_wrapper.sv,
  sn_gen.sv, and count.sv) in the `code_generator/bit_addmul` folder.

Package the IP core folder with the IP packager of Vivado (Tools -> Create
and Package New IP -> Package a specified directory). We assume that the
VLNV name of the IP is `AIT:DSLab:bitpack_top:1.0` in the following steps.
If you want to use another name, you will have to modify the Tcl script and
the custom driver slightly (details are explained later).

After the IP core is packaged correctly, you will find `component.xml` (IP
definition) file, and `xgui` folder in the IP core folder.

### Step 3

Create a Vivado project targetting the PYNQ-Z1 board. From Settings -> IP ->
Repository, add the IP core folder (the `fpga/sample_ip` folder if you have
skipped Step 2), to the IP repository.

Then prepare a block design for the framework. This is automated by the
`make_bd.tcl` script in the `fpga/script` folder. Run the script from the
"Tools -> Run Tcl Script" menu.

If you have given another VLNV name in Step 2, replace the VLNV names
(`AIT:DSLab:bitpack_top:1.0`) in Lines 127 and 207 of the script with your
own.

Probably you can use a version of Vivado other than 2020.2 by modifying the
Vivado version in Line 22 of the script. Note that the hardware handoff file
will be generated under the `(project name).srcs` folder in an older version,
instead of `(project name).gen`.

After the block design is prepared, you can synthesize it by usual "Create
HDL Wrapper," "Generate Block Design," and "Generate Bitstream" steps.
Files of the hardware overlay will be generated in the following locations:

- `(project name).runs/impl_1/design_1_wrapper.bit`
- `(project name).gen/sources_1/bd/design_1/hw_handoff/design_1.hwh`

Copy them and rename them as `bitpack_sample` (bitpack_sample.bit and
bitpack_sample.hwh, respectively).

### Step 4

Prepare a folder that contains the following files:

- `bitpack_sample.ipynb`: sample notebook in the `pynq/sample` folder,
- `bitpack_lib.py`: custom driver in either the `pynq/sample` folder or
  the `code_generator/bit_addmul` folder,
- `bitpack_lib_io.py`: I/O port classes in the `pynq/lib` folder,
- `bitpack_sample.bit`: bitstream file generated in Step 3, and
- `bitpack_sample.hwh`: hardware handoff file generated in Step 3.

If you have given another VLNV name in Step 2, replace the VLNV names
(`AIT:DSLab:bitpack_top:1.0`) in Line 13 of the driver with your own.

Boot the PYNQ-Z1 board and upload this folder to the `jupyter_notebooks`
folder in the home directory of the PYNQ.

### Step 5

Open the `bitpack_sample.ipynb` notebook in Jupyter notebook on PYNQ and run
the cell. Since the test program gives the values of 0.9, 0.8, 0.7, 0.6 to
the input ports, the product will be around 0.3024 and the average will be
around 0.75. The result will vary slightly because random numbers are given
as seeds of stochastic number generators.

-----------------------------------------------------------------------

Use of testbench 
----------------

This repository also includes a testbench of the framework IP core in the
`fpga/testbench` folder. The testbench requires the `axi_slave_bfm` module
(and the `sync_fifo` module instantiated by that module), written by marsee. 
Their source codes are available from the following URL:

> https://marsee101.blog.fc2.com/blog-entry-3509.html

Note that these files are not included in this repository.

The framework IP core reads an array of structures as an input array. The
structure is defined as follows:

>     typedef struct {
>         signed   int binary_value;
>         unsigned int seed;
>     } input_port_t;

The `binary_value` member is the value of that port, multiplied by 0x7fffffff
(INT_MAX). The `seed` member is the seed of the stochastic number generator.
The seed must not be zero. The hexadecimal expressions of these 32-bit
integers have to be prepared in a text file named `input.txt`.

The output array is an array of 32-bit signed integers. Since each integer
corresponds to the value of an output counter, the value of the output port
is obtained by dividing it by the length of stochastic numbers (4096 by
default). After a simulation is successfully finished, the contents of the
output array is saved as a text file named `output.txt`.

As the default working directory of the Vivado simulator is
(project name).sim/sim_1/behav/xsim, the `input.txt` file must be copied to
that directory after a simulation is initiated. Also, the `output.txt` file
will be generated in that directory.

-----------------------------------------------------------------------

Restriction of Source Code of User Circuit
------------------------------------------

To let the code generator detect I/O ports of a user circuit correctly,
the Verilog/SystemVerilog description of the top module of the user circuit
has to meet the following rules.

1. The file given to the code generator shall describe the top module only.
   The other module(s) shall be described in the other file(s).
2. Multiple input or output ports shall NOT be defined in a single line,
   except in cases where Rule 5 or 7 applies.
3. The name of clock input shall be either clk or clock (case insensitive).
4. The name of reset input shall be either rst or reset (case insensitive).
   The reset input shall be active low.
5. Clock and reset input ports can be defined in a single line.
6. If a value is represented by the bipolar representation, its name shall
   end with a postfix of `_b`.
7. If a value is represented by the two-line representation, a pair of ports
   shall be defined in a single line and they shall be end with postfixes of
   `_p` and `_m`, respectively.

-----------------------------------------------------------------------

ChangeLog
---------

### v0.2.0 2022-12-13
- In order to make it easy to add another mode of SN generator and counter
  (or representation of SN), modes are now defined in a JSON file. This
  means SN generator and counter are also generated by the code generator.
- parsing SystemVerilog is put out from the main routine for readability.

### v0.1.0 2021-09-10 (published on 2021-10-06)
- The initial version presented at the CSA workshop of CANDAR 2021.

-----------------------------------------------------------------------

Copyright
---------

All of the Verilog HDL, SystemVerilog, Python source files of this repository,
PYNQ-BitPack, are developed by <a href="https://aitech.ac.jp/~dslab/nf/index.en.html">Naoki FUJIEDA</a>.
These are licensed under the New BSD license.
See the COPYING file for more information.

Copyright (C) 2021 Naoki FUJIEDA. All rights reserved.