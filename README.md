# dumpi
---
## Installtion
- git clone https://github.com/0xaExe/dumpi.git
- cd dumpi
- chmod +x dumpi
- cp dumpi /usr/local/bin
--- 
## Usage

```sh
dumpi -u <single_api_key>
dumpi -l <file_with_api_keys>
```
---
## Features

- Checks a single API key or a list of keys from a file.
- Tests each key against various Google Maps and related endpoints (GET and POST).
- Color-coded output:
  - **Green**: Valid key (HTTP 200)
  - **Yellow**: Forbidden (HTTP 403)
- Saves valid keys to `valid_keys.txt` (deduplicated).
- Logs all output to `run.log` for later review.
- Pretty-prints JSON responses if `jq` is installed.
---
## Requirements
- [`jq`](https://stedolan.github.io/jq/) for pretty-printing JSON
---
