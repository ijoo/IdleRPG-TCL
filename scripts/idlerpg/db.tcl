# Storage. Accounts are held in memory (::irpg::rps) and written to SQLite every
# 60 seconds, after account changes, and on backup.

namespace eval ::irpg {
    variable columns {name pass class level next nick userhost online idled x y
        pen_mesg pen_nick pen_part pen_kick pen_quit pen_quest pen_logout pen_reset
        created lastlogin alignment ns_account
        item_ring item_amulet item_charm item_weapon item_helm item_tunic
        item_gloves item_leggings item_shield item_boots}
    variable itemmap {ring item_ring amulet item_amulet charm item_charm weapon item_weapon
        helm item_helm tunic item_tunic {pair of gloves} item_gloves
        {set of leggings} item_leggings shield item_shield {pair of boots} item_boots}
}

proc ::irpg::db_open {} {
    variable cfg
    catch {::irpg::db close}
    sqlite3 ::irpg::db [file join $cfg(botdir) $cfg(dbfile)]
    ::irpg::db eval {
        CREATE TABLE IF NOT EXISTS players (
            name TEXT PRIMARY KEY, pass TEXT, class TEXT, level INTEGER, next INTEGER,
            nick TEXT, userhost TEXT, online INTEGER, idled INTEGER, x INTEGER, y INTEGER,
            pen_mesg INTEGER, pen_nick INTEGER, pen_part INTEGER, pen_kick INTEGER,
            pen_quit INTEGER, pen_quest INTEGER, pen_logout INTEGER, pen_reset INTEGER,
            created INTEGER, lastlogin INTEGER, alignment TEXT, ns_account TEXT,
            item_ring TEXT, item_amulet TEXT, item_charm TEXT, item_weapon TEXT,
            item_helm TEXT, item_tunic TEXT, item_gloves TEXT, item_leggings TEXT,
            item_shield TEXT, item_boots TEXT)
    }
    ::irpg::db eval {CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)}
}

proc ::irpg::db_load {} {
    variable rps
    array unset rps
    ::irpg::db eval {SELECT * FROM players} row {
        set rec {}
        foreach c $row(*) { dict set rec $c $row($c) }
        set rps($row(name)) $rec
    }
}

proc ::irpg::db_save {} {
    variable rps
    variable columns
    set sql "INSERT INTO players ([join $columns ,]) VALUES ([join [lmap c $columns {string cat : $c}] ,])"
    ::irpg::db transaction {
        ::irpg::db eval {DELETE FROM players}
        foreach n [array names rps] {
            set r $rps($n)
            foreach c $columns { set $c [dict get $r $c] }
            ::irpg::db eval $sql
        }
    }
}

# Copies the database to the backup directory. Returns the destination path.
proc ::irpg::backup {} {
    variable cfg
    db_save
    set dir [file join $cfg(botdir) $cfg(backupdir)]
    file mkdir $dir
    set dest [file join $dir "$cfg(dbfile)[clock seconds]"]
    ::irpg::db eval {VACUUM INTO :dest}
    return $dest
}

proc ::irpg::setting_get {key default} {
    set rows [::irpg::db eval {SELECT value FROM settings WHERE key = :key}]
    if {[llength $rows]} { return [lindex $rows 0] }
    return $default
}

proc ::irpg::setting_set {key value} {
    ::irpg::db eval {INSERT OR REPLACE INTO settings (key, value) VALUES (:key, :value)}
}

proc ::irpg::acct_exists {name} {
    variable rps
    return [info exists rps($name)]
}

proc ::irpg::pget {name field} {
    variable rps
    return [dict get $rps($name) $field]
}

proc ::irpg::pset {name field value} {
    variable rps
    dict set rps($name) $field $value
}

proc ::irpg::padd {name field amount} {
    pset $name $field [expr {[pget $name $field] + $amount}]
}

proc ::irpg::item_columns {} {
    variable itemmap
    return [dict values $itemmap]
}

proc ::irpg::online_accounts {} {
    variable rps
    set out {}
    foreach n [array names rps] {
        if {[dict get $rps($n) online]} { lappend out $n }
    }
    return $out
}

proc ::irpg::new_account {name pass class nick userhost account} {
    variable rps
    variable cfg
    set rec [dict create name $name pass $pass class $class level 0 next $cfg(rpbase) \
        nick $nick userhost $userhost online 1 idled 0 \
        x [irand $cfg(mapx)] y [irand $cfg(mapy)] \
        pen_mesg 0 pen_nick 0 pen_part 0 pen_kick 0 pen_quit 0 pen_quest 0 \
        pen_logout 0 pen_reset 0 created [clock seconds] lastlogin [clock seconds] \
        alignment n ns_account $account]
    foreach col [item_columns] { dict set rec $col 0 }
    set rps($name) $rec
}

proc ::irpg::delete_account {name} {
    variable rps
    unset rps($name)
}

proc ::irpg::rename_account {old new} {
    variable rps
    set rec $rps($old)
    dict set rec name $new
    set rps($new) $rec
    unset rps($old)
}
