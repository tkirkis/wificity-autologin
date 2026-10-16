# WifiCity AutoLogin

A small macOS menu bar app that signs you in to the **Cité Internationale Universitaire de Paris** Wi‑Fi portal automatically, so you never have to type the username and password again after your Mac wakes up.

- **Open the app** → it signs you in right away, then keeps you signed in. It checks every 15 seconds, whenever the network changes and when your Mac wakes.
- **Quit the app** → auto-login is off. Nothing runs in the background and nothing starts at login.
- Your password is stored in the **macOS Keychain**, never in a file.
- It only ever sends your password to the school's portal. Does nothing on any other network.

## Install

Open Terminal (Applications → Utilities → Terminal), paste this line and press Enter:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tkirkis/wificity-autologin/main/install.sh)"
```

The installer asks for your portal **username** and **password**, the same ones you type on the "Authentication Required" page. The password is hidden as you type and asked twice. Then it installs **WifiCity AutoLogin** in `~/Applications` and opens it.

Requires macOS 13 or later, on Apple Silicon or Intel. No developer tools are needed.

From then on, open **WifiCity AutoLogin** from Spotlight whenever you want auto-login on.

## Using it

| Menu item | What it does |
|---|---|
| Status | Online, signing in, or no network, with the time of the last check |
| Last auto-login | When the app last signed you in |
| Connect now | Checks immediately and signs in if needed |
| Log out & Quit… | Signs you out of the portal and turns auto-login off |
| Open log | Shows the activity log in Console |
| Quit | Turns auto-login off |

Menu bar icon: filled circle = online, **!** = signing in, crossed‑out Wi‑Fi = no network.

## Troubleshooting

- **Am I signed in?** Open [http://neverssl.com](http://neverssl.com). If the Cité login page appears, you're signed out.
- **What is it doing?** Choose *Open log* from the menu.
- **Changed password?** Run the installer again with `--reset-creds`:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tkirkis/wificity-autologin/main/install.sh)" -- --reset-creds
  ```
- **Reporting a problem:** this saves a diagnostic report to your Desktop. It doesn't contain your password.
  ```bash
  ~/Library/Application\ Support/WifiCityAutoLogin/wificity report
  ```

## Uninstall

```bash
~/Library/Application\ Support/WifiCityAutoLogin/wificity uninstall
```

This removes the app, its files, its log and the saved credentials.

## How it works

The Cité network uses a FortiGate captive portal. Each check:

1. Requests Apple's connectivity page (`captive.apple.com`). If it loads, you're online and nothing else happens.
2. If the portal (`10.254.0.254`) intercepts the request instead, the app loads the login page, fills in the form with your username and password from the Keychain, and submits it, just as your browser would.
3. Confirms you're online and closes the macOS login window.

Until you sign in, macOS gives a captive network no default route or DNS, so every request is sent directly through the Wi‑Fi interface. If name lookup isn't available, the app asks the network's DNS server directly, or falls back to `http://1.1.1.1`.

| File | Purpose |
|---|---|
| `MenuBarApp.swift` | Menu bar app (Swift) |
| `bin/WifiCityAutoLogin` | The menu bar app, prebuilt for Apple Silicon and Intel |
| `wificity` | Portal detection and sign-in script |
| `install.sh` | Installer |

To compile the app yourself instead of using the prebuilt one, install Xcode Command Line Tools (`xcode-select --install`), clone the repository and run `./install.sh --build-from-source`.

Not affiliated with the Cité Internationale Universitaire de Paris.
