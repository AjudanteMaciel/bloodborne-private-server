# Bloodborne private server for Windows

A private server for the native [Supermedo/bloodborne_pc](https://github.com/Supermedo/bloodborne_pc) port, using shadNet and a local backend for the game's online services. This README and the PowerShell script messages are in English.

The server provides login, bell matchmaking, signaling, and online content. After matchmaking, gameplay traffic flows directly between players. Messages, bloodstains, phantoms, and glyphs are handled by the private backend, without relying on The Hunter's Dream when using the private profile.

This project does not include Bloodborne game files, port executables, saves, registered accounts, passwords, or databases from an existing installation.

## Validation status

Manually tested by two players on Windows over Tailscale on October 24, 2026:

- Co-op within the same Chalice Dungeon and layer.
- Co-op Quick Search at the Makeshift Altar, including a successful test with players on different layers.
- Co-op in the main world, including Corruption and Impurity oath runes.
- Players reported a successful Chalice PvP test using the Sinister Bell with different oath runes.
- Standard dungeon glyph lookup was fixed and confirmed in the game client.

Isolated network tests do not replace testing in the game. Every oath combination, every game region, and PvP triggered exclusively by Corruption versus Radiance have not received complete manual validation. One successful duel does not establish that every PvP filter reproduces the original servers' behavior.

## Components and ports

| Port | Protocol | Purpose |
| --- | --- | --- |
| 31313 | TCP | shadNet login and matchmaking |
| 31314 | UDP | Address discovery / STUN |
| 31315 | TCP | WebAPI and bell matchmaking |
| 31316 | TCP | Online configuration, messages, bloodstains, phantoms, and glyphs |
| 3658 | UDP | Gameplay traffic between players' PCs |

Connect all participating PCs to the same Tailscale network. In this configuration, shadNet login uses TCP without TLS; the documented setup is intended for a private network. Router port forwarding is not required. UPnP is disabled in the private profile.

## Requirements

- Windows, Git, and Python 3.
- MSYS2 with the **UCRT64** environment, CMake, Ninja, GCC, Qt 6 with Core/Network/Sql/Concurrent/HttpServer, and the corresponding development dependencies.
- Tailscale installed on participating PCs.
- The Supermedo port installed separately on each gaming PC.

Scripts use `C:\msys64\ucrt64` by default. The build and startup scripts accept `-MsysPrefix` for another location. Built executables depend on DLLs from that environment. This repository provides source code rather than a portable binary distribution.

## Prepare and build

From the project directory:

```powershell
.\scripts\Prepare-Sources.ps1
.\scripts\Build-Server.ps1
```

The first script downloads shadNet at the commit pinned in `sources.json`, initializes its submodules, and applies the patch. It does not change the commit of an existing checkout or discard local changes. The build includes the summon broker tests and the account registration client.

## Start and stop the server

After building, use the two batch files in the project directory:

- **`Start server.bat`** starts shadNet and the game backend. On first use, it asks for the server PC's Tailscale IPv4 address. Later starts reuse the address saved in `runtime/shadnet.cfg`.
- **`Stop server.bat`** stops both services for this project. It leaves the game, Tailscale, accounts, and databases unchanged. Connected players will lose access to the private server.

Connect Tailscale before starting. Starting again reuses existing server processes instead of launching duplicates. You can stop the server even when Tailscale is disconnected. The batch files use their own location, so you can move the project folder or create Windows shortcuts to them. Keep the scripts and project folders together.

The same controls are available in PowerShell:

```powershell
.\scripts\Start-Server.ps1
.\scripts\Stop-Server.ps1
```

To preview which processes would be stopped without stopping anything:

```powershell
.\scripts\Stop-Server.ps1 -WhatIf
```

The stop script checks the executable or backend script path and process creation time. It does not stop unrelated Python or shadNet installations based on their names or old PID files.

Find the server PC's Tailscale IPv4 address with `tailscale ip -4`. Replace `100.101.102.103` in the following examples with that address:

```powershell
.\scripts\Start-Server.ps1 -ServerAddress 100.101.102.103
```

The script stores local state in `runtime/`, generates a registration key on first startup, and reuses the same databases on subsequent starts. It does not create a new backup on each startup. The address must be assigned to a local interface on the server PC. The Python backend runs as a separate process from shadNet; both must remain running during gameplay. If you installed MSYS2 in a different location, start from PowerShell with `-MsysPrefix 'C:\path\to\ucrt64'` each time, or create a shortcut that supplies that parameter.

For troubleshooting, check `runtime/shadnet.stderr.log` and `runtime/backend.stderr.log`. `-TraceSummons` enables detailed bell requests. These logs may contain player names, IDs, and game session passwords, so never publish `runtime/`.

If needed, run the following once from an administrator PowerShell window:

```powershell
.\scripts\Open-Firewall.ps1 -ServerAddress 100.101.102.103
```

On each gaming PC, allow inbound UDP 3658 from the other participants on the Tailscale interface. This rule does not depend on the game's executable path.

## Private accounts

Each player needs a separate account on this shadNet server. The Hunter's Dream Discord login belongs to a different service.

The compiled upstream account client is located at `build/account/shadnet-sample.exe`. Its registration command is:

```text
shadnet-sample <host> 31313 register <npid> <password> <email> <registration-key>
```

The registration key is stored in the local `runtime/shadnet.cfg`. Supply your own values locally and share only each player's individual credentials with that player. No example account is enabled by default. Enter the private NPID and password in the launcher. To use the public service, link your own Discord account as usual.

## Switch between public and private profiles

Close the game and launcher before switching. The configured user/save directory is preserved, including custom paths inherited from shadPS4.

For the simplest setup, double-click one of these files on each gaming PC:

- **`Online private.bat`** asks for the port folder, private server Tailscale IPv4, and your registered private NPID/password on first use. Later clicks restore those credentials, select the private services, and open the launcher.
- **`Online The Hunters Dream.bat`** selects the public service and opens the launcher. Your saved Discord login is preserved; sign in through Discord in the launcher if the session has expired. It only asks for the port folder if it has not been saved yet.

These shortcuts do not start the server or Tailscale. The server owner must start both separately. Accounts must already exist on the private server; the shortcut does not register them.

Your choices are saved to `client.local.json`, which Git ignores. Its private password is encrypted using Windows DPAPI for the current Windows user and PC. Do not share this file; each player should complete setup on their own PC. The launcher still stores its password using its normal settings format. No backup files accumulate. To change the saved folder, server, or private account, run:

```powershell
.\scripts\Open-Online.ps1 -Mode Private -Configure
```

For command-line use without the saved shortcut settings:

```powershell
.\scripts\Set-OnlineProfile.ps1 -Mode Private -InstallDir 'C:\Games\bbport-windows' -ServerAddress 100.101.102.103 -OpenLauncher
.\scripts\Set-OnlineProfile.ps1 -Mode Public -InstallDir 'C:\Games\bbport-windows' -OpenLauncher
```

The private profile selects **shadNet**, configures the three server endpoints, and redirects game services and playlogs. The public profile selects **The Hunter's Dream**, deactivates the custom override file, and regenerates the public addresses. Saves, trophies, the Discord account, private NPID, and private password are preserved. The disabled custom file uses a fixed filename, so copies do not accumulate. Manually entered routing variables are removed from the launcher's advanced environment field so the selected profile can determine the endpoints.

## Bells and oath runes

For co-op, one player rings the Beckoning Bell and the other rings the Small Resonant Bell, in the same matchmaking zone and with the same password. For direct bell matching in Chalice Dungeons, use the same dungeon and layer. Alternatively, the helper can select **Co-op Quick Search** at the **Makeshift Altar** while the host rings the Beckoning Bell inside the dungeon. This altar method was confirmed to work with players on different layers.

Corruption + Impurity was validated for co-op. The Corruption client advertises category 5 while the host searches for category 0. The patch allows that match and converts internal role 21 to role 7 in the response sent to an exact neutral co-op search. The startup script enables this behavior with `SHADNET_BLOODBORNE_NEUTRAL_OATH_COOP=1`. The stored advertisement is unchanged; explicit adversary searches, unknown versions, and other roles are excluded from this conversion.

For ordinary invasions, use the Sinister Resonant Bell. A Bell-ringing Woman must be active in the eligible host world, and the co-op password does not select an invasion opponent. Radiance and Corruption are opposing oaths in the original game; testing Sinister invasions with those runes does not independently validate oath-based duels.

## Tests

```powershell
python -m unittest discover -s backend/tests -v
.\tests\Test-OnlineProfile.ps1
.\tests\Test-OnlineShortcuts.ps1
.\tests\Test-ServerControl.ps1
.\tests\Test-PrepareSources.ps1
ctest --test-dir build --output-on-failure
python tests/test_udp_framing.py runtime/shadnet.exe modern
```

The profile test uses a temporary directory and fictional credentials. The server control test uses simulated processes to check startup, repeated starts/stops, stale PID handling, dry runs, and database preservation without stopping a real server. The UDP test runs an isolated server on loopback. The C++ tests included in the patch cover advertisements, zone/channel/password/level filtering, data preservation, and the restricted role conversion.

## Launcher settings for both players

Both players must use the **same private server address**, including the player whose PC runs the server. The example below assumes the server PC's Tailscale IPv4 is `100.101.102.103`. Replace it everywhere with your actual server address. Do not use the second player's IP, `localhost`, or `127.0.0.1` for this shared setup.

### Create two accounts first

The server owner must register **two separate accounts on this private shadNet server**, using the account client described under [Private accounts](#private-accounts). For example:

| Account information | Player 1 | Player 2 |
| --- | --- | --- |
| Private NPID | `PlayerOne` | `PlayerTwo` |
| Private account password | Player 1's chosen password | Player 2's chosen password |
| Registration email | Player 1's registration email | Player 2's registration email |

These names are examples, not preconfigured accounts. Use the exact NPID spelling and capitalization registered on your server. Each player signs in with their own account; do not put the same NPID on both PCs. An account registered on a public shadNet server does not automatically exist on your private server.

### Fill in the launcher's Online page

Use the following settings on **both PCs**. The two private account credentials are the only player-specific entries in this table:

| Launcher field | Player 1 | Player 2 |
| --- | --- | --- |
| Online play | Enabled | Enabled |
| Play with / online service | **shadNet server** | **shadNet server** |
| Online ID (NPID) | `PlayerOne`, or the account registered for Player 1 | `PlayerTwo`, or the account registered for Player 2 |
| Password | The private password registered for Player 1 | The private password registered for Player 2 |
| Use my own servers | **Enabled** | **Enabled** |
| Game server (messages, bloodstains, phantoms) | `http://100.101.102.103:31316` | `http://100.101.102.103:31316` |
| Co-op server address (bells and summons) | `100.101.102.103:31313` | `100.101.102.103:31313` |
| WebAPI address | `http://100.101.102.103:31315` | `http://100.101.102.103:31315` |
| UPnP | **Disabled** when using Tailscale | **Disabled** when using Tailscale |

Keep the `http://` prefix on the game server and WebAPI addresses. The co-op server address uses only `IP:port`. Enter the WebAPI address explicitly for this setup.

The launcher account password is **not** the multiplayer password set inside Bloodborne. There are three separate values:

- **Private account password:** each player's shadNet login credential; entered in the launcher.
- **In-game matching password:** an optional shared code, such as `hunt123`, entered in Bloodborne's Network settings on both PCs to find each other for co-op. It does not direct ordinary Sinister invasions.
- **Registration key:** the server owner's key from `runtime/shadnet.cfg`, used only when creating accounts with the account client. Do not enter it as a player's launcher password.

The NPID field takes the private account name, not an email address or a Discord username. Discord sign-in for The Hunter's Dream is not required for this private profile. Do not enter PlayStation Network or Discord account passwords here.

### Apply the profile and connect

1. The server owner starts Tailscale and **Start server.bat**. The second player connects Tailscale on their own PC, with access to the same private network.
2. Each player enters their own private NPID and password on the launcher's Online page, saves the settings, and closes the game and launcher.
3. Each player runs the following command from their copy of this project. Change `-InstallDir` to that PC's port installation, but use the **same server IP** on both PCs:

   ```powershell
   .\scripts\Set-OnlineProfile.ps1 -Mode Private -InstallDir 'C:\Games\bbport-windows' -ServerAddress 100.101.102.103 -OpenLauncher
   ```

4. The profile script configures the server fields and active routing files. It preserves the NPID and password entered in step 2; it does **not** register accounts or supply credentials for you.
5. Start the game and select **Play Online**. Use game version **1.09** on both PCs. For co-op, set the same in-game matching password, stand in the same matchmaking zone, and ring the appropriate bells. For direct bell matching in Chalice Dungeons, also use the same dungeon and layer. For the tested Makeshift Altar method, the host rings the Beckoning Bell inside the dungeon and the helper selects **Co-op Quick Search** at the altar; this worked with players on different layers.

If login fails, first check that the selected service is shadNet, the NPID and password belong to this private server, Tailscale is connected, and both server processes are running. If login succeeds but messages or bells still use another server, close both the game and launcher and reapply the private profile to refresh the override files.

## Credits and licensing

- [Wozzardman/shadnet-p2p](https://github.com/Wozzardman/shadnet-p2p): original server, account client, and tests.
- [lKaniel/bloodborne-server](https://github.com/lKaniel/bloodborne-server): Python backend and service template.
- [Supermedo/bloodborne_pc](https://github.com/Supermedo/bloodborne_pc): the port used for testing.

See `sources.json`, `LICENSE`, `LICENSES/`, and the [documented changes](docs/CHANGES.md), which are currently in Portuguese. Preserve the original projects' copyright notices and licenses when redistributing their code. The Protobuf submodule retains its own upstream license.
