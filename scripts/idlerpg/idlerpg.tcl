# IdleRPG for Eggdrop: a Tcl port of IRPG bot v3.1.2 (by jotun).
# Requires Covid.5.0.tcl to be sourced first, and the Eggdrop pbkdf2 module.
# Load it from eggdrop.conf AFTER Covid:
#   source scripts/Covid.5.0.tcl
#   source scripts/idlerpg/idlerpg.tcl

namespace eval ::irpg {
    variable dir [file dirname [file normalize [info script]]]
    variable timerid ""
}

if {![info exists ::owner] || [llength [info procs cvd_netget]] == 0} {
    putlog "IRPG: NOT LOADED. Covid (scripts/Covid.5.0.tcl) must be loaded first."
    putlog "IRPG: add 'source scripts/Covid.5.0.tcl' above the IRPG source line in eggdrop.conf."
    return
}
if {[llength [info commands pbkdf2]] == 0} {
    putlog "IRPG: NOT LOADED. The pbkdf2 module is not loaded. Add 'loadmodule pbkdf2' to eggdrop.conf."
    return
}
if {[catch {package require sqlite3} err]} {
    putlog "IRPG: NOT LOADED. SQLite is not available to Tcl: $err"
    return
}

foreach part {config util db auth penalty game events commands channel} {
    source [file join $::irpg::dir $part.tcl]
}

proc ::irpg::bind_all {} {
    set msgs {
        idlehelp cmd_help register cmd_register login cmd_login logout cmd_logout
        status cmd_status whoami cmd_whoami newpass cmd_newpass align cmd_align
        removeme cmd_removeme resetpass cmd_resetpass quest cmd_quest info cmd_info
        hog cmd_hog push cmd_push chpass cmd_chpass chuser cmd_chuser chclass cmd_chclass
        pause cmd_pause silent cmd_silent backup cmd_backup clearq cmd_clearq
        del cmd_del mkadmin cmd_mkadmin deladmin cmd_deladmin penalty cmd_penalty
    }
    foreach {cmd proc} $msgs {
        catch {unbind msg - $cmd ::irpg::$proc}
        bind msg - $cmd ::irpg::$proc
    }
    set others {
        pubm * pub_message
        join * join_event
        part * part_event
        kick * kick_event
        nick * nick_event
        sign * sign_event
    }
    foreach {type mask proc} $others {
        catch {unbind $type - $mask ::irpg::$proc}
        bind $type - $mask ::irpg::$proc
    }
    foreach {keyword proc} {NOTICE raw_notice 330 raw_330 307 raw_307 318 raw_318} {
        catch {unbind raw - $keyword ::irpg::$proc}
        bind raw - $keyword ::irpg::$proc
    }
}

proc ::irpg::init {} {
    variable cfg
    variable timerid
    variable rps
    set cfg(botnick) $::nick
    set cfg(owner) $::owner
    set cfg(channel) [lindex $::basechan 0]
    set cfg(botdir) [pwd]
    variable quest
    if {$quest(qtime) == 0} { set quest(qtime) [expr {[clock seconds] + [irand 3600]}] }
    db_open
    db_load
    bind_all
    if {$timerid ne ""} { catch {killutimer $timerid} }
    set timerid [utimer $cfg(self_clock) ::irpg::tick]
    if {[botonchan $cfg(channel)]} { on_bot_join }
    putlog "IRPG: loaded [array size rps] accounts from $cfg(dbfile); channel $cfg(channel)."
}

::irpg::init
