# geekdojo

We build **Rasputin** — an open-source homelab cluster system: a small fleet
of nodes (Raspberry Pi or Intel N100) plus a dedicated firewall node, managed
from one web UI. Atomic A/B OS updates with automatic rollback, passkey-only
auth, Docker Compose apps behind a catalog. Opinionated where you want
guidance, open where you want control — built to work in the first hour.

**→ [Get Rasputin](https://rasputin.geekdojo.com/download/)** — flashable
images and a four-step quickstart.

| Repo | What it is |
| --- | --- |
| [rasputin-control-plane](https://github.com/geekdojo/rasputin-control-plane) | The brain: Go API + web UI + node agent |
| [rasputin-os](https://github.com/geekdojo/rasputin-os) | Buildroot-based node OS (Pi + N100), RAUC A/B updates |
| [rasputin-openwrt-firewall](https://github.com/geekdojo/rasputin-openwrt-firewall) | OpenWrt-based firewall image, GRUB A/B updates, snort3 IDS |

Everything is AGPL-3.0. **Status: pre-alpha** — commodity-hardware proof
phase, running on real Pis and N100 boxes today; custom hardware comes later.

Solo-maintained, built in public with AI assistance (each repo carries an
`AI_DISCLOSURE.md`). We're recruiting **design partners** — homelab folks
willing to run Rasputin for a couple of weeks and tell us what's broken:
[raise your hand](https://github.com/geekdojo/rasputin-control-plane/issues/new?title=design%20partner).
