# Helpers: random numbers, durations, timestamps, output and logging.

proc ::irpg::frand {n} {
    return [expr {rand() * $n}]
}

proc ::irpg::irand {n} {
    return [expr {int(rand() * $n)}]
}

# Perl int() semantics for item values such as "50a".
proc ::irpg::ival {s} {
    if {[regexp {^\s*(-?\d+)} $s -> n]} { return $n }
    return 0
}

# Trailing non-digit marker on an item value (artifacts carry a letter).
proc ::irpg::suffix {s} {
    if {[regexp {(\D)$} $s -> c]} { return $c }
    return ""
}

proc ::irpg::pick {items} {
    return [lindex $items [irand [llength $items]]]
}

proc ::irpg::shuffle {items} {
    for {set i [expr {[llength $items] - 1}]} {$i > 0} {incr i -1} {
        set j [irand [expr {$i + 1}]]
        set tmp [lindex $items $i]
        lset items $i [lindex $items $j]
        lset items $j $tmp
    }
    return $items
}

proc ::irpg::words {text} {
    return [regexp -inline -all {\S+} $text]
}

proc ::irpg::duration {s} {
    if {![regexp {^\d+$} $s]} { return "NA ($s)" }
    set days [expr {$s / 86400}]
    set plural [expr {$days == 1 ? "" : "s"}]
    return [format "%d day%s, %02d:%02d:%02d" $days $plural \
        [expr {($s % 86400) / 3600}] [expr {($s % 3600) / 60}] [expr {$s % 60}]]
}

proc ::irpg::ts {} {
    return [clock format [clock seconds] -format {[%m/%d/%y %H:%M:%S] }]
}

proc ::irpg::chunks {text size} {
    set out {}
    while {[string length $text] > $size} {
        lappend out [string range $text 0 [expr {$size - 1}]]
        set text [string range $text $size end]
    }
    lappend out $text
    return $out
}

# Sends text, honouring the silent mode (0 = all, 1 = no channel, 2 = no private, 3 = none).
proc ::irpg::say {kind target text {force 0}} {
    variable cfg
    if {!$force} {
        if {$cfg(silentmode) == 3} { return }
        set c [string index $target 0]
        if {$cfg(silentmode) == 2 && $c ne "#" && $c ne "&" && $c ne "+"} { return }
    }
    foreach part [chunks $text 400] {
        if {$part ne ""} { puthelp "$kind $target :$part" }
    }
}

proc ::irpg::msg_to {target text {force 0}} {
    say PRIVMSG $target $text $force
}

proc ::irpg::notice_to {target text {force 0}} {
    say NOTICE $target $text $force
}

proc ::irpg::chanmsg {text} {
    variable cfg
    if {$cfg(silentmode) & 1} { return }
    msg_to $cfg(channel) $text
}

# Appends an event to the modifiers log and returns it, so it can be nested in chanmsg.
proc ::irpg::clog {text} {
    variable cfg
    set path [file join $cfg(botdir) $cfg(modsfile)]
    if {[catch {open $path a} f]} {
        putlog "IRPG: cannot open $path: $f"
        return $text
    }
    puts $f "[ts]$text"
    close $f
    return $text
}
