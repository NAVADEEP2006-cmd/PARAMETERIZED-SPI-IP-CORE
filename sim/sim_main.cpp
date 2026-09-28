// -----------------------------------------------------------------------------
// sim_main.cpp  -  Verilator C++ testbench harness
// -----------------------------------------------------------------------------
#include <verilated.h>
#include "Vspi_tb.h"

#if VM_TRACE
#include <verilated_vcd_c.h>
#endif

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vspi_tb* top = new Vspi_tb;

#if VM_TRACE
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("spi_tb.vcd");
#endif

    vluint64_t main_time = 0;
    while (!Verilated::gotFinish()) {
        top->eval();
#if VM_TRACE
        if (tfp) tfp->dump(main_time);
#endif
        main_time++;
    }

#if VM_TRACE
    if (tfp) {
        tfp->close();
        delete tfp;
    }
#endif

    top->final();
    delete top;
    return 0;
}
