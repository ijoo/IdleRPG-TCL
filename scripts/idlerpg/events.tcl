# Random events, combat, items and quests.

proc ::irpg::itemsum {name {battle 0}} {
    variable cfg
    if {$name eq $cfg(botnick)} {
        set max 0
        foreach n [array names ::irpg::rps] {
            set s [itemsum $n]
            if {$s > $max} { set max $s }
        }
        return [expr {$max + 1}]
    }
    if {![acct_exists $name]} { return -1 }
    set sum 0
    foreach col [item_columns] { incr sum [ival [pget $name $col]] }
    if {$battle} {
        switch -- [pget $name alignment] {
            e { return [expr {int($sum * .9)}] }
            g { return [expr {int($sum * 1.1)}] }
        }
    }
    return $sum
}

proc ::irpg::item_types {} {
    variable itemmap
    return [dict keys $itemmap]
}

# Random line of events.txt matching a glob (and optional regexp), chosen with
# reservoir sampling as in the Perl bot. Returns "" if none match.
proc ::irpg::event_pick {globpat {re ""}} {
    variable dir
    variable cfg
    set path [file join $dir $cfg(eventsfile)]
    if {[catch {open $path r} f]} {
        putlog "IRPG: cannot open $path: $f"
        return ""
    }
    set i 0
    set chosen ""
    while {[gets $f line] >= 0} {
        if {![string match $globpat $line]} { continue }
        if {$re ne "" && ![regexp $re $line]} { continue }
        incr i
        if {[irand $i] == 0} { set chosen $line }
    }
    close $f
    return $chosen
}

proc ::irpg::hog {} {
    set players [online_accounts]
    if {![llength $players]} { return }
    set p [pick $players]
    set win [irand 5]
    set time [expr {int(((5 + [irand 71]) / 100.0) * [pget $p next])}]
    set lvl [expr {[pget $p level] + 1}]
    if {$win} {
        chanmsg [clog "Verily I say unto thee, the Heavens have burst forth, and the blessed hand of God carried $p [duration $time] toward level $lvl."]
        padd $p next [expr {-$time}]
    } else {
        chanmsg [clog "Thereupon He stretched out His little finger among them and consumed $p with fire, slowing the heathen [duration $time] from level $lvl."]
        padd $p next $time
    }
    chanmsg "$p reaches next level in [duration [pget $p next]]."
}

proc ::irpg::team_battle {} {
    set opp [online_accounts]
    if {[llength $opp] < 6} { return }
    while {[llength $opp] > 6} {
        set idx [irand [llength $opp]]
        set opp [lreplace $opp $idx $idx]
    }
    set opp [shuffle $opp]
    set a [lindex $opp 0]
    set b [lindex $opp 1]
    set c [lindex $opp 2]
    set d [lindex $opp 3]
    set e [lindex $opp 4]
    set f [lindex $opp 5]
    set mysum [expr {[itemsum $a 1] + [itemsum $b 1] + [itemsum $c 1]}]
    set oppsum [expr {[itemsum $d 1] + [itemsum $e 1] + [itemsum $f 1]}]
    set gain [pget $a next]
    foreach p [list $b $c] {
        if {$gain > [pget $p next]} { set gain [pget $p next] }
    }
    set gain [expr {int($gain * .20)}]
    set myroll [irand $mysum]
    set opproll [irand $oppsum]
    set us "$a, $b, and $c \[$myroll/$mysum\]"
    set them "$d, $e, and $f \[$opproll/$oppsum\]"
    if {$myroll >= $opproll} {
        chanmsg [clog "$us have team battled $them and won! [duration $gain] is removed from their clocks."]
        foreach p [list $a $b $c] { padd $p next [expr {-$gain}] }
    } else {
        chanmsg [clog "$us have team battled $them and lost! [duration $gain] is added to their clocks."]
        foreach p [list $a $b $c] { padd $p next $gain }
    }
}

proc ::irpg::calamity {} {
    set players [online_accounts]
    if {![llength $players]} { return }
    set p [pick $players]
    if {[frand 10] < 1} {
        set type [pick {amulet charm weapon tunic {set of leggings} shield}]
        set col [dict get $::irpg::itemmap $type]
        switch -- $type {
            amulet { set text "$p fell, chipping the stone in his amulet!" }
            charm { set text "$p slipped and dropped his charm in a dirty bog!" }
            weapon { set text "$p left his weapon out in the rain to rust!" }
            tunic { set text "$p spilled a level 7 shrinking potion on his tunic!" }
            shield { set text "$p's shield was damaged by a dragon's fiery breath!" }
            default { set text "$p burned a hole through his leggings while ironing them!" }
        }
        chanmsg [clog "$text $p's $type loses 10% of its effectiveness."]
        set old [pget $p $col]
        pset $p $col "[expr {int([ival $old] * .9)}][suffix $old]"
    } else {
        set time [expr {int(int(5 + [irand 8]) / 100.0 * [pget $p next])}]
        set line [event_pick "C *"]
        set actioned [expr {$line eq "" ? "was struck by misfortune" : [string range $line 2 end]}]
        chanmsg [clog "$p $actioned. This terrible calamity has slowed them [duration $time] from level [expr {[pget $p level] + 1}]."]
        padd $p next $time
        chanmsg "$p reaches next level in [duration [pget $p next]]."
    }
}

proc ::irpg::godsend {} {
    set players [online_accounts]
    if {![llength $players]} { return }
    set p [pick $players]
    if {[frand 10] < 1} {
        set type [pick {amulet charm weapon tunic {set of leggings} shield}]
        set col [dict get $::irpg::itemmap $type]
        switch -- $type {
            amulet { set text "$p's amulet was blessed by a passing cleric!" }
            charm { set text "$p's charm ate a bolt of lightning!" }
            weapon { set text "$p sharpened the edge of his weapon!" }
            tunic { set text "A magician cast a spell of Rigidity on $p's tunic!" }
            shield { set text "$p reinforced his shield with a dragon's scales!" }
            default { set text "The local wizard imbued $p's pants with a Spirit of Fortitude!" }
        }
        chanmsg [clog "$text $p's $type gains 10% effectiveness."]
        set old [pget $p $col]
        pset $p $col "[expr {int([ival $old] * 1.1)}][suffix $old]"
    } else {
        set time [expr {int(int(5 + [irand 8]) / 100.0 * [pget $p next])}]
        set line [event_pick "G *"]
        set actioned [expr {$line eq "" ? "was blessed" : [string range $line 2 end]}]
        chanmsg [clog "$p $actioned! This wondrous godsend has accelerated them [duration $time] towards level [expr {[pget $p level] + 1}]."]
        padd $p next [expr {-$time}]
        chanmsg "$p reaches next level in [duration [pget $p next]]."
    }
}

proc ::irpg::goodness {} {
    set good {}
    foreach n [online_accounts] {
        if {[pget $n alignment] eq "g"} { lappend good $n }
    }
    if {[llength $good] < 2} { return }
    while {[llength $good] > 2} {
        set idx [irand [llength $good]]
        set good [lreplace $good $idx $idx]
    }
    set a [lindex $good 0]
    set b [lindex $good 1]
    set gain [expr {5 + [irand 8]}]
    chanmsg [clog "$a and $b have not let the iniquities of evil men poison them. Together have they prayed to their god, and it is his light that now shines upon them. $gain% of their time is removed from their clocks."]
    pset $a next [expr {int([pget $a next] * (1 - ($gain / 100.0)))}]
    pset $b next [expr {int([pget $b next] * (1 - ($gain / 100.0)))}]
    chanmsg "$a reaches next level in [duration [pget $a next]]."
    chanmsg "$b reaches next level in [duration [pget $b next]]."
}

proc ::irpg::evilness {} {
    set evil {}
    foreach n [online_accounts] {
        if {[pget $n alignment] eq "e"} { lappend evil $n }
    }
    if {![llength $evil]} { return }
    set me [pick $evil]
    if {[irand 2] < 1} {
        set good {}
        foreach n [online_accounts] {
            if {[pget $n alignment] eq "g"} { lappend good $n }
        }
        if {![llength $good]} { return }
        set target [pick $good]
        set type [pick [item_types]]
        set col [dict get $::irpg::itemmap $type]
        if {[ival [pget $target $col]] > [ival [pget $me $col]]} {
            set mine [pget $me $col]
            pset $me $col [pget $target $col]
            pset $target $col $mine
            chanmsg [clog "$me stole $target's level [ival [pget $me $col]] $type while they were sleeping! $me leaves his old level [ival [pget $target $col]] $type behind, which $target then takes."]
        } else {
            notice_to [pget $me nick] "You made to steal $target's $type, but realized it was lower level than your own. You creep back into the shadows."
        }
    } else {
        set gain [expr {1 + [irand 5]}]
        chanmsg [clog "$me is forsaken by his evil god. [duration [expr {int([pget $me next] * ($gain / 100.0))}]] is added to his clock."]
        pset $me next [expr {int([pget $me next] * (1 + ($gain / 100.0)))}]
        chanmsg "$me reaches next level in [duration [pget $me next]]."
    }
}

proc ::irpg::collision_fight {u opp} {
    variable cfg
    set mysum [itemsum $u 1]
    set oppsum [itemsum $opp 1]
    set myroll [irand $mysum]
    set opproll [irand $oppsum]
    if {$myroll >= $opproll} {
        set gain [expr {int([pget $opp level] / 4)}]
        if {$gain < 7} { set gain 7 }
        set gain [expr {int(($gain / 100.0) * [pget $u next])}]
        chanmsg [clog "$u \[$myroll/$mysum\] has come upon $opp \[$opproll/$oppsum\] and taken them in combat! [duration $gain] is removed from $u's clock."]
        padd $u next [expr {-$gain}]
        chanmsg "$u reaches next level in [duration [pget $u next]]."
        if {[frand 35] < 1} {
            set gain [expr {int(((5 + [irand 20]) / 100.0) * [pget $opp next])}]
            chanmsg [clog "$u has dealt $opp a Critical Strike! [duration $gain] is added to $opp's clock."]
            padd $opp next $gain
            chanmsg "$opp reaches next level in [duration [pget $opp next]]."
        } elseif {[frand 25] < 1 && [pget $u level] > 19} {
            swap_item $u $opp "In the fierce battle"
        }
    } else {
        set gain [expr {int([pget $opp level] / 7)}]
        if {$gain < 7} { set gain 7 }
        set gain [expr {int(($gain / 100.0) * [pget $u next])}]
        chanmsg [clog "$u \[$myroll/$mysum\] has come upon $opp \[$opproll/$oppsum\] and been defeated in combat! [duration $gain] is added to $u's clock."]
        padd $u next $gain
        chanmsg "$u reaches next level in [duration [pget $u next]]."
    }
}

# Winner takes the opponent's better item of a random type.
proc ::irpg::swap_item {u opp lead} {
    set type [pick [item_types]]
    set col [dict get $::irpg::itemmap $type]
    if {[ival [pget $opp $col]] > [ival [pget $u $col]]} {
        chanmsg [clog "$lead, $opp dropped his level [ival [pget $opp $col]] $type! $u picks it up, tossing his old level [ival [pget $u $col]] $type to $opp."]
        set tmp [pget $u $col]
        pset $u $col [pget $opp $col]
        pset $opp $col $tmp
    }
}

proc ::irpg::challenge_opp {u} {
    variable cfg
    if {[pget $u level] < 25} {
        if {[frand 4] >= 1} { return }
    }
    set opps {}
    foreach n [online_accounts] {
        if {$n ne $u} { lappend opps $n }
    }
    if {![llength $opps]} { return }
    set opp [pick $opps]
    if {[frand [expr {[llength $opps] + 1}]] < 1} { set opp $cfg(botnick) }
    set mysum [itemsum $u 1]
    set oppsum [itemsum $opp 1]
    set myroll [irand $mysum]
    set opproll [irand $oppsum]
    set isbot [expr {$opp eq $cfg(botnick)}]
    if {$myroll >= $opproll} {
        if {$isbot} { set gain 20 } else { set gain [expr {int([pget $opp level] / 4)}] }
        if {$gain < 7} { set gain 7 }
        set gain [expr {int(($gain / 100.0) * [pget $u next])}]
        chanmsg [clog "$u \[$myroll/$mysum\] has challenged $opp \[$opproll/$oppsum\] in combat and won! [duration $gain] is removed from $u's clock."]
        padd $u next [expr {-$gain}]
        chanmsg "$u reaches next level in [duration [pget $u next]]."
        switch -- [pget $u alignment] {
            g { set csfactor 50 }
            e { set csfactor 20 }
            default { set csfactor 35 }
        }
        if {[frand $csfactor] < 1 && !$isbot} {
            set gain [expr {int(((5 + [irand 20]) / 100.0) * [pget $opp next])}]
            chanmsg [clog "$u has dealt $opp a Critical Strike! [duration $gain] is added to $opp's clock."]
            padd $opp next $gain
            chanmsg "$opp reaches next level in [duration [pget $opp next]]."
        } elseif {[frand 25] < 1 && !$isbot && [pget $u level] > 19} {
            swap_item $u $opp "In the fierce battle"
        }
    } else {
        if {$isbot} { set gain 10 } else { set gain [expr {int([pget $opp level] / 7)}] }
        if {$gain < 7} { set gain 7 }
        set gain [expr {int(($gain / 100.0) * [pget $u next])}]
        chanmsg [clog "$u \[$myroll/$mysum\] has challenged $opp \[$opproll/$oppsum\] in combat and lost! [duration $gain] is added to $u's clock."]
        padd $u next $gain
        chanmsg "$u reaches next level in [duration [pget $u next]]."
    }
}

# Finds an item for a player on level-up. Rare artifacts are checked first.
proc ::irpg::find_item {name} {
    set plevel [pget $name level]
    set nick [pget $name nick]
    set type [pick [item_types]]
    set level 1
    for {set num 1} {$num <= int($plevel * 1.5)} {incr num} {
        if {[frand [expr {pow(1.4, $num / 4.0)}]] < 1} { set level $num }
    }
    # {minimum level, base level, random span, item column, marker, message}
    set artifacts {
        25 50 25 item_helm a {Mattt's Omniscience Grand Crown! Your enemies fall before you as you anticipate their every move.}
        25 50 25 item_ring h {Juliet's Glorious Ring of Sparkliness! Your enemies are blinded by both its glory and their greed as you bring desolation upon them.}
        30 75 25 item_tunic b {Res0's Protectorate Plate Mail! Your enemies cower in fear as their attacks have no effect on you.}
        35 100 25 item_amulet c {Dwyn's Storm Magic Amulet! Your enemies are swept away by an elemental fury before the war has even begun}
        40 150 25 item_weapon d {Jotun's Fury Colossal Sword! Your enemies' hatred is brought to a quick end as you arc your wrist, dealing the crushing blow.}
        45 175 26 item_weapon e {Drdink's Cane of Blind Rage! Your enemies are tossed aside as you blindly swing your arm around hitting stuff.}
        48 250 51 item_boots f {Mrquick's Magical Boots of Swiftness! Your enemies are left choking on your dust as you run from them very, very quickly.}
        52 300 51 item_weapon g {Jeff's Cluehammer of Doom! Your enemies are left with a sudden and intense clarity of mind... even as you relieve them of it.}
    }
    foreach {minlvl base span col marker text} $artifacts {
        if {$plevel < $minlvl || [frand 40] >= 1} { continue }
        set ulevel [expr {$base + [irand $span]}]
        if {$ulevel >= $level && $ulevel > [ival [pget $name $col]]} {
            notice_to $nick "The light of the gods shines down upon you! You have found the level $ulevel $text"
            pset $name $col "$ulevel$marker"
            return
        }
        break
    }
    set col [dict get $::irpg::itemmap $type]
    if {$level > [ival [pget $name $col]]} {
        notice_to $nick "You found a level $level $type! Your current $type is only level [ival [pget $name $col]], so it seems Luck is with you!"
        pset $name $col $level
    } else {
        notice_to $nick "You found a level $level $type. Your current $type is level [ival [pget $name $col]], so it seems Luck is against you. You toss the $type."
    }
}

proc ::irpg::questers_text {} {
    variable quest
    set q $quest(questers)
    return "[lindex $q 0], [lindex $q 1], [lindex $q 2], and [lindex $q 3]"
}

proc ::irpg::quest_start {} {
    variable quest
    set now [clock seconds]
    set cand {}
    foreach n [online_accounts] {
        if {[pget $n level] > 39 && $now - [pget $n lastlogin] > 36000} { lappend cand $n }
    }
    if {[llength $cand] < 4} {
        set quest(questers) {}
        return
    }
    while {[llength $cand] > 4} {
        set idx [irand [llength $cand]]
        set cand [lreplace $cand $idx $idx]
    }
    set line [event_pick "Q*" {^Q[12] }]
    if {$line eq ""} {
        putlog "IRPG: no Q1/Q2 quest lines in events file."
        set quest(questers) {}
        return
    }
    set quest(questers) $cand
    if {[regexp {^Q1 (.*)} $line -> text]} {
        set quest(text) $text
        set quest(type) 1
        set quest(qtime) [expr {$now + 43200 + [irand 43201]}]
    } elseif {[regexp {^Q2 (\d+) (\d+) (\d+) (\d+) (.*)} $line -> x1 y1 x2 y2 text]} {
        set quest(p1) [list $x1 $y1]
        set quest(p2) [list $x2 $y2]
        set quest(text) $text
        set quest(type) 2
        set quest(stage) 1
    }
    if {$quest(type) == 1} {
        chanmsg "[questers_text] have been chosen by the gods to $quest(text). Quest to end in [duration [expr {$quest(qtime) - $now}]]."
    } else {
        chanmsg "[questers_text] have been chosen by the gods to $quest(text). Participants must first reach \[[lindex $quest(p1) 0],[lindex $quest(p1) 1]\], then \[[lindex $quest(p2) 0],[lindex $quest(p2) 1]\]."
    }
    writequestfile
}

proc ::irpg::writequestfile {} {
    variable cfg
    variable quest
    if {!$cfg(writequestfile)} { return }
    set path [file join $cfg(botdir) $cfg(questfile)]
    if {[catch {open $path w} f]} {
        chanmsg "Error: cannot open $cfg(questfile): $f"
        return
    }
    if {[llength $quest(questers)]} {
        if {$quest(type) == 1} {
            puts $f "T $quest(text)"
            puts $f "Y 1"
            puts $f "S $quest(qtime)"
            for {set i 0} {$i < 4} {incr i} {
                puts $f "P[expr {$i + 1}] [lindex $quest(questers) $i]"
            }
        } elseif {$quest(type) == 2} {
            puts $f "T $quest(text)"
            puts $f "Y 2"
            puts $f "S $quest(stage)"
            puts $f "P [lindex $quest(p1) 0] [lindex $quest(p1) 1] [lindex $quest(p2) 0] [lindex $quest(p2) 1]"
            for {set i 0} {$i < 4} {incr i} {
                set q [lindex $quest(questers) $i]
                puts $f "P[expr {$i + 1}] $q [pget $q x] [pget $q y]"
            }
        }
    }
    close $f
}
