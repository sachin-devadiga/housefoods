# MealIn Customer App — Google Play Console Forms Reference

> **Corrected 18 Oct 2026.** The previous version of this file declared
> "User-generated content: No" and "Communication between users: No". Both were
> false: the app has reviews and ratings (`lib/features/customer/.../submit_review_screen.dart`)
> and a real customer↔kitchen chat (`lib/features/chat/`). Declaring otherwise is
> a mismatch Google can detect, and it is a rejection risk. The answers below now
> match the code.

## Data Safety Form Answers

### What data does your app collect?

**Data type: Personal info**
- ✅ Name
- ✅ Email address (used for OTP login)
- ✅ Phone number
- ✅ Physical address (delivery address book)

**Data type: Financial info**
- ✅ Payment info — processed by Razorpay. We store only the payment reference
  and outcome; card/bank details never reach our servers.

**Data type: Location**
- ✅ Precise location — app-in-use only, for kitchen discovery, rider
  assignment and live order tracking. Background location is NOT collected.

**Data type: App activity**
- ✅ App interactions (order history, cart, subscriptions)
- ✅ Search history

**Data type: Messages**
- ✅ Messages — in-app chat with home kitchens and support, plus support
  ticket contents.

**Data type: User-generated content**
- ✅ Reviews and ratings posted about kitchens and dishes.

**Data type: Device or other identifiers**
- ✅ Device IDs / push tokens (Firebase Cloud Messaging)

**Data type: Voice or audio**
- ✅ Microphone audio, ONLY if the user actively invokes voice ordering. Audio is
  sent to a speech-to-text provider to produce a text query and is not retained
  after transcription.

**Data type: Other — AI processing**
- ✅ Chat text sent to Google Gemini to generate the assistant's reply. API keys
  live on our servers, never in the app.

### Is any data collected for AI training?
Answer **"No data is used for training third-party AI"** unless Google/Sarvam's
enterprise terms explicitly commit otherwise. Confirm before submitting — this
answer is attested, not estimated.

### How is this data used?

- ✅ App functionality (processing orders, delivery)
- ✅ Analytics (understanding usage patterns)
- ✅ Communication (order updates, notifications)
- ✅ Fraud prevention (security)

### Is this data shared with third parties?

- ✅ Shared with delivery partners (name, phone, address — for delivery only)
- ✅ Shared with home kitchens (name, order details — for order fulfillment)
- ✅ Shared with payment processor (Razorpay — for payment processing)
- ✅ Shared with AI processors — Sarvam (speech-to-text for voice ordering) and
  Google Gemini (chat assistant replies)
- ✅ Shared with Google (Firebase Cloud Messaging — push notification delivery)
- ❌ NOT sold to third parties

### Data collection & security practices

- ✅ Data is encrypted in transit (TLS/SSL). The release build sets
  `android:usesCleartextTraffic="false"` — unencrypted connections are refused.
- ✅ Users can request data deletion
- ✅ Privacy policy: **https://mealin.in/privacy-policy.html**
  (hosted on our own domain; the old GitHub Pages URL is retired)

---

## Content Rating Questionnaire Answers

**Category**: Everyone

| Question | Answer |
|----------|--------|
| Does the app contain violent content? | No |
| Does the app contain sexual content? | No |
| Does the app contain profanity? | No |
| Does the app contain realistic violence? | No |
| Does the app contain blood/gore? | No |
| Does the app contain user-generated content? | **Yes** — reviews and ratings for kitchens and dishes |
| Does the app have in-app purchases? | **No** — physical goods (food) only, paid offline-equivalent via Razorpay. No digital goods, so Play Billing is not required. **CONFIRM: if any digital good is ever sold, this flips and Play Billing becomes mandatory.** |
| Does the app have ads? | No |
| Does the app collect personal data? | Yes (see Data Safety section) |
| Does the app share data with third parties? | Yes (kitchens, delivery partners, Razorpay, Sarvam, Google) |
| Is the app intended for children under 13? | No |
| Does the app allow communication between users? | **Yes** — in-app chat between customers and home kitchens, plus support chat. Users can block/report abusive kitchens via the support channel. |

**Result**: Rated **Everyone** — Suitable for all ages. Note that "Everyone"
does not imply child-suitable; see the Target Audience note below.

---

## Reviewer Notes (paste into the Play Console submission)

Play rejects apps reviewers cannot operate. Give them a way in.

- **Account:** phone OTP login. Use the reviewer email supplied in the listing;
  the OTP arrives by email (Brevo), so the reviewer must be able to read it.
- **Voice ordering:** tap the microphone on the MEAL AI screen. It requires the
  microphone permission — this is expected, and the app explains why at the
  permission prompt.
- **Location:** needed for kitchen discovery and delivery. Denying it still
  lets the reviewer browse the App, but no kitchens appear.
- **Ordering requires a real address** and a kitchen within range. If no
  kitchens show near the reviewer's location, use the seeded demo kitchen in
  [scripts/seed_staging.py](../../scripts/seed_staging.py) or contact
  contact@mealin.in to provision one near the reviewer.
- **Permissions:** microphone (voice ordering), precise location (delivery).
  Bluetooth/USB are for bill printing in the separate MealIn Resto app and are
  not requested by the customer app.

---

## Target Audience

- **Primary audience**: Adults (18-65) who want convenient homemade food delivery
- **Not designed for children**: App does not target or market to children under 13
- **Store listing**: Suitable for all ages

---

## Steps in Google Play Console

1. Go to https://play.google.com/console
2. Click "Create app"
3. Enter app name: **MealIn - Customer**
4. Package name: **app.mealin.customer**
5. App or game: **App**
6. Free or paid: **Free**
7. Select countries/regions
8. Complete Data Safety form (use answers above)
9. Complete Content Rating questionnaire (use answers above)
10. Set pricing: **Free**
11. Upload AAB: `build/apk-output/mealin-customer.aab`
12. Upload app icon: `play-store-icon.png`
13. Add screenshots (you capture these)
14. Copy descriptions from `play-store-listing.md`
15. Add privacy policy URL
16. Submit for review
