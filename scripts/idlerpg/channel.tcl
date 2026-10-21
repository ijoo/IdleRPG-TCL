# Channel events: chat penalties, joins, parts, kicks, nick changes, quits
# and netsplits. Penalties and logouts follow the rules in penalty.tcl and
# the NOTE shown to new players. Advertising bans are handled by Covid.

proc ::irpg::is_our_channel {chan} {
    variable cfg
    return [string equal -nocase $chan $cfg(channel)]
}

proc ::irpg::pub_message {nick uhost hand chan text} {
    variable cfg
    if {![is_our_channel $chan] || [string equal -nocase $nick $cfg(botnick)]} { return }
    set char [finduser $nick]
    if {$char ne ""} {
        penalize $char privmsg [string length $text]
    }
}

proc ::irpg::join_event {nick uhost hand chan} {
    variable cfg
    variable joined
    variable netsplits
    if {![is_our_channel $chan]} { return }
    set joined($nick) [clock seconds]
    if {[info exists netsplits("$nick!$uhost")]} { unset netsplits("$nick!$uhost") }
    if {[string equal -nocase $nick $cfg(botnick)]} { on_bot_join }
}

proc ::irpg::part_event {nick uhost hand chan text} {
    variable joined
    if {![is_our_channel $chan]} { return }
    catch {unset joined($nick)}
    set char [finduser $nick]
    if {$char eq ""} { return }
    penalize $char part
    logout_account $char
}

proc ::irpg::kick_event {nick uhost hand chan target reason} {
    variable joined
    if {![is_our_channel $chan]} { return }
    catch {unset joined($target)}
    set char [finduser $target]
    if {$char eq ""} { return }
    penalize $char kick
    logout_account $char
}

proc ::irpg::nick_event {nick uhost hand chan newnick} {
    variable joined
    if {![is_our_channel $chan]} { return }
    if {[info exists joined($nick)]} {
        set joined($newnick) $joined($nick)
        unset joined($nick)
    }
    set char [finduser $nick]
    if {$char eq ""} { return }
    pset $char nick $newnick
    penalize $char nick
    logout_account $char
}

proc ::irpg::sign_event {nick uhost hand chan reason} {
    variable cfg
    variable joined
    variable netsplits
    catch {unset joined($nick)}
    set char [finduser $nick]
    if {$char eq ""} { return }
    if {$cfg(detectsplits) && [regexp {^\S+\.\S+ \S+\.\S+$} $reason]} {
        set netsplits("$nick!$uhost") [dict create time [clock seconds] account $char]
        return
    }
    penalize $char quit
    logout_account $char
}

# Notices from players to anyone but the bot are penalized, as in the Perl bot.
proc ::irpg::raw_notice {from keyword text} {
    variable cfg
    set nick [lindex [split [string trimleft $from :] !] 0]
    set i [string first " :" $text]
    if {$i < 0} { return }
    set target [lindex $text 0]
    if {[string equal -nocase $target $cfg(botnick)]} { return }
    set msg [string range $text [expr {$i + 2}] end]
    set char [finduser $nick]
    if {$char eq ""} { return }
    penalize $char notice [string length $msg]
}
