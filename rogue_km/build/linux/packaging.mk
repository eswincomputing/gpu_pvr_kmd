########################################################################### ###
#@Copyright     Copyright (c) Imagination Technologies Ltd. All Rights Reserved
#@License       Dual MIT/GPLv2
#
# The contents of this file are subject to the MIT license as set out below.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# Alternatively, the contents of this file may be used under the terms of
# the GNU General Public License Version 2 ("GPL") in which case the provisions
# of GPL are applicable instead of those above.
#
# If you wish to allow use of your version of this file only under the terms of
# GPL, and not to allow others to use your version of this file under the terms
# of the MIT license, indicate your decision by deleting the provisions above
# and replace them with the notice and other provisions required by GPL as set
# out in the file called "GPL-COPYING" included in this distribution. If you do
# not delete the provisions above, a recipient may use your version of this file
# under the terms of either the MIT license or GPL.
#
# This License is also included in this distribution in the file called
# "MIT-COPYING".
#
# EXCEPT AS OTHERWISE STATED IN A NEGOTIATED AGREEMENT: (A) THE SOFTWARE IS
# PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT; AND (B) IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
### ###########################################################################

.PHONY: rpm_specs
rpm_specs: ddk_rpm_spec llvm_rpm_spec mesa_rpm_spec


# DDK spec file
#
.PHONY: ddk_rpm_spec
ddk_rpm_spec: $(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec
$(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec: METAG_VERSION := $(METAG_VERSION_NEEDED)
$(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec: MIPS_VERSION := $(MIPS_VERSION_NEEDED)
$(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec: RISCV_VERSION := $(RISCV_VERSION_NEEDED)
$(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec: $(MAKE_TOP)/packaging/pvr-rogue-ddk.spec
$(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec: $(PVRVERSION_H) $(CONFIG_MK)
$(RELATIVE_OUT)/packaging/pvr-rogue-ddk.spec: | $(RELATIVE_OUT)/packaging
	$(if $(V),,@echo "  GEN     " $(call relative-to-top,$@))
	$(SED) \
		-e 's,@DDK_VERSION@,$(PVRVERSION_MAJ).$(PVRVERSION_MIN).$(PVRVERSION_BUILD),g' \
		-e 's,@METAG_VERSION@,$(METAG_VERSION),g' \
		-e 's,@MIPS_VERSION@,$(MIPS_VERSION),g' \
		-e 's,@RISCV_VERSION@,$(RISCV_VERSION),g' \
		$< > $@

$(RELATIVE_OUT)/packaging:
	@mkdir -p $@


# LLVM spec file
#
# Generate llvm-img rpm spec file and copy patches referenced in the spec file
# to the same location.
#
LLVM_PATCH_DIR := $(TOP)/compiler/llvmufgen/rogue/patches
LLVM_PATCHES := $(sort $(notdir $(wildcard $(LLVM_PATCH_DIR)/*)))
LLVM_OUT_DIR := $(RELATIVE_OUT)/packaging/llvm-img

.PHONY: llvm_rpm_spec
llvm_rpm_spec: $(LLVM_OUT_DIR)/llvm-img.spec
$(LLVM_OUT_DIR)/llvm-img.spec: LLVM_PATCH_DIR := $(LLVM_PATCH_DIR)
$(LLVM_OUT_DIR)/llvm-img.spec: $(MAKE_TOP)/packaging/llvm-img.spec
$(LLVM_OUT_DIR)/lolvm-img.spec: $(addprefix $(LLVM_PATCH_DIR)/, $(LLVM_PATCHES))
$(LLVM_OUT_DIR)/llvm-img.spec: | $(LLVM_OUT_DIR)
	$(if $(V),,@echo "  GEN     " $(call relative-to-top,$@))
	$(CP) $< $@
	$(CP) $(wildcard $(LLVM_PATCH_DIR)/*) $(dir $@)

$(LLVM_OUT_DIR):
	@mkdir -p $@


# Mesa spec file
#
# Generate mesa-img rpm spec file. This involves generating 'patch' lines
# based upon the patches found in the Mesa patch directory. This is done
# to protect against Mesa patches being added and removed (something that
# happens fairly often). All referenced patches get copied to the location
# of the generated spec file.
#
MESA_PATCH_DIR := $(LWS_GIT_PATCH_DIR)/mesa/mesa-22.0.1
MESA_PATCHES := $(sort $(notdir $(wildcard $(MESA_PATCH_DIR)/*)))
MESA_OUT_DIR := $(RELATIVE_OUT)/packaging/mesa-img

.PHONY: mesa_rpm_spec
mesa_rpm_spec: $(MESA_OUT_DIR)/mesa-img.spec
$(MESA_OUT_DIR)/mesa-img.spec: MESA_PATCH_DIR := $(MESA_PATCH_DIR)
$(MESA_OUT_DIR)/mesa-img.spec: MESA_PATCHES := $(MESA_PATCHES)
$(MESA_OUT_DIR)/mesa-img.spec: SUBST_PATCHES_TXT := $(MESA_OUT_DIR)/subst_patches.txt
$(MESA_OUT_DIR)/mesa-img.spec: SUBST_APPLY_PATCHES_TXT := $(MESA_OUT_DIR)/subst_apply_patches.txt
$(MESA_OUT_DIR)/mesa-img.spec: $(MAKE_TOP)/packaging/mesa-img.spec
$(MESA_OUT_DIR)/mesa-img.spec: $(addprefix $(MESA_PATCH_DIR)/, $(MESA_PATCHES))
$(MESA_OUT_DIR)/mesa-img.spec: | $(MESA_OUT_DIR)
	$(if $(V),,@echo "  GEN     " $(call relative-to-top,$@))
	$(if $(V),,@)patch_nums=$$(seq -s ' ' 0 $$(expr $$(echo $(MESA_PATCHES) | wc -w) - 1)); \
	echo "# Gbp-Ignore-Patches: $${patch_nums}" > $(SUBST_PATCHES_TXT)
	$(if $(V),,@)i=0; for patch in $(MESA_PATCHES); do \
		echo "Patch$${i}: $${patch}" >> $(SUBST_PATCHES_TXT); \
		i=$$(expr $${i} + 1); \
	done
	$(if $(V),,@)i=0; for patch in $(MESA_PATCHES); do \
		echo "%patch$${i} -p1" >> $(SUBST_APPLY_PATCHES_TXT); \
		i=$$(expr $${i} + 1); \
	done
	$(SED) \
		-e '/@PATCHES@/ {' -e 'r $(SUBST_PATCHES_TXT)' -e 'd' -e '}' \
		-e '/@APPLY_PATCHES@/ {' -e 'r $(SUBST_APPLY_PATCHES_TXT)' -e 'd' -e '}' \
		$< > $@
	$(RM) $(SUBST_PATCHES_TXT)
	$(RM) $(SUBST_APPLY_PATCHES_TXT)
	$(RM) $(MESA_OUT_DIR)/*.patch
	$(CP) $(wildcard $(MESA_PATCH_DIR)/*) $(dir $@)

$(MESA_OUT_DIR):
	@mkdir -p $@
