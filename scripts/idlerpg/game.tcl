# The game clock. Runs every self_clock seconds, like rpcheck() in the Perl bot.

proc ::irpg::tick {} {
    variable cfg
    variable timerid
    set timerid [utimer $cfg(self_clock) ::irpg::tick]
    if {[catch {rpcheck} err]} {
        putlog "IRPG: tick error: $err"
    }
}

proc ::irpg::rpcheck {} {
    variable cfg
    variable lasttime
    variable rpreport
    variable quest
    if {$lasttime == 0} { return }
    checksplits
    set onl [online_accounts]
    set online [llength $onl]
    if {!$online} {
        set lasttime [clock seconds]
        return
    }
    set onlineevil 0
    set onlinegood 0
    foreach n $onl {
        switch -- [pget $n alignment] {
            e { incr onlineevil }
            g { incr onlinegood }
        }
    }
    set s $cfg(self_clock)
    if {!$cfg(noscale)} {
        if {[frand [expr {20 * 86400.0 / $s}]] < $online} { hog }
        if {[frand [expr {24 * 86400.0 / $s}]] < $online} { team_battle }
        if {[frand [expr {8 * 86400.0 / $s}]] < $online} { calamity }
        if {[frand [expr {4 * 86400.0 / $s}]] < $online} { godsend }
    } else {
        if {[frand 4000] < 1} { hog }
        if {[frand 4000] < 1} { team_battle }
        if {[frand 4000] < 1} { calamity }
        if {[frand 2000] < 1} { godsend }
    }
    if {[frand [expr {8 * 86400.0 / $s}]] < $onlineevil} { evilness }
    if {[frand [expr {12 * 86400.0 / $s}]] < $onlinegood} { goodness }

    moveplayers

    if {$rpreport % 120 == 0 && $cfg(writequestfile)} { writequestfile }

    if {[clock seconds] > $quest(qtime)} {
        if {![llength $quest(questers)]} {
            quest_start
        } elseif {$quest(type) == 1} {
            chanmsg [clog "[questers_text] have blessed the realm by completing their quest! 25% of their burden is eliminated."]
            foreach q $quest(questers) { pset $q next [expr {int([pget $q next] * .75)}] }
            set quest(questers) {}
            set quest(qtime) [expr {[clock seconds] + 21600}]
        }
    }

    if {$rpreport > 0 && $rpreport % 36000 == 0} {
        top_report
        if {[catch {backup} err]} { putlog "IRPG: backup failed: $err" }
    }
    if {$rpreport > 0 && $rpreport % 1200 == 0} { challenge_check }
    if {$rpreport % 600 == 0 && $cfg(pausemode)} {
        chanmsg "WARNING: Cannot write database in PAUSE mode!"
    }

    restore_tick

    set now [clock seconds]
    set diff [expr {$now - $lasttime}]
    foreach n [online_accounts] {
        set nick [pget $n nick]
        if {$nick eq "" || ![onchan $nick $cfg(channel)]} { continue }
        padd $n next [expr {-$diff}]
        padd $n idled $diff
        if {[pget $n next] < 1} { levelup $n }
    }
    if {!$cfg(pausemode) && $rpreport % 60 == 0} { db_save }

    # Automated announcements
    variable last_top_announce
    variable last_register_announce
    variable last_penalty_announce
    if {$cfg(announce_top_players) > 0 && $now - $last_top_announce >= $cfg(announce_top_players)} {
        announce_top_players
        set last_top_announce $now
    }
    if {$cfg(announce_register) > 0 && $now - $last_register_announce >= $cfg(announce_register)} {
        announce_register
        set last_register_announce $now
    }
    if {$cfg(announce_penalties) > 0 && $now - $last_penalty_announce >= $cfg(announce_penalties)} {
        announce_penalties
        set last_penalty_announce $now
    }

    incr rpreport $s
    set lasttime $now
}

proc ::irpg::levelup {name} {
    variable cfg
    padd $name level 1
    set level [pget $name level]
    if {$level > 60} {
        set next [expr {int($cfg(rpbase) * pow($cfg(rpstep), 60)) + 86400 * ($level - 60)}]
    } else {
        set next [expr {int($cfg(rpbase) * pow($cfg(rpstep), $level))}]
    }
    pset $name next $next
    chanmsg "$name, the [pget $name class], has attained level $level! Next level in [duration $next]."
    find_item $name
    challenge_opp $name
}

proc ::irpg::cmp_rank {a b} {
    set la [lindex $a 1]
    set lb [lindex $b 1]
    if {$la != $lb} { return [expr {$la > $lb ? -1 : 1}] }
    set na [lindex $a 2]
    set nb [lindex $b 2]
    if {$na == $nb} { return 0 }
    return [expr {$na < $nb ? -1 : 1}]
}

proc ::irpg::top_report {} {
    variable rps
    set list {}
    foreach n [array names rps] {
        lappend list [list $n [pget $n level] [pget $n next]]
    }
    set sorted [lsort -command ::irpg::cmp_rank $list]
    if {[llength $sorted]} { chanmsg "[lgrnd] \037Idle RPG Top Players:\037" }
    for {set i 0} {$i < 3 && $i < [llength $sorted]} {incr i} {
        set n [lindex [lindex $sorted $i] 0]
        chanmsg "$n, the level [pget $n level] [pget $n class], is #[expr {$i + 1}]! Next level in [duration [pget $n next]]."
    }
}

proc ::irpg::announce_top_players {} {
    variable rps
    variable cfg
    set list {}
    foreach n [array names rps] {
        lappend list [list $n [pget $n level] [pget $n next]]
    }
    set sorted [lsort -command ::irpg::cmp_rank $list]
    if {![llength $sorted]} { return }
    chanmsg "[lgrnd] \037Top IdleRPG Players:\037"
    for {set i 0} {$i < 5 && $i < [llength $sorted]} {incr i} {
        set n [lindex [lindex $sorted $i] 0]
        chanmsg "#[expr {$i + 1}] $n, the level [pget $n level] [pget $n class], next level in [duration [pget $n next]]."
    }
}

proc ::irpg::announce_register {} {
    variable cfg
    chanmsg "New players can join the game! Type /msg $cfg(botnick) REGISTER <char> <password> <class> to start playing."
}

proc ::irpg::announce_penalties {} {
    variable cfg
    set disabled {}
    foreach e {privmsg notice nick part kick quit logout quest} {
        if {![pen_enabled $e]} { lappend disabled $e }
    }
    if {[llength $disabled]} {
        chanmsg "[lgrnd] \002Penalty\002 IdleRPG currently disabled: [join $disabled {, }]."
    } else {
        chanmsg "[lgnrd] All penalty events are currently \002enabled.\002"
    }
}

proc ::irpg::challenge_check {} {
    set onl [online_accounts]
    set elig {}
    foreach n $onl {
        if {[pget $n level] > 44} { lappend elig $n }
    }
    if {[llength $elig] > 0.15 * [llength $onl]} {
        challenge_opp [pick $elig]
    }
}

# Players whose pending auto-login has not been confirmed by the channel yet.
proc ::irpg::on_bot_join {} {
    variable lasttime
    variable pending
    variable pending_deadline
    variable pending_total
    variable restored
    set lasttime [clock seconds]
    array unset pending
    foreach n [online_accounts] { set pending($n) 1 }
    set pending_total [array size pending]
    set restored 0
    set pending_deadline [expr {[clock seconds] + 120}]
}

# Restores online sessions after a restart or reconnect when a player is still in the
# channel from the same host. Anyone not matched by the deadline is logged out.
proc ::irpg::restore_tick {} {
    variable cfg
    variable pending
    variable pending_deadline
    variable pending_total
    variable restored
    if {![array size pending]} { return }
    foreach n [array names pending] {
        if {![acct_exists $n] || ![pget $n online]} {
            unset pending($n)
            continue
        }
        set nick [pget $n nick]
        set want [lindex [split [pget $n userhost] !] end]
        if {[onchan $nick $cfg(channel)] && [getchanhost $nick $cfg(channel)] eq $want} {
            unset pending($n)
            incr restored
        }
    }
    if {[clock seconds] >= $pending_deadline} {
        foreach n [array names pending] {
            logout_account $n
            unset pending($n)
        }
        if {$pending_total > 0} {
            chanmsg "$restored of $pending_total users matching their hosts were logged back in automatically."
        }
        set pending_total 0
    }
}

proc ::irpg::checksplits {} {
    variable cfg
    variable netsplits
    if {!$cfg(detectsplits)} { return }
    set now [clock seconds]
    foreach host [array names netsplits] {
        if {$now - [dict get $netsplits($host) time] > $cfg(splitwait)} {
            set acct [dict get $netsplits($host) account]
            if {[acct_exists $acct]} { logout_account $acct }
            unset netsplits($host)
        }
    }
}

# Players move about the map. Two players on the same square may fight.
proc ::irpg::moveplayers {} {
    variable cfg
    variable quest
    variable lasttime
    variable posuser
    variable posbattled
    if {$lasttime == 0} { return }
    set online [online_accounts]
    set count [llength $online]
    if {!$count} { return }
    for {set i 0} {$i < $cfg(self_clock)} {incr i} {
        array unset posuser
        array unset posbattled
        if {$quest(type) == 2 && [llength $quest(questers)]} {
            set allgo 1
            foreach q $quest(questers) {
                set target [expr {$quest(stage) == 1 ? $quest(p1) : $quest(p2)}]
                if {[pget $q x] != [lindex $target 0] || [pget $q y] != [lindex $target 1]} {
                    set allgo 0
                    break
                }
            }
            if {$quest(stage) == 1 && $allgo} {
                set quest(stage) 2
            } elseif {$quest(stage) == 2 && $allgo} {
                quest_complete_journey
            } else {
                foreach p $online {
                    if {[lsearch -exact $quest(questers) $p] < 0} { move_player $p $count }
                }
                foreach q $quest(questers) { quest_step $q }
            }
        } else {
            foreach p $online { move_player $p $count }
        }
    }
}

proc ::irpg::move_player {p count} {
    variable cfg
    variable posuser
    variable posbattled
    set x [expr {[pget $p x] + [irand 3] - 1}]
    set y [expr {[pget $p y] + [irand 3] - 1}]
    if {$x > $cfg(mapx)} { set x 0 }
    if {$y > $cfg(mapy)} { set y 0 }
    if {$x < 0} { set x $cfg(mapx) }
    if {$y < 0} { set y $cfg(mapy) }
    pset $p x $x
    pset $p y $y
    set key "$x,$y"
    if {[info exists posuser($key)] && !$posbattled($key)} {
        set other $posuser($key)
        if {[account_is_admin $other] && ![account_is_admin $p] && [frand 100] < 1} {
            chanmsg "$p encounters $other and bows humbly."
        }
        if {[frand $count] < 1} {
            set posbattled($key) 1
            collision_fight $p $other
        }
    } else {
        set posbattled($key) 0
        set posuser($key) $p
    }
}

proc ::irpg::quest_step {q} {
    variable quest
    if {[frand 100] >= 1} { return }
    set target [expr {$quest(stage) == 1 ? $quest(p1) : $quest(p2)}]
    set tx [lindex $target 0]
    set ty [lindex $target 1]
    if {[pget $q x] != $tx} {
        pset $q x [expr {[pget $q x] + ([pget $q x] < $tx ? 1 : -1)}]
    }
    if {[pget $q y] != $ty} {
        pset $q y [expr {[pget $q y] + ([pget $q y] < $ty ? 1 : -1)}]
    }
}

proc ::irpg::quest_complete_journey {} {
    variable quest
    chanmsg [clog "[questers_text] have completed their journey! 25% of their burden is eliminated."]
    foreach q $quest(questers) { pset $q next [expr {int([pget $q next] * .75)}] }
    set quest(questers) {}
    set quest(qtime) [expr {[clock seconds] + 3600}]
    set quest(type) 1
    writequestfile
}
