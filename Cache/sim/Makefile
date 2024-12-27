SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS  := $(PWD)/../pkg/types.sv
HDL_SRCS  := $(shell find $(PWD)/../hdl -name '*.sv')
COMM_HVL  := $(shell find $(PWD)/../hvl/common -name '*.sv' -o -name '*.v')
VCS_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/vcs -name '*.sv' -o -name '*.v')
VER_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/verilator -name '*.sv' -o -name '*.v')
SRAM_SRCS := $(shell find $(PWD)/../sram/output -name '*.v')
HDRS      := $(shell find $(PWD)/../hvl -name '*.svh')
DW_IP     :=
VCS_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VCS_HVL) $(SRAM_SRCS) $(DW_IP)
VER_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VER_HVL) $(SRAM_SRCS) $(DW_IP)

export VCS_ARCH_OVERRIDE=linux
VCS_FLAGS= -full64 -lca -sverilog -timescale=1ps/1ps -debug_acc+all -kdb -fsdb -suppress=LCA_FEATURES_ENABLED -msg_config=../vcs_warn.config -xprop=../xprop.config -xprop=flowctrl +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN

ifdef f
VCS_FLAGS= -full64 -lca -sverilog -timescale=1ps/1ps -debug_access+all -kdb -suppress=LCA_FEATURES_ENABLED -msg_config=../vcs_warn.config -xprop=../xprop.config -xprop=flowctrl +incdir+$(DW)/sim_ver +define+DW_SUPPRESS_WARN
endif
DFILE += ../hdl/lru_array.sv
DFILE += ../hdl/valid_array.sv
DFILE += ../hdl/cache.sv
TFILE += ../hvl/common/simple_memory_256_wo_mask.sv
TFILE += ../hvl/common/mem_itf.sv
TFILE += ../hvl/common/rand_ufp.sv
TFILE += ../hvl/common/ufp_mst.sv
TFILE += ../hvl/vcs/top_tb.sv
TFILE += ../hvl/vcs/cache_rm.sv
LFILE += ../sram/output/mp_cache_data_array/mp_cache_data_array.v
LFILE += ../sram/output/mp_cache_tag_array/mp_cache_tag_array.v

vcs/top_tb: $(VCS_SRCS) $(HDRS)
	mkdir -p vcs
	python3 check_sus.py
	cd vcs && vcs $(VCS_SRCS) $(VCS_FLAGS) -l compile.log -top top_tb -o top_tb
	bash check_compile_error.sh
	cat vcs/xprop.log
	bash check_xprop.sh

run: 
	mkdir -p vcs
	rm -f vcs/dump.fsdb
	cd vcs && vcs $(VCS_SRCS) $(VCS_FLAGS) -l compile.log -top top_tb -o top_tb
	bash check_compile_error.sh
	export ECE411_MEMFILE=../$(MEM) ;\
	cd vcs && ./top_tb -l simulation.log -exitstatus

.PHONY: run_vcs_top_tb
run_vcs_top_tb: vcs/top_tb $(MEM)
	rm -f vcs/dump.fsdb
	export ECE411_MEMFILE=../$(MEM) ;\
	cd vcs && ./top_tb -l simulation.log -exitstatus
	bash check_sim_error.sh

.PHONY: covrep
covrep: vcs/top_tb.vdb
	cd vcs && urg -dir top_tb.vdb

.PHONY: verdi
verdi:
	mkdir -p verdi
	cd verdi && $(VERDI_HOME)/bin/verdi -ssf $(PWD)/vcs/dump.fsdb &

.PHONY: clean
clean:
	rm -rf bin vcs verdi verilator
