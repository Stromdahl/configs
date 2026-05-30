# xenon — hardware reference

Bare-metal HTPC ("couch" appliance; two users: `couch` = autologin/no-sudo,
`ms` = admin/sudo).

> **Not inventoried yet.** xenon was **powered off / not on the network** at capture
> time (2026-05-30) — no DNS, mDNS, or ARP presence. Run the refresh command below
> when it's next online and fill this in.

Known from config (`hosts/xenon/modules.conf`): **Intel CPU**, NVIDIA **RTX 2060**.

> ⚠️ titan currently holds an RTX 2060 passed through to `titan-100`. If that's the
> same card, xenon may have been retired or virtualised into `titan-100` — confirm
> whether xenon is still a live machine before relying on this entry.

## Refresh (run on xenon when online)
```bash
for k in sys_vendor product_name board_name bios_version bios_date; do echo "$k=$(cat /sys/class/dmi/id/$k)"; done
lscpu; lsblk -d -e7,11 -o NAME,SIZE,MODEL,TRAN,ROTA; lspci | grep -iE "vga|3d|ethernet|network"
sudo dmidecode -t memory | grep -E "Size:|Locator:|Part Number:|Speed:" | grep -v Serial
```
