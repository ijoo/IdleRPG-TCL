# IdleRPG for Eggdrop (with Tcl)

A complete port of the IRPG bot v3.1.2 (by jotun) from Perl to Tcl for use with
Eggdrop 1.10.2. The bot runs as an Eggdrop script and requires Covid.5.0.tcl to
be loaded first.

## Prerequisites

- Eggdrop 1.10.2 (built and working)
- Tcl 8.6
- The **pbkdf2** Eggdrop module must be loaded (`loadmodule pbkdf2`)
- Tcl SQLite3 binding (`package require sqlite3`)
- **Covid.5.0.tcl** must be sourced in `eggdrop.conf` **before** IdleRPG

## Installation

### 1. Edit `eggdrop.conf`

Add the following to your Eggdrop configuration file (`eggdrop.conf`), making
sure Covid loads **first**:

```tcl
############ LOAD MODULE ##############
loadmodule pbkdf2    ; # Password hashing (used by IRPG)
loadmodule blowfish  ; # Userfile encryption
loadmodule channels  ; # Channel support
loadmodule server    ; # Core server support
loadmodule ctcp      ; # CTCP functionality
loadmodule irc       ; # Basic IRC functionality
loadmodule notes     ; # Note storing for users
loadmodule console   ; # Console setting storage

############ BASIC SETTINGS ############
set owner "YourNick"
set basechan "#yourchannel"
set nick "IRPGBot"
...
############ SCRIPTS #####
source scripts/Covid.5.0.tcl
source scripts/idlerpg/idlerpg.tcl
```

### 2. Configure IdleRPG settings

Edit `scripts/idlerpg/config.tcl` to adjust game parameters:

```tcl
array set cfg {
    rpbase          600       ; # Base time to level up (seconds)
    rpstep          1.16      ; # Time multiplier per level
    rppenstep       1.14      ; # Penalty multiplier per level
    self_clock      3         ; # Game tick interval (seconds)
    mapx            500       ; # Map width
    mapy            500       ; # Map height
    limitpen        604800    ; # Max penalty per event (0 = unlimited)
    ...
    # Automated announcements (seconds, 0 = disabled)
    announce_top_players 1800
    announce_register    3600
    announce_penalties   3600
}
```

### 3. Start the bot

```bash
cd /home/user/IdleTCL
./eggdrop -m  # -m for foreground mode (use -nm for no-motd)
```

The bot will create `irpg.sqlite` in the Eggdrop directory on first run.

## Player Commands

Send these to the bot in a **private message**:

| Command | Description |
|---|---|
| `REGISTER <char> <password> <class>` | Create a new character account |
| `LOGIN <char> <password>` | Log in to your character |
| `LOGOUT` | Log out of your character |
| `STATUS [char]` | View your or another player's status |
| `WHOAMI` | Show your own character info |
| `NEWPASS <password>` | Change your password |
| `ALIGN <good\|neutral\|evil>` | Set your alignment |
| `REMOVEME` | Delete your account |
| `RESETPASS <char> <newpassword>` | Reset password (requires NickServ ID match) |
| `QUEST` | Show active quest information |
| `INFO` | Show bot and server info |
| `IDLEHELP` | Show this help message |

**Registration and login require NickServ identification.** You must be
identified with NickServ before you can register, log in, or reset a password.

## Admin Commands

Admins (Eggdrop flag `I`, set via `MKADMIN`) must **log in to IRPG** before
using admin commands. The owner does not need to log in.

| Command | Description |
|---|---|
| `HOG` | Summon the Hand of God on a random player |
| `PUSH <char> <seconds>` | Reduce a player's time-to-level |
| `CHPASS <char> <password>` | Change a player's password |
| `CHUSER <char> <newname>` | Rename a character |
| `CHCLASS <char> <class>` | Change a character's class |
| `PAUSE` | Toggle pause mode (stops DB writes) |
| `SILENT <0-3>` | Set silent mode (0=all, 1=no chan, 2=no priv, 3=none) |
| `BACKUP` | Force a database backup |
| `CLEARQ` | Clear the outgoing message queue |

## Superadmin / Owner Commands

Superadmins are users with Covid's `Z` flag (the owner after Covid `auth`).

| Command | Description |
|---|---|
| `DEL <char>` | Delete a character account |
| `MKADMIN <nick\|char>` | Grant admin flag to an online user |
| `DELADMIN <nick\|char>` | Revoke admin flag |
| `PENALTY [<event> <ON\|OFF>]` | Toggle penalties per event (or list all) |

Penalty events: `privmsg`, `notice`, `nick`, `part`, `kick`, `quit`, `logout`, `quest`

## Access Levels

| Level | Requirement | Notes |
|---|---|---|
| **Player** | Registered + logged in | Can play the game |
| **Admin** | Eggdrop flag `I` + IRPG login | Granted by `MKADMIN` |
| **Superadmin/Owner** | `$owner` from `eggdrop.conf` | No IRPG login needed |
| **Superadmin (Z)** | Covid `Z` flag | Can use `MKADMIN`, `DELADMIN`, `PENALTY` |

## Important Notes

- **Login/logout behavior:** Parting, kicking, nick changes, and quitting
  automatically log you out of IRPG. You must log in again to resume idling.
- **RESETPASS:** Requires NickServ identification, and your NickServ account
  must match the one that registered the character. Applies a logout-level
  penalty.
- **PENALTY:** Only superadmins can toggle penalties. `RESETPASS` uses the
  `logout` penalty setting.
- **No exceptions:** Owners, admins, and friends are all subject to penalties
  and logout rules.

## Penalties

| Event | Base Penalty | Toggleable |
|---|---|---|
| Channel message | 1s × length | Yes (`privmsg`) |
| Notice | 1s × length | Yes (`notice`) |
| Nick change | 30s | Yes (`nick`) |
| Part | 200s | Yes (`part`) |
| Kick | 250s | Yes (`kick`) |
| Quit | 20s | Yes (`quit`) |
| LOGOUT command | 20s | Yes (`logout`) |
| RESETPASS | 20s | Yes (uses `logout` setting) |

Penalty formula: `int(base × rppenstep^level)`

## Database

IdleRPG stores all data in a SQLite database (`irpg.sqlite`) in the Eggdrop
directory. The database is saved automatically every 60 seconds (when not in
pause mode) and after every account change.

To disable SQLite and use flat files instead, edit `scripts/idlerpg/db.tcl`.

## Automated Announcements

Three announcements run on timers (set in `config.tcl`):

1. **Top 5 Players** — Highest-level characters (default: every 30 minutes)
2. **Registration Reminder** — Tells new players how to join (default: every 60 minutes)
3. **Penalty Status** — Lists disabled penalty events (default: every 60 minutes)

Set any interval to `0` to disable that announcement.

## PHP Website (Optional)

The PHP website in `IdleRPG/site/` reads player data from the SQLite database
written by the Tcl bot.

### Requirements

- PHP with SQLite3 support (`php-sqlite3`)
- A web server (Apache, Nginx, etc.)

### Setup

1. **Install PHP:**
   ```bash
   apt-get install php-cli php-sqlite3
   ```

2. **Configure the database path** in `IdleRPG/site/conf-global.php`:
   ```php
   define('IDLE_SQLITE_PATH', '/home/user/IdleTCL/IdleTCL/irpg.sqlite');
   ```

3. **Ensure the web server can read** `irpg.sqlite`:
   ```bash
   chmod 644 /home/user/IdleTCL/IdleTCL/irpg.sqlite
   ```

4. **Point your web server** at `IdleRPG/site/` as the document root.

### What the PHP site provides

- Player list and individual player profiles
- World map with online player positions
- Quest status page
- Player position map images

The quest pages (`quest.template.loader.php`, `make.quest.map.php`) continue to
read `questinfo.txt`, which the Tcl bot still writes.

## Files Included

```
IdleTCL/                    # Eggdrop 1.10.2 installation
├── eggdrop.conf            # Bot configuration (source Covid + IdleRPG)
├── scripts/
│   ├── Covid.5.0.tcl       # Required: loads first
│   └── idlerpg/            # IdleRPG Tcl scripts
│       ├── idlerpg.tcl     # Main loader
│       ├── config.tcl      # Game settings
│       ├── util.tcl        # Helper functions
│       ├── db.tcl          # SQLite storage
│       ├── auth.tcl        # Passwords & access checks
│       ├── penalty.tcl     # Penalty system
│       ├── game.tcl        # Game clock & events
│       ├── events.tcl      # HOG, combat, quests, items
│       ├── commands.tcl    # Player/admin commands
│       └── channel.tcl     # Channel event handlers
├── irpg.sqlite             # IdleRPG database (created on first run)
├── questinfo.txt           # Quest data (for PHP website)
└── ...                     # Other Eggdrop files

```

## License

This Tcl port is for personal use only. The original IRPG bot code by jotun
has distribution restrictions — see `bot.v3.1.2.pl` header for details.
