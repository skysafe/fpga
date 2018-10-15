#
# Copyright 2016 Ettus Research
#

include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_AXI_INTERCON_3X64_256_BD_SRCS = $(IP_BUILD_DIR)/axi_intercon_3x64_256_bd/axi_intercon_3x64_256_bd.bd \
$(IP_BUILD_DIR)/axi_intercon_3x64_256_bd/axi_intercon_3x64_256_bd.bxml \
$(IP_BUILD_DIR)/axi_intercon_3x64_256_bd/axi_intercon_3x64_256_bd_wrapper.v 

BD_AXI_INTERCON_3X64_256_BD_OUTS = $(addprefix $(IP_BUILD_DIR)/axi_intercon_3x64_256_bd/, \
axi_intercon_3x64_256_bd.bd.out \
axi_intercon_3x64_256_bd_ooc.xdc \
)

# The cp below is a workaround for a Vivado issue where it is pulling in wrong sources
$(IP_AXI_INTERCON_3X64_256_BD_SRCS) $(IP_AXI_INTERCON_3X64_256_BD_OUTS) : $(IP_DIR)/axi_intercon_3x64_256_bd/axi_intercon_3x64_256_bd.bd
	$(call BUILD_VIVADO_BD,axi_intercon_3x64_256_bd,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR))
	cp -f $(IP_BUILD_DIR)/axi_intercon_3x64_256_bd/synth/axi_intercon_3x64_256_bd.v $(IP_BUILD_DIR)/axi_intercon_3x64_256_bd/hdl/axi_intercon_3x64_256_bd.v
