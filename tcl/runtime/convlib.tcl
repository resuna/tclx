#
# convlib.tcl --
#
#     Convert Ousterhout style tclIndex files and associated libraries to a
# package library.
# 
#------------------------------------------------------------------------------
# Copyright 1992-1993 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: convlib.tcl,v 2.2 1993/06/21 05:58:43 markd Exp markd $
#------------------------------------------------------------------------------
#

#@package: TclX-convertlib convert_lib

#------------------------------------------------------------------------------
# tclx:ParseTclIndex
# Parse a tclIndex file, returning an array of file names with the list of
# procedures in each package. This is done by sourcing the file and then
# going through the local auto_index array that was created. Issues warnings
# for lines that can't be converted.  tclIndex should be an absolute path
# name.  Returns 1 if all lines are converted, 0 if some failed.
#

proc tclx:ParseTclIndex {tclIndex fileTblVar ignore} {
    upvar $fileTblVar fileTbl
    set allOK 1

    # Open and validate the file.

    set tclIndexFH [open $tclIndex r]
    set hdr [gets $tclIndexFH]
    if {$hdr != "# Tcl autoload index file, version 2.0"} {
        error "can only convert version 2.0 Tcl auto-load files"
    }
    set dir [file dirname $tclIndex]  ;# Expected by the script.
    eval [read $tclIndexFH]
    close $tclIndexFH

    foreach procName [array names auto_index] {
        if ![string match "source *" $auto_index($procName)] {
            puts stderr "WARNING: Can't convert load command for \"$procName\": $auto_index($procName)"
            set allOK 0
            continue
        }
        set filePath [lindex $auto_index($procName) 1]
        set fileName [file tail $filePath] 
        if {[lsearch $ignore $fileName] >= 0} continue

        lappend fileTbl($filePath) $procName
    }
    if ![info exists fileTbl] {
        error "no entries could be converted in $tclIndex"
    }
    return $allOK
}

#------------------------------------------------------------------------------
# convert_lib:
# Convert a tclIndex library to a .tlib. ignore any files in the ignore
# list

proc convert_lib {tclIndex packageLib {ignore {}}} {
    source [info library]/buildidx.tcl

    if {[file tail $tclIndex] != "tclIndex"} {
        error "Tail file name must be `tclIndex': $tclIndex"}
    if ![file readable $tclIndex] {
        error "File not readable: $tclIndex"
    }

    # Expand to root relative file name.

    set tclIndex [glob $tclIndex]
    if ![string match "/*" $tclIndex] {
        set tclIndex "[pwd]/$tclIndex"
    }

    # Parse the file.

    set allOK [tclx:ParseTclIndex $tclIndex fileTbl $ignore]

    # Generate the .tlib package names with contain the directory and
    # file name, less any extensions.

    if {[file extension $packageLib] != ".tlib"} {
        append packageLib ".tlib"
    }
    set libFH [open $packageLib w]

    foreach srcFile [array names fileTbl] {
        set pkgName [file tail [file dirname $srcFile]]/[file tail [file root $srcFile]]
        set srcFH [open $srcFile r]
        puts $libFH "#@package: $pkgName $fileTbl($srcFile)\n"
        copyfile $srcFH $libFH
        close $srcFH
    }
    close $libFH
    buildpackageindex $packageLib
    if !$allOK {
        error "*** Not all entries converted, but library generated"
    }
}
