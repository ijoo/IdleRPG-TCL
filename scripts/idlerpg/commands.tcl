# Private message commands. Players talk to the bot in private; admin and
# superadmin rules are described in auth.tcl.

proc ::irpg::need_login {nick} {
    set char [finduser $nick]
    if {$char eq ""} {
        msg_to $nick "You are not logged in. Use: LOGIN <char> <password>"
    }
    return $char
}

proc ::irpg::bad_password {pass} {
    return [expr {$pass eq "" || [string index $pass 0] eq "-"}]
}

proc ::irpg::cmd_help {nick uhost hand text} {
    msg_to $nick "IdleRPG commands (send them to me in private):"
    msg_to $nick "Players: IDLEHELP | REGISTER <char> <password> <class> | LOGIN <char> <password> | LOGOUT | STATUS \[char\] | WHOAMI | NEWPASS <password> | ALIGN <good|neutral|evil> | REMOVEME | RESETPASS <char> <newpassword> | QUEST | INFO"
    msg_to $nick "Admins (log in first, the owner does not need to): HOG | PUSH <char> <seconds> | CHPASS <char> <password> | CHUSER <char> <newname> | CHCLASS <char> <class> | PAUSE | SILENT <0-3> | BACKUP | CLEARQ"
    msg_to $nick "Superadmins (Covid auth): DEL <char> | MKADMIN <nick|char> | DELADMIN <nick|char> | PENALTY \[<event> <ON|OFF>\]"
    msg_to $nick "Registering, logging in and resetting a password require NickServ identification."
}

proc ::irpg::cmd_register {nick uhost hand text} {
    variable cfg
    variable lastreg
    set a [words $text]
    set char [lindex $a 0]
    set pass [lindex $a 1]
    set class [join [lrange $a 2 end] " "]
    if {[finduser $nick] ne ""} {
        msg_to $nick "Sorry, you are already online as [finduser $nick]."
        return
    }
    if {[llength $a] < 3 || [bad_password $pass]} {
        msg_to $nick "Try: REGISTER <char name> <password> <class>"
        msg_to $nick "IE : REGISTER Poseidon MyPassword God of the Sea"
        return
    }
    if {$cfg(pausemode)} {
        msg_to $nick "Sorry, new accounts may not be registered while the bot is in pause mode; please wait a few minutes and try again."
        return
    }
    if {[name_taken $char]} {
        msg_to $nick "Sorry, that character name is already in use."
        return
    }
    if {[string equal -nocase $char $cfg(botnick)]} {
        msg_to $nick "Sorry, that character name cannot be registered."
        return
    }
    if {![onchan $nick $cfg(channel)]} {
        msg_to $nick "Sorry, you're not in $cfg(channel)."
        return
    }
    if {[string length $char] > 16 || [string length $char] < 1} {
        msg_to $nick "Sorry, character names must be < 17 and > 0 chars long."
        return
    }
    if {[string index $char 0] eq "#"} {
        msg_to $nick "Sorry, character names may not begin with #."
        return
    }
    if {[string first [format %c 1] $char] >= 0} {
        msg_to $nick "Sorry, character names may not include character \\001."
        return
    }
    if {$cfg(noccodes) && ([regexp {[[:cntrl:]]} $char] || [regexp {[[:cntrl:]]} $class])} {
        msg_to $nick "Sorry, neither character names nor classes may include control codes."
        return
    }
    if {$cfg(nononp) && ([regexp {[^[:print:]]} $char] || [regexp {[^[:print:]]} $class])} {
        msg_to $nick "Sorry, neither character names nor classes may include non-printable chars."
        return
    }
    if {[string length $class] > 30} {
        msg_to $nick "Sorry, character classes must be < 31 chars long."
        return
    }
    if {[clock seconds] == $lastreg} {
        msg_to $nick "Wait 1 second and try again."
        return
    }
    ns_check $nick [list ::irpg::finish_register $nick $uhost $char $pass $class]
}

proc ::irpg::name_taken {char} {
    variable cfg
    if {[acct_exists $char]} { return 1 }
    if {!$cfg(casematters)} {
        foreach n [array names ::irpg::rps] {
            if {[string equal -nocase $n $char]} { return 1 }
        }
    }
    return 0
}

proc ::irpg::finish_register {nick uhost char pass class ok account} {
    variable cfg
    variable registrations
    variable lastreg
    if {!$ok} {
        msg_to $nick "You must be identified with NickServ to register. Identify with NickServ, then try again."
        return
    }
    if {[finduser $nick] ne ""} { return }
    if {[name_taken $char]} {
        msg_to $nick "Sorry, that character name is already in use."
        return
    }
    if {![onchan $nick $cfg(channel)]} {
        msg_to $nick "Sorry, you're not in $cfg(channel)."
        return
    }
    new_account $char [hashpass $pass] $class $nick "$nick!$uhost" $account
    set lastreg [clock seconds]
    incr registrations
    db_save
    if {$cfg(voiceonlogin) && [botisop $cfg(channel)]} {
        pushmode $cfg(channel) +v $nick
    }
    chanmsg "Welcome $nick's new player $char, the $class! Next level in [duration $cfg(rpbase)]."
    msg_to $nick "Success! Account $char created. You have $cfg(rpbase) seconds idleness until you reach level 1."
    msg_to $nick "NOTE: The point of the game is to see who can idle the longest. As such, talking in the channel, parting, quitting, and changing nicks all penalize you."
}

proc ::irpg::cmd_login {nick uhost hand text} {
    variable cfg
    set a [words $text]
    if {[finduser $nick] ne ""} {
        notice_to $nick "Sorry, you are already online as [finduser $nick]."
        return
    }
    set char [lindex $a 0]
    set pass [lindex $a 1]
    if {[llength $a] < 2} {
        notice_to $nick "Try: LOGIN <username> <password>"
        return
    }
    if {![acct_exists $char]} {
        notice_to $nick "Sorry, no such account name. Note that account names are case sensitive."
        return
    }
    if {![onchan $nick $cfg(channel)]} {
        notice_to $nick "Sorry, you're not in $cfg(channel)."
        return
    }
    ns_check $nick [list ::irpg::finish_login $nick $uhost $char $pass]
}

proc ::irpg::finish_login {nick uhost char pass ok account} {
    variable cfg
    if {!$ok} {
        notice_to $nick "You must be identified with NickServ to log in."
        return
    }
    if {![acct_exists $char] || [finduser $nick] ne ""} { return }
    if {![checkpass [pget $char pass] $pass]} {
        notice_to $nick "Wrong password."
        return
    }
    if {$cfg(voiceonlogin) && [botisop $cfg(channel)]} {
        pushmode $cfg(channel) +v $nick
    }
    pset $char online 1
    pset $char nick $nick
    pset $char userhost "$nick!$uhost"
    pset $char lastlogin [clock seconds]
    chanmsg "$char, the level [pget $char level] [pget $char class], is now online from nickname $nick. Next level in [duration [pget $char next]]."
    notice_to $nick "Logon successful. Next level in [duration [pget $char next]]."
}

proc ::irpg::cmd_logout {nick uhost hand text} {
    set char [need_login $nick]
    if {$char eq ""} { return }
    penalize $char logout
    logout_account $char
    msg_to $nick "You are logged out."
}

proc ::irpg::cmd_status {nick uhost hand text} {
    variable cfg
    set me [need_login $nick]
    if {$me eq ""} { return }
    if {!$cfg(statuscmd)} { return }
    set target [lindex [words $text] 0]
    if {$target ne ""} {
        if {![acct_exists $target]} {
            msg_to $nick "No such user."
            return
        }
    } else {
        set target $me
    }
    set status [expr {[pget $target online] ? "Online" : "Offline"}]
    msg_to $nick "$target: Level [pget $target level] [pget $target class]; Status: $status; TTL: [duration [pget $target next]]; Idled: [duration [pget $target idled]]; Item sum: [itemsum $target]"
}

proc ::irpg::cmd_whoami {nick uhost hand text} {
    set me [need_login $nick]
    if {$me eq ""} { return }
    msg_to $nick "You are $me, the level [pget $me level] [pget $me class]. Next level in [duration [pget $me next]]"
}

proc ::irpg::cmd_newpass {nick uhost hand text} {
    set me [need_login $nick]
    if {$me eq ""} { return }
    set pass [lindex [words $text] 0]
    if {[bad_password $pass]} {
        msg_to $nick "Try: NEWPASS <new password>"
        return
    }
    pset $me pass [hashpass $pass]
    db_save
    msg_to $nick "Your password was changed."
}

proc ::irpg::cmd_align {nick uhost hand text} {
    set me [need_login $nick]
    if {$me eq ""} { return }
    set word [string tolower [lindex [words $text] 0]]
    if {$word ne "good" && $word ne "neutral" && $word ne "evil"} {
        msg_to $nick "Try: ALIGN <good|neutral|evil>"
        return
    }
    pset $me alignment [string index $word 0]
    chanmsg "$me has changed alignment to: $word."
    msg_to $nick "Your alignment was changed to $word."
}

proc ::irpg::cmd_removeme {nick uhost hand text} {
    set me [need_login $nick]
    if {$me eq ""} { return }
    msg_to $nick "Account $me removed."
    chanmsg "$nick removed his account, $me, the [pget $me class]."
    delete_account $me
    db_save
}

proc ::irpg::cmd_resetpass {nick uhost hand text} {
    set a [words $text]
    set char [lindex $a 0]
    set pass [lindex $a 1]
    if {[bad_password $pass]} {
        msg_to $nick "Try: RESETPASS <char name> <new password>"
        return
    }
    if {![acct_exists $char]} {
        msg_to $nick "No such account."
        return
    }
    ns_check $nick [list ::irpg::finish_resetpass $nick $char $pass]
}

proc ::irpg::finish_resetpass {nick char pass ok account} {
    if {!$ok} {
        msg_to $nick "You must be identified with NickServ to reset a password."
        return
    }
    if {![acct_exists $char]} {
        msg_to $nick "No such account."
        return
    }
    if {[string tolower [pget $char ns_account]] ne [string tolower $account]} {
        msg_to $nick "Your NickServ account does not match the one that registered $char."
        return
    }
    pset $char pass [hashpass $pass]
    logout_account $char
    set pen [penalize $char reset]
    db_save
    if {$pen > 0} {
        msg_to $nick "The password for $char was reset. A penalty of [duration $pen] was added to its timer."
    } else {
        msg_to $nick "The password for $char was reset."
    }
}

proc ::irpg::cmd_quest {nick uhost hand text} {
    variable quest
    if {![llength $quest(questers)]} {
        msg_to $nick "There is no active quest."
        return
    }
    if {$quest(type) == 1} {
        msg_to $nick "[questers_text] are on a quest to $quest(text). Quest to complete in [duration [expr {$quest(qtime) - [clock seconds]}]]."
    } else {
        set p1 $quest(p1)
        set p2 $quest(p2)
        msg_to $nick "[questers_text] are on a quest to $quest(text). Participants must first reach \[[lindex $p1 0],[lindex $p1 1]\], then \[[lindex $p2 0],[lindex $p2 1]\]."
    }
}

proc ::irpg::cmd_info {nick uhost hand text} {
    variable cfg
    variable version
    variable registrations
    set hand [norm_hand $hand]
    if {!$cfg(allowuserinfo) && ![admin_ok $nick $hand]} {
        msg_to $nick "You do not have access to INFO."
        return
    }
    set admins {}
    foreach n [online_accounts] {
        if {[account_is_admin $n]} { lappend admins [pget $n nick] }
    }
    if {[llength $admins]} { set adminlist [join $admins ", "] } else { set adminlist "none" }
    msg_to $nick "IdleRPG bot v$version (Tcl port of IRPG 3.1.2 by jotun). [llength [online_accounts]] IRPG users online of [array size ::irpg::rps] total. Admins online: $adminlist."
    if {[admin_ok $nick $hand]} {
        msg_to $nick "PAUSE_MODE is $cfg(pausemode), SILENT_MODE is $cfg(silentmode). Accounts created since startup: $registrations."
    }
}

proc ::irpg::cmd_hog {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand HOG]} { return }
    chanmsg "$nick has summoned the Hand of God."
    hog
}

proc ::irpg::cmd_push {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand PUSH]} { return }
    set a [words $text]
    set char [lindex $a 0]
    set secs [lindex $a 1]
    if {$secs eq "" || ![regexp {^-?\d+$} $secs]} {
        msg_to $nick "Try: PUSH <char name> <seconds>"
        return
    }
    if {![acct_exists $char]} {
        msg_to $nick "No such username $char."
        return
    }
    set next [pget $char next]
    if {$secs > $next} {
        msg_to $nick "Time to level for $char ($next s) is lower than $secs; setting TTL to 0."
        chanmsg "$nick has pushed $char $next seconds toward level [expr {[pget $char level] + 1}]."
        pset $char next 0
    } else {
        padd $char next [expr {-$secs}]
        chanmsg "$nick has pushed $char $secs seconds toward level [expr {[pget $char level] + 1}]. $char reaches next level in [duration [pget $char next]]."
    }
}

proc ::irpg::cmd_chpass {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand CHPASS]} { return }
    set a [words $text]
    set char [lindex $a 0]
    set pass [lindex $a 1]
    if {$pass eq "" || [bad_password $pass]} {
        msg_to $nick "Try: CHPASS <char name> <new password>" 1
        return
    }
    if {![acct_exists $char]} {
        msg_to $nick "No such username $char." 1
        return
    }
    pset $char pass [hashpass $pass]
    db_save
    msg_to $nick "Password for $char changed." 1
}

proc ::irpg::cmd_chuser {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand CHUSER]} { return }
    set a [words $text]
    set old [lindex $a 0]
    set new [lindex $a 1]
    if {$new eq ""} {
        msg_to $nick "Try: CHUSER <char name> <new char name>" 1
        return
    }
    if {![acct_exists $old]} {
        msg_to $nick "No such username $old." 1
        return
    }
    if {[acct_exists $new]} {
        msg_to $nick "Username $new is already taken." 1
        return
    }
    rename_account $old $new
    db_save
    msg_to $nick "Username for $old changed to $new." 1
}

proc ::irpg::cmd_chclass {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand CHCLASS]} { return }
    set a [words $text]
    set char [lindex $a 0]
    set class [join [lrange $a 1 end] " "]
    if {$class eq ""} {
        msg_to $nick "Try: CHCLASS <char name> <new char class>" 1
        return
    }
    if {![acct_exists $char]} {
        msg_to $nick "No such username $char." 1
        return
    }
    pset $char class $class
    db_save
    msg_to $nick "Class for $char changed to $class." 1
}

proc ::irpg::cmd_pause {nick uhost hand text} {
    variable cfg
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand PAUSE]} { return }
    set cfg(pausemode) [expr {!$cfg(pausemode)}]
    msg_to $nick "PAUSE_MODE set to $cfg(pausemode)." 1
}

proc ::irpg::cmd_silent {nick uhost hand text} {
    variable cfg
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand SILENT]} { return }
    set mode [lindex [words $text] 0]
    if {![regexp {^[0-3]$} $mode]} {
        msg_to $nick "Try: SILENT <mode>" 1
        return
    }
    set cfg(silentmode) $mode
    msg_to $nick "SILENT_MODE set to $cfg(silentmode)." 1
}

proc ::irpg::cmd_backup {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand BACKUP]} { return }
    set dest [backup]
    msg_to $nick "Database copied to $dest." 1
}

proc ::irpg::cmd_clearq {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_admin $nick $hand CLEARQ]} { return }
    clearqueue all
    chanmsg "Outgoing message queue cleared by $nick."
    msg_to $nick "Outgoing message queue cleared." 1
}

proc ::irpg::cmd_del {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_super $nick $hand DEL]} { return }
    set char [lindex [words $text] 0]
    if {$char eq ""} {
        msg_to $nick "Try: DEL <char name>" 1
        return
    }
    if {![acct_exists $char]} {
        msg_to $nick "No such account $char." 1
        return
    }
    delete_account $char
    db_save
    chanmsg "Account $char removed by $nick."
}

# Finds the Eggdrop handle for a character name or nick. An online nick with no
# handle gets one created from its current host.
proc ::irpg::resolve_handle {target} {
    variable cfg
    if {[acct_exists $target] && [pget $target online]} {
        set target [pget $target nick]
    }
    set h [hand_of $target]
    if {$h ne ""} { return $h }
    if {[validuser $target]} { return $target }
    if {[onchan $target $cfg(channel)]} {
        set uh [getchanhost $target $cfg(channel)]
        if {[catch {adduser $target [maskhost "$target!$uh"]} err]} {
            putlog "IRPG: could not add handle $target: $err"
            return ""
        }
        return $target
    }
    return ""
}

proc ::irpg::cmd_mkadmin {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_super $nick $hand MKADMIN]} { return }
    set target [lindex [words $text] 0]
    if {$target eq ""} {
        msg_to $nick "Try: MKADMIN <nick or char name>" 1
        return
    }
    set h [resolve_handle $target]
    if {$h eq ""} {
        msg_to $nick "No online nick or Eggdrop user named $target was found. Put them in the channel first." 1
        return
    }
    chattr $h +I
    save
    msg_to $nick "$h is now an IRPG admin. They must LOGIN to IRPG to use admin commands." 1
}

proc ::irpg::cmd_deladmin {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_super $nick $hand DELADMIN]} { return }
    set target [lindex [words $text] 0]
    if {$target eq ""} {
        msg_to $nick "Try: DELADMIN <nick or char name>" 1
        return
    }
    set h [resolve_handle $target]
    if {$h eq ""} {
        msg_to $nick "No online nick or Eggdrop user named $target was found." 1
        return
    }
    if {[is_owner $h]} {
        msg_to $nick "Cannot remove admin access from the owner." 1
        return
    }
    chattr $h -I
    save
    msg_to $nick "$h is no longer an IRPG admin." 1
}

proc ::irpg::cmd_penalty {nick uhost hand text} {
    set hand [norm_hand $hand]
    if {![gate_super $nick $hand PENALTY]} { return }
    set events {privmsg notice nick part kick quit logout quest}
    set a [words $text]
    if {![llength $a]} {
        foreach e $events {
            set state [expr {[pen_enabled $e] ? "ON" : "OFF"}]
            msg_to $nick "Penalty for $e: $state" 1
        }
        msg_to $nick "Logout penalty also applies to RESETPASS. Use: PENALTY <event> <ON|OFF>" 1
        return
    }
    set event [string tolower [lindex $a 0]]
    set state [string toupper [lindex $a 1]]
    if {[lsearch -exact $events $event] < 0 || ($state ne "ON" && $state ne "OFF")} {
        msg_to $nick "Try: PENALTY <privmsg|notice|nick|part|kick|quit|logout|quest> <ON|OFF>" 1
        return
    }
    setting_set pen.$event [expr {$state eq "ON" ? 1 : 0}]
    msg_to $nick "Penalty for $event is now $state." 1
}
