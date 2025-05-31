### Write out the node details in the node file ###
proc print_node_header { fp } {
  puts $fp "Name,Type,Master,Height,Width"
}
proc print_edge_header { fp } {
  puts $fp "Source,Sink,Weight,Net"
}

proc print_node { fp nPtr dbu } {
  set name [concat {*}[$nPtr getName]]
  regexp {[^_]+$} $nPtr type
  if { $type == "dbInst" } {
    set type "inst"
  } elseif { $type == "dbBTerm" } {
    set type "term"
  } else {
    puts "Error: Unknown node type in print_node $type name: $name"
  }
  set master "NA"
  set height "0.0"
  set width "0.0"
  if { $type == "inst" } {
    set boxPtr [$nPtr getBBox]
    set master [[$nPtr getMaster] getName]
    set height [expr [$boxPtr getDY]*1.0 / $dbu]
    set width [expr [$boxPtr getDX]*1.0 / $dbu]
  }
  puts $fp "$name,$type,$master,$height,$width"
}

proc get_net_fanout { ePtr } {
  set source_name [get_source_name $ePtr]
  if { $source_name == "NA" } {
    set fanout [expr [$ePtr getITermCount] + [$ePtr getBTermCount]]
    return $fanout
  } else {
    set fanout [expr [$ePtr getITermCount] + [$ePtr getBTermCount] - 1]
    return $fanout
  }
}

proc get_source_name { ePtr } {
  foreach bPtr [$ePtr getBTerms] {
    if { [$bPtr getIoType] == "INPUT" } {
      return [concat {*}[$bPtr getName]]
    }
  }

  foreach iPtr [lreverse  [$ePtr getITerms]] {
    if { [$iPtr getIoType] == "OUTPUT" } {
      set instPtr [$iPtr getInst]
      return [concat {*}[$instPtr getName]]
    }
  }

  set net_name [concat {*}[$ePtr getName]]
  puts "Error: Net $net_name has no source"
  return "NA"
}

proc get_net_sinks { ePtr } {
  set sinks {}
  foreach bPtr [$ePtr getBTerms] {
    if { [$bPtr getIoType] == "OUTPUT" } {
      lappend sinks [concat {*}[$bPtr getName]]
    }
  }

  foreach iPtr [$ePtr getITerms] {
    if { [$iPtr getIoType] == "INPUT" } {
      set instPtr [$iPtr getInst]
      lappend sinks [concat {*}[$instPtr getName]]
    }
  }
  return [lsort -unique $sinks]
}

proc print_edge { fp ePtr {fanout_threshold 50}} {
  set net_fanout [get_net_fanout $ePtr]
  set is_special [$ePtr isSpecial]
  if { $is_special || $net_fanout > $fanout_threshold || $net_fanout == 0 } {
    return
  }

  set net_name [$ePtr getName]
  set edge_weigth [expr 1.0 / $net_fanout]
  set source_name [get_source_name $ePtr]
  set sink_names [get_net_sinks $ePtr]
  if { [llength $sink_names] != $net_fanout } {
    set unique_sink_count [llength $sink_names]
    puts "Error: Net $net_name has fanout $net_fanout but only \
      $unique_sink_count sinks"
  }

  foreach sink_name $sink_names {
    puts $fp "$source_name,$sink_name,$edge_weigth,$net_name"
  }
}

proc print_hyper_graph { fp ePtr } {
  set net_name [$ePtr getName]
  set source_name [get_source_name $ePtr]
  set sink_names [get_net_sinks $ePtr]
  set sinks [join $sink_names " "]
  puts $fp "$net_name $source_name $sinks"
}

proc write_macro_location { fp macro_ptr } {
  set name [concat {*}[$macro_ptr getName]]
  set boxPtr [$macro_ptr getBBox]
  set x [$boxPtr getXMin]
  set y [$boxPtr getYMin]
  puts $fp "$name,$x,$y"
}

proc find_macros {} {
  set macros ""

  set db [ord::get_db]
  set block [[$db getChip] getBlock]
  foreach inst [$block getInsts] {
    set inst_master [$inst getMaster]

    # BLOCK means MACRO cells
    if { [string match [$inst_master getType] "BLOCK"] } {
      append macros " " $inst
    }
  }
  return $macros
}

proc write_graph { {output_dir "./"}} {
  exec mkdir -p $output_dir
  set block [ord::get_db_block]
  set design_name [$block getName]
  set dbu [$block getDbUnitsPerMicron]
  set node_file [open "$output_dir/${design_name}_nodes.csv" "w"]

  ## Write Insts
  print_node_header $node_file
  foreach instPtr [$block getInsts] {
    print_node $node_file $instPtr $dbu
  }

  ## Write Terms
  foreach termPtr [$block getBTerms] {
    print_node $node_file $termPtr $dbu
  }
  close $node_file

  set edge_file [open "$output_dir/${design_name}_edges.csv" "w"]
  ## Write Nets
  print_edge_header $edge_file
  foreach netPtr [$block getNets] {
    print_edge $edge_file $netPtr
  }
  close $edge_file

  ## Write Hypergraph
  set hypergraph_file [open "$output_dir/${design_name}.hgr" "w"]
  foreach netPtr [$block getNets] {
    print_hyper_graph $hypergraph_file $netPtr
  }
  close $hypergraph_file

  set macros [find_macros]
  if { [llength $macros] != 0 } {
    set macro_file [open "$output_dir/${design_name}_macro.csv" "w"]
    puts $macro_file "Name,llx,lly"
    foreach macroPtr $macros {
      write_macro_location $macro_file $macroPtr
    }
    close $macro_file 
  }

  write_def ${output_dir}/${design_name}_placed.def
  write_verilog ${output_dir}/${design_name}.v
}

proc write_graph_or {} {
  set output_dir "$::env(RESULTS_DIR)/blob_input"
  exec mkdir -p $output_dir
  write_graph $output_dir
}