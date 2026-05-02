# Licensing & Payments

Amore includes a licensing system for selling macOS apps with license keys, integrated with Stripe for payment processing.

## Overview

The licensing system consists of:
- **Products** — License tiers with device limits and optional durations
- **License keys** — Issued to customers after purchase
- **AmoreLicensing Swift SDK** — For validating licenses in your app (see [docs.amore.computer](https://docs.amore.computer))
- **Customer portal** — Self-serve portal where users manage their license activations
- **Stripe integration** — Automatic license issuance via webhooks

## Managing Products via CLI

### List Products

```sh
amore products list --bundle-id com.example.App
```

### Create a Product

```sh
amore products create --bundle-id com.example.App \
  --name "Pro License" \
  --device-limit 3 \
  --duration-days 365
```

- `--device-limit` — Maximum devices per license (default: 1)
- `--duration-days` — License duration in days. Omit for perpetual licenses.

### Update a Product

```sh
amore products update <product-id> --bundle-id com.example.App \
  --name "Pro License" \
  --device-limit 5 \
  --stripe-product-id prod_xxx \
  --stripe-price-id price_xxx
```

### Delete a Product

```sh
amore products delete <product-id> --bundle-id com.example.App --yes
```

## Stripe Integration

Amore issues licenses automatically when a Stripe payment completes. Both one-time payments and subscriptions are supported.

### Setup Steps

1. Create a product and price in your Stripe Dashboard
2. Create the matching product in Amore with `amore products create`
3. Link them by updating the product with Stripe IDs:
   ```sh
   amore products update <id> -b com.example.App \
     --stripe-product-id prod_xxx \
     --stripe-price-id price_xxx
   ```
4. Configure your Stripe keys:
   ```sh
   amore config set app stripe-secret-key sk_live_xxx -b com.example.App
   amore config set app stripe-webhook-secret whsec_xxx -b com.example.App
   ```

### Stripe Managed Payments

Stripe can act as your Merchant of Record via [Managed Payments](https://docs.stripe.com/payments/managed-payments), handling tax, compliance, and payouts. Enable it with:

```sh
amore config set app stripe-managed-payments true -b com.example.App
```

### Customer Journey

1. Customer opens the Amore checkout link for your product (redirects to Stripe Checkout)
2. Customer completes payment (one-time or subscription)
3. Stripe webhook fires — Amore automatically issues a license key
4. Customer sees a success page with their license key
5. Customer enters the key in your app
6. Your app validates the license via the AmoreLicensing SDK
7. Customer can manage activations at the Amore customer portal

## License Types

| Type | Config | Use Case |
|------|--------|----------|
| Perpetual | Omit `--duration-days` | One-time purchase, license never expires |
| Time-limited | `--duration-days 365` | Annual subscription, license expires after N days |
| Single device | `--device-limit 1` | One activation per license |
| Multi device | `--device-limit 5` | Multiple activations per license |

## Viewing Configuration

```sh
amore config show app -b com.example.App
```

Shows Stripe keys, managed payments status, custom domain, and release notes URL.
