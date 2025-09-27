# API Documentation

- `POST /generate` - Generate a new client
  - Response JSON:
    - `success` : boolean
    - `client_name` : string
    - `ip` : string
    - `config` : string (WG config)
    - `qr_code` : base64 PNG
