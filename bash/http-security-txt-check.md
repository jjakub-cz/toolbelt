## http-security-txt-check.sh

Validate a site's [security.txt](https://www.rfc-editor.org/rfc/rfc9116.html) file according to RFC 9116.

### Features

* Fetches `https://<domain>/.well-known/security.txt`
* Verifies:
  * HTTP status code (expects 200)
  * `Content-Type` header (`text/plain`)
  * Presence of required `Contact:` field
  * Character set validity (UTF-8, printable ASCII + Unicode)
  * Duplicate fields
* Prints parsed fields and full file content

### Usage

```bash
http-security-txt-check.sh <domain>
```

### Example

```bash
http-security-txt-check.sh example.com
```

### Exit codes

* `0` — file is valid
* `1` — any validation error

Perfect for quick checks of `security.txt` compliance in your toolbelt.
