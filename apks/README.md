# APK build output

Home for every APK built from this repository. `scripts/build-apks.sh` writes
here; nothing else should.

## Layout

```
apks/
  latest/                    newest build for each role (one APK per role)
  latest/SHA256SUMS          checksums for the APKs in latest/
  archive/<timestamp>/       previous builds, kept when a role is rebuilt
  archive/<timestamp>/SHA256SUMS
```

`latest/` holds the newest build for each role - one universal APK per role, or
three per-ABI APKs per role when `--split-per-abi` is used. Rebuilding a role
moves the outgoing APKs into `archive/<timestamp>/` first, so no build is ever
overwritten in place and every past build stays recoverable.

## Roles

| Role key       | App name      | applicationId             | File stem           |
| -------------- | ------------- | ------------------------- | ------------------- |
| `customer`     | MEALIN        | `app.mealin.customer`     | `mealin-customer`   |
| `chef`         | MEALIN RESTO  | `app.mealin.kitchen`      | `mealin-kitchen`    |
| `delivery_partner` | MEALIN RIDER | `app.mealin.delivery`   | `mealin-delivery`   |

`chef` is the role key; the filename says `kitchen` to match the
`applicationId`. `APP_ROLE` is what the app itself reads, so the key column is
the one to pass to `--role`.

## File names

```
mealin-customer-1.3.0+500.apk           release, universal APK
mealin-customer-1.3.0+500-DEBUG.apk     debug, universal APK
mealin-kitchen-1.3.0+500.apk
mealin-delivery-1.3.0+500.apk
```

With `--split-per-abi` each role produces one APK per ABI instead:

```
mealin-customer-1.3.0+500-armeabi-v7a.apk
mealin-customer-1.3.0+500-arm64-v8a.apk
mealin-customer-1.3.0+500-x86_64.apk
```

Split APKs have different `versionCode`s - Flutter adds a per-ABI offset so
Play can order per-ABI updates. For `versionCode` 500 that means
`armeabi-v7a` 1500, `arm64-v8a` 2500, `x86_64` 4500. This is expected, not a
packaging mistake.

The version is read from `version:` in `pubspec.yaml`. Bump it there before
building if the version in the APK name should change.

## Building

```bash
# all three roles, release
./scripts/build-apks.sh

# one role
./scripts/build-apks.sh --role customer

# one APK per ABI instead of a universal APK
./scripts/build-apks.sh --role customer --split-per-abi

# debug build (no signing, Maps left blank if no key is exported)
./scripts/build-apks.sh --role customer --debug
```

Requirements for a release build:

- `MAPS_API_KEY` in the environment. It is baked into the manifest at build
  time, so it cannot be added afterwards. Release builds stop without it.
- `RAZORPAY_KEY` in the environment. Without it the app embeds the literal
  placeholder `rzp_test_YOUR_KEY_HERE` and payments break. Release builds stop
  without it. A `rzp_test_` key is accepted but warned about: fine for
  sideloading, a Play Store violation if published.
- `android/key.properties` and the keystore it points at. Both are
  gitignored - see `android/.gitignore`. The keystore must stay out of git;
  losing the upload key means asking Google Support to reset it.

Debug builds need none of these. They warn and continue.

The script restores `android/gradle.properties` and the app-name string
resource to their original contents when it exits, including on failure.
