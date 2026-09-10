# synth_aes.tcl -- synth+impl the AES-128 encrypt baseline for comparison.
#   vivado -mode batch -source synth/synth_aes.tcl -tclargs <part> <period_ns>
set part   [lindex $argv 0]
set period [lindex $argv 1]
set label  "aes128_enc"
set root   [pwd]
set outdir $root/results/synth/$label
file mkdir $outdir

read_verilog $root/baseline_aes/aes_sbox.v
read_verilog $root/baseline_aes/aes_round.v
read_verilog $root/baseline_aes/aes_keyexp.v
read_verilog $root/baseline_aes/aes_encrypt.v
synth_design -top aes_encrypt -part $part -mode out_of_context -flatten_hierarchy rebuilt
create_clock -period $period -name clk [get_ports clk]
opt_design
place_design
route_design

report_utilization    -file $outdir/utilization.rpt
report_timing_summary -file $outdir/timing.rpt
report_power          -file $outdir/power.rpt

proc ncells {pat} { return [llength [get_cells -hierarchical -filter "REF_NAME =~ $pat"]] }
set luts [ncells LUT*]; set ff [ncells FD*]; set dsp [ncells DSP48*]
set bram [ncells RAMB*]; set srl [ncells SRL*]
set wns [get_property SLACK [get_timing_paths -setup -max_paths 1 -nworst 1]]
if {$wns eq ""} { set wns 0.0 }
set fmax [expr {($period-$wns) > 0 ? 1000.0/($period-$wns) : 0.0}]
set power "NA"
if {[catch {
    set fh [open $outdir/power.rpt r]; set txt [read $fh]; close $fh
    if {[regexp {Total On-Chip Power \(W\)\s*\|\s*([0-9.]+)} $txt -> p]} { set power $p }
}]} {}

set csv $root/results/aes_synth.csv
set fh [open $csv w]
puts $fh "label,part,period_ns,lut,ff,dsp,bram,srl,wns_ns,fmax_mhz,power_w"
puts $fh [format "%s,%s,%s,%d,%d,%d,%d,%d,%.3f,%.1f,%s" \
          $label $part $period $luts $ff $dsp $bram $srl $wns $fmax $power]
close $fh
puts "==== $label : LUT=$luts FF=$ff DSP=$dsp SRL=$srl WNS=$wns Fmax=${fmax}MHz Power=${power}W"
