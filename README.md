# OpenZ7

**Goals:** To build a Zynq based design using
[AutoFPGA](https://github.com/ZipCPU/autofpga), a completely text base
processing system, rather than Vivado's visual board design methodology.

This is a high risk goal, so if I am unsuccessful I intend to use the board
design methodology to create a single peripheral and master component which
will then have its source found here.  (I have yet to be unsuccessful, but
the project is ongoing.)

**Board:** This project is built around the [Arty Z7-20
board](https://store.digilentinc.com/arty-z7-apsoc-zynq-7000-development-board-for-makers-and-hobbyists/)
from [Digilent](https://store.digilentinc.com).

My goal is to then be able to use this project as a base for other projects
using the [Arty Z7-20
board](https://store.digilentinc.com/arty-z7-apsoc-zynq-7000-development-board-for-makers-and-hobbyists/).
I'll be using AXI components from my
[WB2AXIP](https://github.com/ZipCPU/wb2axip) repository liberally to make this
happen.  This includes my open source [AXI
crossbar](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axixbar.v), my
[AXI-lite 
crossbar](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axilxbar.v) (if
necessary), a [bridge from AXI3 to
AXI4](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axi32axi.v),
a [bridge from AXI4 to
AXI-lite](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axi2axilite.v),
and (hopefully) a [bridge from AXI4 to
AXI3](https://github.com/ZipCPU/wb2axip/blob/master/rtl/axi2axi3.v) (still
unfinished/untested).

## Status

This project is a work in progress.  As such, do not expect to be able to use
it at present without a lot of additional work.  Gurus welcome, beginners
wave-off.  Support will likely be sporadic or non-existent at best for the
time being.

## License

This project is licensed under the GPLv3.  If this license is insufficient
for your needs, please feel free to contact me to discuss other potential
license terms.

