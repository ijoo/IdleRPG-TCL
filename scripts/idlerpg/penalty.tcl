# Penalties add time to a player's clock. Each event can be toggled by the
# owner with PENALTY. Logging out happens whether or not the penalty applies.

proc ::irpg::pen_enabled {event} {
    if {$event eq "reset"} { set event logout }
    return [expr {[setting_get pen.$event 1] eq "1"}]
}

# Applies the penalty for event to account name. len is the message length for
# privmsg and notice. Returns the number of seconds added (0 if none).
proc ::irpg::penalize {name event {len 0}} {
    variable cfg
    if {![acct_exists $name]} { return 0 }
    quest_check $name
    if {![pen_enabled $event]} { return 0 }
    set level [pget $name level]
    switch -- $event {
        privmsg { set base $len; set field pen_mesg; set why "talking in the channel" }
        notice  { set base $len; set field pen_mesg; set why "sending a notice" }
        nick    { set base 30;   set field pen_nick; set why "changing your nickname" }
        part    { set base 200;  set field pen_part; set why "parting the channel" }
        kick    { set base 250;  set field pen_kick; set why "being kicked" }
        quit    { set base 20;   set field pen_quit; set why "quitting" }
        logout  { set base 20;   set field pen_logout; set why "the LOGOUT command" }
        reset   { set base 20;   set field pen_reset; set why "a password reset" }
        default { return 0 }
    }
    set pen [expr {int($base * pow($cfg(rppenstep), $level))}]
    if {$cfg(limitpen) > 0 && $pen > $cfg(limitpen)} { set pen $cfg(limitpen) }
    if {$pen <= 0} { return 0 }
    padd $name $field $pen
    padd $name next $pen
    if {[pget $name online]} {
        notice_to [pget $name nick] "Penalty of [duration $pen] added to your timer for $why."
    }
    return $pen
}

# If a quest member is penalized, the gods abandon the quest and every online
# player is penalized.
proc ::irpg::quest_check {name} {
    variable cfg
    variable quest
    if {[lsearch -exact $quest(questers) $name] < 0} { return }
    if {![pen_enabled quest]} { return }
    chanmsg [clog "$name's prudence and self-regard has brought the wrath of the gods upon the realm. Hell rains down upon you as you beg for the sweet release of death."]
    foreach p [online_accounts] {
        set gain [expr {int(15 * pow($cfg(rppenstep), [pget $p level]))}]
        padd $p pen_quest $gain
        padd $p next $gain
    }
    set quest(questers) {}
    set quest(qtime) [expr {[clock seconds] + 43200}]
    writequestfile
}

proc ::irpg::logout_account {name} {
    pset $name online 0
}
