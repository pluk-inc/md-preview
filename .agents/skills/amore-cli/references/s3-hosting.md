# S3 Self-Hosted Distribution

Amore supports self-managed S3-compatible storage as an alternative to Amore-hosted distribution. This gives you full control over where your binaries and appcast live.

## Setup

When registering a new app, choose S3 hosting:

```sh
amore setup MyApp.app --hosting s3 \
  --s3-bucket my-releases \
  --s3-region us-east-1 \
  --s3-public-url https://cdn.example.com \
  --s3-access-key-id "$AWS_ACCESS_KEY_ID" \
  --s3-secret-access-key "$AWS_SECRET_ACCESS_KEY"
```

### Required Fields

| Field | Flag | Description |
|-------|------|-------------|
| Bucket | `--s3-bucket` | S3 bucket name |
| Region | `--s3-region` | AWS region (e.g., `us-east-1`) or `auto` for Cloudflare R2 |
| Public URL | `--s3-public-url` | Base URL where files are publicly accessible |
| Access Key ID | `--s3-access-key-id` | AWS/S3 access key |
| Secret Access Key | `--s3-secret-access-key` | AWS/S3 secret key |

### Optional Fields

| Field | Flag / Config | Description |
|-------|--------------|-------------|
| Endpoint | `--s3-endpoint` | Custom S3 endpoint URL (required for non-AWS providers like R2) |
| Path Prefix | `--s3-path-prefix` | Folder path within the bucket for uploaded files |
| Appcast Path | `config set s3 appcast-path` | Custom path to `appcast.xml` (useful for existing setups) |

## Cloudflare R2

To use Cloudflare R2 instead of AWS S3:

```sh
amore setup MyApp.app --hosting s3 \
  --s3-bucket my-bucket \
  --s3-region auto \
  --s3-endpoint https://<account-id>.r2.cloudflarestorage.com \
  --s3-public-url https://cdn.example.com \
  --s3-access-key-id "$R2_ACCESS_KEY_ID" \
  --s3-secret-access-key "$R2_SECRET_ACCESS_KEY"
```

Key difference: set region to `auto`.

## Updating S3 Config After Setup

Use `amore config set s3` to change individual fields:

```sh
amore config set s3 bucket new-bucket -b com.example.App
amore config set s3 region eu-west-1 -b com.example.App
amore config set s3 endpoint https://custom.endpoint.com -b com.example.App
amore config set s3 path-prefix releases/myapp -b com.example.App
amore config set s3 public-url https://cdn.example.com -b com.example.App
amore config set s3 appcast-path custom/appcast.xml -b com.example.App
```

View current config:
```sh
amore config show s3 -b com.example.App
```

## Credentials

S3 credentials are resolved in this order:
1. CLI flags (`--s3-access-key-id`, `--s3-secret-access-key`)
2. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
3. macOS keychain (stored during `amore setup`)

For CI/CD, use flags or environment variables. For local development, the keychain is most convenient.

## Existing S3 Setups

If you already have an S3 bucket with an existing `appcast.xml`, Amore will:
- Read your existing `appcast.xml` and preserve all entries
- Add new releases to the beginning of the appcast
- Leave existing files untouched

Amore also creates a persistent download link at `/{path-prefix}/{product-name}.dmg` (or `.zip`) pointing to the latest release.

## Migration

Amore does not lock you in. You can switch between Amore-hosted and S3 hosting, or migrate away entirely since you own the S3 bucket and appcast.
