# SPDX-License-Identifier: Apache-2.0

SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src

VERILOG_SOURCES += $(SRC_DIR)/project.v

TOPLEVEL = tt_um_pwm_generator
MODULE = test

include $(shell cocotb-config --makefiles)/Makefile.sim
