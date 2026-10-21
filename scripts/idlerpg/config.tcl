# IdleRPG settings and runtime state. Edit values here, then restart the bot.

namespace eval ::irpg {
    variable cfg
    # Automated announcements (seconds, 0 = disabled)
    array set cfg {
        rpbase          600
        rpstep          1.16
        rppenstep       1.14
        self_clock      3
        mapx            500
        mapy            500
        limitpen        604800
        splitwait       900
        detectsplits    1
        noscale         0
        voiceonlogin    1
        noccodes        1
        nononp          1
        casematters     1
        statuscmd       1
        allowuserinfo   1
        writequestfile  1
        announce_top_players 5400
        announce_register    1800
        announce_penalties   3600
        questfile       questinfo.txt
        modsfile        modifiers.txt
        eventsfile      events.txt
        dbfile          irpg.sqlite
        backupdir       .dbbackup
        pbkdf2_rounds   10000
        silentmode      0
        pausemode       0
    }

    variable version "3.1.2-tcl"
    variable rps
    array set rps {}
    variable quest
    array set quest {questers {} p1 {0 0} p2 {0 0} text "" type 1 stage 1 qtime 0}
    variable whois
    array set whois {}
    variable joined
    array set joined {}
    variable netsplits
    array set netsplits {}
    variable pending
    array set pending {}
    variable pending_deadline 0
    variable pending_total 0
    variable restored 0
    variable posuser
    array set posuser {}
    variable posbattled
    array set posbattled {}
    variable lasttime 0
    variable rpreport 0
    variable lastreg 0
    variable registrations 0
    variable timerid ""
    variable last_top_announce 0
    variable last_register_announce 0
    variable last_penalty_announce 0
}
