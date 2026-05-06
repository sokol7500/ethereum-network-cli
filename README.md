git clone https://github.com/sokol7500/ethereum-network-cli.git && cd ethereum-network-cli && chmod +x install.sh && ./install.sh

The program for working with the Ethereum cryptocurrency was created
with the goal that many Ethereum holders could use it safely and without
loss, since the key is stored only locally, and you can copy the key to
various USB flash drives or disks.

The key can also be stored in various cloud services under any name,
so that no one could guess that it is a key, but only in encrypted form,
since this program has a key encryption function, and it can be safely
decrypted. On USB flash drives, it is better to store the key without
encryption, but in a secure place and on multiple USB flash drives.

The program is safe for working with cryptocurrency, as it works purely
locally via an RPC server, and it can be launched either with a root
password or without a password.

Rules for Using the Program
1. After creating a key, always check the key's correctness using the
"🔍 Check Key Correctness" function. The key is verified through a test
transaction without sending any amount, including password verification,
so that you can be sure that the key was created correctly with the
right password.

2. After verifying the key's correctness, you can safely store and use
the key, and also keep it in a secure place.

3. If you already have a ready-made key, you can copy it to the user
folder /root/.ethereum/keystore for use.

4. To make a transaction, you can use the built-in RPC servers or your
own via the "🌐 Add RPC Server" function.

5. A key can only be created with a password of 12 characters or more
(from 12 characters).

6. ETH can be sent with any amount using the built-in fees, or you can
enter your own fee to complete the transaction.

Security
The security of Ethereum storage is the sole responsibility of the
Ethereum holder, but in the future, the Author of the program (sokol7500)
will improve it in terms of security and functionality, and it is planned
to make the program much safer than Trust Wallet, Metamask, and other
programs and applications.

The program is adapted only for Gentoo, Arch Linux, and Ubuntu
distributions, but it can also work on any other distributions — for
this, only the necessary components are needed. The package includes
the install.sh file, which automatically installs all components on
Gentoo, Arch Linux, and Ubuntu.

Required Components
1.  geth — Ethereum client (compiled from source)
2.  clef — Ethereum account manager (compiled from source)
3.  curl — HTTP requests to RPC, Etherscan
4.  wget — downloading (on Arch)
5.  git — cloning repositories
6.  bc — mathematical calculations (balance, fees)
7.  jq — JSON parsing (key structure verification)
8.  python3 — JSON parsing (address extraction, structure verification)
9.  openssl — key encryption/decryption (AES-256-CBC)
10. netstat / fuser — port checking and releasing
11. stat — file information retrieval
12. eth_checksum (eth-checksum) — Ethereum address normalization
13. dbus / gdbus — for highlighting files in the file manager
14. xdg-open — opening folders
15. fc-cache — updating font cache
16. gtk-update-icon-cache — updating GTK cache
17. update-desktop-database — updating .desktop file database
18. Noto fonts (noto-fonts, noto-fonts-cjk, noto-fonts-emoji, noto-fonts-extra)
19. bash (≥4.0) — interpreter
20. coreutils (stat, mkdir, chmod, chown, kill, tee, readlink, mktemp)
21. sudo — privilege escalation
22. sed — text replacement
23. grep — search
24. find — file search
25. sort / uniq — sorting
26. tr — text transformation
27. head / tail — reading files
28. wc — line counting
29. date — working with date/time
30. sleep — delays
31. stty — terminal configuration
32. pgrep / pkill / killall — process management
33. mkfifo — creating named pipes (FIFO)

- 💻 The program can also be run on Windows via the Ubuntu emulator
  (WSL), but it has not been tested.

Privacy
The program is written in the Bash programming language and works only
in binary format. It does not collect any user data. All transactions
are performed only from the user's computer through the main Go-Ethereum
program, which is developed by the Ethereum developers, and via an RPC
server, then into the Ethereum network.

## 🛠️ Future Development Plans

The program will be constantly improved, and new features will be added
with a focus on the security of your keys, which are stored on your
local computer.

The following features will also be developed:

- 🔒 Automatic Key Encryption
- 📜 Transaction History
- 🔔 Notifications of Sending or Receiving Ethereum
- 📱 QR Code Key Generation
- 📷 QR Code Key Scanning for Adding
- 📤 Simultaneous Sending of Transactions to Multiple Wallets (from 1 to 10 and above)
- 💱 Splitting ETH Amount Across Different Created Wallets — this feature
  will be useful if the user does not want to keep everything in one wallet
- 🔄 Fund Collection — the user will be able to collect all funds from wallets
  that were created through the ETH splitting function back into one wallet
- 🖥️ Graphical Interface — a version will also be developed so that
  transactions can be made not through the console, but through a
  graphical interface
- 📱 Other Platforms — a version for other platforms will also be
  developed, including Android, with the highest security

Support:

For all questions, you can contact us via email:
- templier@europe.com
- templier@mail.com

You can support the author in further development by sending funds to
the wallet address:
0x078A3F395E2baf41D514d5068940fB6e067AEC5f

This is needed to know that people need a secure program for working
with cryptocurrency, as I am developing the program alone and I need
your support and interest.

📊 5,569 lines of code in the Bash programming language across 12 files.
