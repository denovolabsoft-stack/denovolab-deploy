# Own Server One-Click Install

Install DeNoVoLab Class4 Fusion v6 on a customer-managed Rocky Linux 8 or
RHEL-compatible 8 server.

## Requirements

- Fresh Rocky Linux 8 compatible server with public internet access.
- Root shell or sudo access.
- Firewall allowing the ports you plan to use:
  - TCP `80`, `443` for web UI and optional SSL.
  - TCP/UDP `5060-5061` for SIP.
  - UDP `10000-20000` for RTP by default.
- Optional DNS A record if enabling Let's Encrypt SSL.

## Install

Run this on the target server:

```bash
curl -fsSL https://raw.githubusercontent.com/denovolabsoft-stack/denovolab-deploy/main/deploy/own-server/install.sh | sudo bash
```

Then open `http://SERVER_PUBLIC_IP/` and complete the first-time Class4 Fusion
wizard. Create the admin username and password there; the installer does not
store or transmit admin credentials.

## Install With SSL

Point the DNS A record to the server public IP first, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/denovolabsoft-stack/denovolab-deploy/main/deploy/own-server/install.sh | sudo ENABLE_SSL=yes DOMAIN=switch.example.com LETSENCRYPT_EMAIL=ops@example.com bash
```

SSL runs in the background after the package install. Check progress with:

```bash
sudo tail -f /var/log/class4-ssl.log
```

If DNS is not ready yet, the SSL helper keeps checking for up to 24 hours. After
fixing DNS later, you can run:

```bash
sudo /usr/local/sbin/class4-own-server-ssl.sh switch.example.com ops@example.com
```

## Logs

- Main install: `/var/log/class4-own-server-install.log`
- SSL setup: `/var/log/class4-ssl.log`

## License

The default one-click install includes the 500-port community license path. For
LRN support or more ports, copy the Switch UUID from the Class4 Fusion UI and
bind the license in `https://app.denovo.me`.
