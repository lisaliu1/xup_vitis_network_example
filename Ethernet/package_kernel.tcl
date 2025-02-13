#   Copyright (c) 2021, Xilinx, Inc.
#   All rights reserved.
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are met:
#
#   1.  Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#   2.  Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#   3.  Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived from
#       this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
#   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#   OR BUSINESS INTERRUPTION). HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#   OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#   ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


set projName kernel_pack
set bd_name cmac_bd
set root_dir "[file normalize "."]"
set path_to_hdl "./src"
set path_to_packaged "./packaged_kernel_${suffix}"
set path_to_tmp_project "./tmp_${suffix}"

set words [split $device "_"]
set board [lindex $words 1]

if {[string first "u50" ${board}] != -1} {
    if {$interface != 0} {
        puts "ERROR: Alveo U50 only has one interface"
        exit
    }
    set projPart "xcu50-fsvh2104-2L-e"
} elseif {[string first "u55" ${board}] != -1} {
    set projPart "xcu55c-fsvh2892-2L-e"
} elseif {[string first "u200" ${board}] != -1} {
    set projPart "xcu200-fsgd2104-2-e"
} elseif {[string first "u250" ${board}] != -1} {
    set projPart "xcu250-figd2104-2L-e"
} elseif {[string first "u280" ${board}] != -1} {
    set projPart "xcu280-fsvh2892-2L-e"
} else {
    puts "ERROR: unsupported $board"
    exit
}


create_project -force $projName $path_to_tmp_project -part $projPart
add_files -norecurse [glob ${root_dir}/src/cmac_top_${interface}.v]
add_files -norecurse [glob ${root_dir}/src/cmac_0_axi4_lite_user_if.v]
add_files -norecurse [glob ${root_dir}/src/cmac_sync.v]
add_files -norecurse [glob ${root_dir}/src/rx_sync.v]
add_files -fileset constrs_1 -norecurse [glob ${root_dir}/src/cmac_synq_false_path.xdc]

update_compile_order -fileset sources_1

source ${root_dir}/bd_cmac.tcl
update_compile_order -fileset sources_1


generate_target all [get_files  ${path_to_tmp_project}/${projName}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd]
export_ip_user_files -of_objects [get_files ${path_to_tmp_project}/${projName}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] ${path_to_tmp_project}/${projName}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd]
update_compile_order -fileset sources_1
set_property top cmac_${interface} [current_fileset]


set gt_name gt_serial_port${interface}
# Package IP

ipx::package_project -root_dir ${path_to_packaged} -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core ${path_to_packaged}/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ${path_to_packaged} ${path_to_packaged}/component.xml
set_property core_revision 1 [ipx::current_core]
foreach up [ipx::get_user_parameters] {
  ipx::remove_user_parameter [get_property NAME $up] [ipx::current_core]
}
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::add_bus_interface ap_clk [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]
ipx::add_port_map CLK [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]
set_property physical_name ap_clk [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]]
ipx::associate_bus_interfaces -busif S_AXIS -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif M_AXIS -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif S_AXILITE -clock ap_clk [ipx::current_core]

ipx::add_bus_interface ${gt_name} [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:gt_rtl:1.0 [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:interface:gt:1.0 [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
ipx::add_port_map GRX_P [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
set_property physical_name gt_rxp_in [ipx::get_port_maps GRX_P -of_objects [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]]
ipx::add_port_map GRX_N [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
set_property physical_name gt_rxn_in [ipx::get_port_maps GRX_N -of_objects [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]]
ipx::add_port_map GTX_P [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
set_property physical_name gt_txp_out [ipx::get_port_maps GTX_P -of_objects [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]]
ipx::add_port_map GTX_N [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]
set_property physical_name gt_txn_out [ipx::get_port_maps GTX_N -of_objects [ipx::get_bus_interfaces ${gt_name} -of_objects [ipx::current_core]]]


set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} [ipx::current_core]
set_property supported_families { } [ipx::current_core]
set_property auto_family_support_level level_2 [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project -delete
