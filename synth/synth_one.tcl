# synth_one.tcl -- synth+impl simon_enc at a given UNROLL, append one CSV row.
#   vivado -mode batch -source synth/synth_one.tcl -tclargs <part> <period_ns> <unroll>
set part   [lindex $argv 0]
set period [lindex $argv 1]
set unroll [lindex $argv 2]
set label  "simon_u$unroll"
set root   [pwd]
set outdir $root/results/synth/$label
file mkdir $outdir

read_verilog -sv $root/rtl/simon_enc.sv
synth_design -top simon_enc -part $part -include_dirs $root/rtl -mode out_of_context \
             -generic UNROLL=$unroll -flatten_hierarchy rebuilt
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

set csv $root/results/synth_sweep.csv
if {![file exists $csv]} {
    set fh [open $csv w]
    puts $fh "unroll,part,period_ns,lut,ff,dsp,bram,srl,wns_ns,fmax_mhz,power_w"
    close $fh
}
set fh [open $csv a]
puts $fh [format "%s,%s,%s,%d,%d,%d,%d,%d,%.3f,%.1f,%s" \
          $unroll $part $period $luts $ff $dsp $bram $srl $wns $fmax $power]
close $fh
puts "==== $label : LUT=$luts FF=$ff DSP=$dsp SRL=$srl WNS=$wns Fmax=${fmax}MHz Power=${power}W"
