# AdviserLink Mobile (Flutter)

Uses the same Python API as the web app and routes signed-in users to their role's workspace:
students can find advisers, book and rate consultations, add confirmed meetings to a calendar,
chat, and work with task files, shared documents, version history, and milestones; advisers can
manage availability, review advisee requests and group members, manage project boards, set
consultation details, and inspect analytics records; admins can manage accounts, review moderated
conversations, view analytics, and inspect audit history. Backend role checks remain authoritative.

## Unang beses na setup
Kailangan ng Flutter SDK. Sa folder na ito (`mobile/`):

```
flutter create . --project-name adviserlink --org ph.edu.isu
flutter pub get
```

Ang `flutter create .` ay gagawa lang ng `android/`, `ios/` atbp. at hindi ibabagsak ang `lib/` at `pubspec.yaml` na nandito na.

### Android
The main Android manifest includes Internet permission for both debug and release builds.
For local development only, Android may need cleartext HTTP enabled in the debug manifest
when connecting to a local API. Do not enable cleartext traffic in the main manifest or a
production release; deployed APIs must use HTTPS.

## Patakbuhin
1. Simulan ang API na naka-bind sa lahat ng address: `uvicorn main:app --reload --host 0.0.0.0 --port 8001`
2. `flutter run`
3. Server address:
   - Android emulator: `http://10.0.2.2:8001`
   - Totoong phone (parehong Wi-Fi): `http://<IP ng PC mo>:8001`, ilagay sa **Server settings** sa unang screen ng app.
   - To use another local API port, set it in **Server settings** or pass `--dart-define=API_BASE_URL=http://10.0.2.2:<port>` to Flutter.

### Flutter Web sa phone browser
Build the web app with the computer's current LAN IP and the API's actual port. For this
local setup, the API is on port `8001`:

```powershell
flutter build web --dart-define=API_BASE_URL=http://<IP-ng-PC>:8001
python -m http.server 5001 --bind 0.0.0.0 --directory build/web
```

Open `http://<IP-ng-PC>:5001/` on the phone and keep both devices on the same Wi-Fi.
If the computer's IP changes, rebuild with the new IP and add
`http://<IP-ng-PC>:5001` to `CORS_ORIGINS` in `backend/.env`, then restart the API.

## Production Android APK
Build against the deployed HTTPS API:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.your-domain.example
```

The APK output is `build/app/outputs/flutter-apk/app-release.apk`. Before sharing it as an
official download, configure a private Android release signing key and keep its keystore
and passwords outside source control. Do not distribute a debug-signed APK as an official
release. Increment the app version in `pubspec.yaml` for each update.

Create a release keystore with `keytool`, then create `android/key.properties` locally
(this file is ignored by Git) with the following fields:

```properties
storeFile=C:/secure/path/adviserlink-release.jks
storePassword=your-keystore-password
keyAlias=adviserlink
keyPassword=your-key-password
```

Back up the keystore and its passwords securely. Losing them prevents signing compatible
updates; never upload or send them in chat.
