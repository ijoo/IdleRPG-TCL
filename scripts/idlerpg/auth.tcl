# Passwords (Eggdrop pbkdf2 module), NickServ identification (WHOIS) and access checks.

proc ::irpg::random_hex {n} {
    set f [open /dev/urandom rb]
    set bytes [read $f $n]
    close $f
    binary scan $bytes H* hex
    return $hex
}

# Stored form: pbkdf2-sha256$<rounds>$<salt>$<key>
proc ::irpg::hashpass {pass} {
    variable cfg
    set salt [random_hex 16]
    set key [pbkdf2 $pass $salt $cfg(pbkdf2_rounds) SHA256]
    return [join [list pbkdf2-sha256 $cfg(pbkdf2_rounds) $salt $key] \$]
}

proc ::irpg::checkpass {stored pass} {
    set parts [split $stored \$]
    if {[llength $parts] != 4 || [lindex $parts 0] ne "pbkdf2-sha256"} { return 0 }
    lassign $parts algo rounds salt key
    return [expr {[pbkdf2 $pass $salt $rounds SHA256] eq $key}]
}

# Asks NickServ (via WHOIS) whether nick is identified. Calls cb with {ok account}
# appended. account is the NickServ account name in lower case, or "".
proc ::irpg::ns_check {nick cb} {
    variable whois
    set key [string tolower $nick]
    if {[info exists whois($key)]} {
        dict lappend whois($key) cbs $cb
        return
    }
    set whois($key) [dict create cbs [list $cb] ok 0 account ""]
    putquick "WHOIS $nick"
    utimer 10 [list ::irpg::ns_finish $key]
}

proc ::irpg::ns_finish {key} {
    variable whois
    if {![info exists whois($key)]} { return }
    set d $whois($key)
    unset whois($key)
    foreach cb [dict get $d cbs] {
        if {[catch [concat $cb [list [dict get $d ok] [dict get $d account]]] err]} {
            putlog "IRPG: NickServ callback error: $err"
        }
    }
}

# 330 "is logged in as": text is "<botnick> <nick> <account> :...".
proc ::irpg::raw_330 {from keyword text} {
    variable whois
    set key [string tolower [lindex $text 1]]
    if {[info exists whois($key)]} {
        dict set whois($key) ok 1
        dict set whois($key) account [string tolower [lindex $text 2]]
    }
}

# 307 "is identified for this nick" (DalNet style): the nick is its own account.
proc ::irpg::raw_307 {from keyword text} {
    variable whois
    set key [string tolower [lindex $text 1]]
    if {[info exists whois($key)]} {
        dict set whois($key) ok 1
        dict set whois($key) account $key
    }
}

proc ::irpg::raw_318 {from keyword text} {
    ns_finish [string tolower [lindex $text 1]]
}

# Returns the IRPG account currently online under nick, or "".
proc ::irpg::finduser {nick} {
    variable rps
    foreach n [array names rps] {
        set r $rps($n)
        if {[dict get $r online] && [string equal -nocase [dict get $r nick] $nick]} {
            return $n
        }
    }
    return ""
}

proc ::irpg::norm_hand {hand} {
    if {$hand eq "*"} { return "" }
    return $hand
}

# Eggdrop handle of a channel nick, or "".
proc ::irpg::hand_of {nick} {
    set h [nick2hand $nick]
    if {$h eq "*"} { return "" }
    return $h
}

# Owner: the handle named by owner in eggdrop.conf (shared with Covid).
proc ::irpg::is_owner {hand} {
    variable cfg
    return [expr {$hand ne "" && $hand eq $cfg(owner)}]
}

# Superadmin: the Covid-authenticated owner flag Z.
proc ::irpg::is_super {hand} {
    return [expr {$hand ne "" && [validuser $hand] && [matchattr $hand Z]}]
}

# Admin flag: custom global flag I, set with MKADMIN.
proc ::irpg::is_admin_hand {hand} {
    return [expr {$hand ne "" && [validuser $hand] && [matchattr $hand I]}]
}

# Admin commands: the owner, or an admin who is logged in to IRPG.
proc ::irpg::admin_ok {nick hand} {
    if {[is_owner $hand]} { return 1 }
    return [expr {[is_admin_hand $hand] && [finduser $nick] ne ""}]
}

proc ::irpg::gate_admin {nick hand cmd} {
    if {[admin_ok $nick $hand]} { return 1 }
    if {[is_admin_hand $hand]} {
        msg_to $nick "Admins must log in to IRPG before using $cmd. Use: LOGIN <char> <password>"
    } else {
        msg_to $nick "You do not have access to $cmd."
    }
    return 0
}

proc ::irpg::gate_super {nick hand cmd} {
    variable cfg
    if {[is_super $hand]} { return 1 }
    msg_to $nick "$cmd requires superadmin access. Authenticate with Covid first: /msg $cfg(botnick) auth <password>"
    return 0
}

proc ::irpg::account_is_admin {name} {
    if {![acct_exists $name] || ![pget $name online]} { return 0 }
    set h [hand_of [pget $name nick]]
    return [expr {[is_owner $h] || [is_admin_hand $h]}]
}
