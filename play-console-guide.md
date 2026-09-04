# MealIn Customer App — Google Play Console Forms Reference

## Data Safety Form Answers

### What data does your app collect?

**Data type: Personal info**
- ✅ Name
- ✅ Email address
- ✅ Phone number
- ✅ Physical address

**Data type: Financial info**
- ✅ Payment info (processed by Razorpay — we don't store card/bank details)

**Data type: Location**
- ✅ Approximate location (for finding nearby kitchens)
- ✅ Precise location (for delivery — only when app is in use)

**Data type: App activity**
- ✅ App interactions (order history)
- ✅ Search history

**Data type: Device or other identifiers**
- ✅ Device IDs (for push notifications)

### How is this data used?

- ✅ App functionality (processing orders, delivery)
- ✅ Analytics (understanding usage patterns)
- ✅ Communication (order updates, notifications)
- ✅ Fraud prevention (security)

### Is this data shared with third parties?

- ✅ Shared with delivery partners (name, phone, address — for delivery only)
- ✅ Shared with home kitchens (name, order details — for order fulfillment)
- ✅ Shared with payment processor (Razorpay — for payment processing)
- ❌ NOT sold to third parties

### Data collection & security practices

- ✅ Data is encrypted in transit (TLS/SSL)
- ✅ Users can request data deletion
- ✅ Privacy policy link: https://sachin-devadiga.github.io/housefoods/privacy-policy.html

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
| Does the app contain user-generated content? | No (kitchen-managed menus) |
| Does the app have in-app purchases? | No (payment through Razorpay) |
| Does the app have ads? | No |
| Does the app collect personal data? | Yes (see Data Safety section) |
| Does the app share data with third parties? | Yes (kitchens, delivery partners, Razorpay) |
| Is the app intended for children under 13? | No |
| Does the app allow communication between users? | No (no in-app chat between customers) |

**Result**: Rated **Everyone** — Suitable for all ages

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
