# AiSMUS — production backend

## Evaluation of the supplied site

The supplied `index.html` is a strong visual/prototype build, but its current data layer is local/device-only. The registration code explicitly saves to local storage and says live email verification requires a backend; rental listings, partner applications, history, cart, posts and reviews also use browser storage. Checkout currently opens an email request instead of creating a server-side order/payment. Therefore it is **not yet a production backend**.

This package supplies the missing backend foundation using Supabase:
- Authentication and persistent user profiles
- Customer/seller/service-provider/organization/partner/admin/developer roles
- Marketplace products and media
- Services and service requests
- Reviews and voting
- Posts/feed and media storage
- Partner applications and private verification documents
- Rentals and rental media
- Persistent carts
- Server-calculated orders and order items
- Payments and payment status
- Referral/commission records
- Activity history
- Notifications
- Registration/verification requests
- Row Level Security policies
- Storage buckets and storage policies
- Safe order RPC so the browser cannot choose arbitrary prices
- Frontend adapter for auth/data/storage

## Important limitation

There is currently **no Supabase project connected to this ChatGPT session**, so I cannot honestly claim that the backend has been deployed or that live email/payment processing is active. The files are ready for connection to a Supabase project.

Supabase changed new-project Data API exposure defaults in 2026, so the migration includes explicit grants in addition to RLS.

## Setup

1. Create/open a Supabase project.
2. Run `supabase/migrations/202609140001_initial.sql` in the SQL editor (or use Supabase migrations).
3. Enable Email Auth in Supabase Auth.
4. Configure your site URL and redirect URLs in Auth.
5. Put the project's **publishable** key and URL in your frontend configuration. Never expose `service_role`/secret keys.
6. Load:
   - `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2`
   - `frontend/supabase-adapter.js`
7. Replace the current localStorage-only submit/login/order functions with the adapter calls.
8. Configure custom SMTP for production email branding/verification if needed.
9. Add Paystack/Flutterwave secrets only to Edge Function secrets, never to browser code.
10. Create the first developer/admin account and set its role using trusted server-side app metadata.

## Role model

- customer: browse, cart, orders, reviews
- seller: products, product media, sales
- service_provider: services and service requests
- organization: organization/partner workflows
- partner: verified partner workflows
- admin: moderation, listings, users, orders, payments, notifications
- developer: admin privileges plus operational/backend control

Authorization must use `auth.jwt()->app_metadata`, not user-editable metadata.

## What still needs real credentials/configuration

These cannot be completed without your external account/project:
- Supabase project connection
- SMTP sender/domain
- payment provider account/API keys
- production domain
- optional WhatsApp Business API credentials
- optional map/geocoding API
- optional AI provider/API key for a real Aura backend

The schema and application boundaries are already prepared for these integrations.

## Verification checklist

After connecting a project, verify:
- sign-up email arrives and confirmation works
- sign-in/session/logout works
- user can only edit own profile/listings/cart
- anonymous users can only read published content
- admin/developer moderation works
- uploads cannot escape user folders
- partner documents remain private
- order totals are calculated from database prices
- payment webhook updates payment/order status
- commission is recorded only for eligible completed/paid orders
- activity and notifications persist per user
- deleted users cascade/retain only what is intentionally required
- Supabase security and performance advisors report no critical issues


## AiSMS+BACKEND integration status

`frontend/index.html` now loads the Supabase JS client, `supabase-config.js`, and `supabase-adapter.js`, then applies a live integration bridge without removing the existing UI.

### Required before going live
1. Create a Supabase project.
2. Run both SQL migrations in `supabase/migrations/` in filename order.
3. Enable Email authentication and configure the production Site URL/redirect URL.
4. Copy `frontend/supabase-config.js` and replace the two placeholders with the project URL and publishable/anon key.
5. Deploy the Edge Functions, including `initialize-payment` and `payment-callback`.
6. Set `PAYSTACK_SECRET_KEY`, `PAYSTACK_CALLBACK_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` as Edge Function secrets as appropriate. Never put service-role or Paystack secret keys in the frontend.
7. Add real published products/services through the database/admin workflow. The original static catalog is retained for visual continuity; checkout only accepts real UUID products that exist in Supabase.

### Important production behavior
- Registration uses Supabase email verification (magic-link/OTP style sign-in) rather than pretending verification happened.
- Posts, partner applications, rentals, service requests, profile data, and activity history are persisted in Supabase after authentication.
- Partner proof documents use the private `partner-docs` bucket and signed URLs.
- Orders derive product prices server-side through `create_order_from_cart`; the browser cannot set the order total.
- Payment initialization verifies the authenticated buyer owns the order before contacting Paystack.
- Payment callback verifies the Paystack transaction amount/currency before marking the order paid.
- Account roles cannot be self-promoted through the profile table; administrator approval is required.
