# react-native-advanced-share-intent

Production-ready share intent handling for React Native apps.

`react-native-advanced-share-intent` exposes a small typed API for reading content shared into your app from Android share sheets and iOS Share Extensions. It supports cold starts, foreground shares, multiple files, text, URLs, images, videos, documents, MIME metadata, and explicit cleanup.

## Features

- Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE`
- iOS Share Extension support with App Groups
- `getInitialShare()` for cold start delivery
- `addShareListener()` for foreground/new-intent delivery
- `clearSharedData()` for cleanup after processing
- Multiple files without copying large Android `content://` assets into JS memory
- iOS Photos asset preservation with `ph://` local identifiers when available
- `dateTaken`, original URI, file name, size, and MIME metadata where the platform exposes it
- TypeScript definitions
- No runtime dependencies
- Compatible with current React Native autolinking and New Architecture apps

## Installation

```sh
npm install react-native-advanced-share-intent
```

```sh
cd ios && pod install
```

Rebuild the native app after installation.

## API

```ts
import ShareIntent from 'react-native-advanced-share-intent';

const data = await ShareIntent.getInitialShare();

const subscription = ShareIntent.addShareListener(data => {
  console.log(data);
});

await ShareIntent.clearSharedData();
subscription.remove();
```

### ShareIntentPayload

```ts
type ShareIntentPayload = {
  text?: string;
  subject?: string;
  title?: string;
  mimeType?: string;
  files: SharedFile[];
  webUrl?: string;
  isInitial: boolean;
  receivedAt: number;
};

type SharedFile = {
  uri: string;
  fileName?: string;
  mimeType?: string;
  size?: number;
  type: 'text' | 'image' | 'video' | 'document' | 'unknown';
  dateTaken?: number;
  localIdentifier?: string;
  originalUri?: string;
};
```

## Android Setup

Add share intent filters to the activity that hosts React Native. Keep `launchMode="singleTask"` so foreground shares arrive through `onNewIntent`.

```xml
<activity
  android:name=".MainActivity"
  android:launchMode="singleTask"
  android:exported="true">

  <intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/*" />
    <data android:mimeType="image/*" />
    <data android:mimeType="video/*" />
    <data android:mimeType="application/*" />
  </intent-filter>

  <intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="image/*" />
    <data android:mimeType="video/*" />
    <data android:mimeType="application/*" />
  </intent-filter>
</activity>
```

Android returns shared files as provider-backed `content://` URIs. The library does not read file bytes into JavaScript, which keeps large media and multi-file shares stable. Pass the URI to your uploader, media pipeline, or a native file-copy step when your app specifically needs a local copy.

## iOS Setup

iOS share delivery requires a Share Extension and an App Group. The library includes `AdvancedShareIntentShareExtension`, a base extension controller that collects shared items, stores a compact payload in the App Group, and opens the containing app.

1. In Xcode, add a Share Extension target.
2. Enable the same App Group on the main app target and the Share Extension target.
3. Add a URL scheme to the main app, for example `myapp`.
4. In your extension target, subclass the included controller:

```swift
import AdvancedShareIntent

final class ShareViewController: AdvancedShareIntentShareExtension {
  override var appGroupIdentifier: String {
    "group.com.example.myapp"
  }

  override var containingAppScheme: String {
    "myapp"
  }
}
```

5. Configure the App Group once from JavaScript before reading initial data:

```ts
import ShareIntent from 'react-native-advanced-share-intent';

await ShareIntent.setAppGroupIdentifier('group.com.example.myapp');
await ShareIntent.setContainingAppScheme('myapp');
const initialShare = await ShareIntent.getInitialShare();
```

The extension preserves Photos library items as `ph://` URIs with `localIdentifier` when iOS exposes a `PHAsset`. Other files are copied into the App Group container and returned as `file://` URLs. For long-running uploads, copy or consume those files promptly after receiving the payload, then call `clearSharedData()` to remove cached share-extension files.

## Usage Pattern

```ts
import { useEffect, useState } from 'react';
import ShareIntent, {
  type ShareIntentPayload,
} from 'react-native-advanced-share-intent';

export function useShareIntent() {
  const [share, setShare] = useState<ShareIntentPayload | null>(null);

  useEffect(() => {
    ShareIntent.getInitialShare().then(setShare);

    const subscription = ShareIntent.addShareListener(setShare);
    return () => subscription.remove();
  }, []);

  return share;
}
```

After your app has processed a share, call:

```ts
await ShareIntent.clearSharedData();
```

This prevents the same cold-start payload from being processed repeatedly.

## Example App

The `example` app is configured to receive Android shares and display the parsed payload:

```sh
cd example
npm install
npm run android
```

For iOS, add a Share Extension target to the example app and use the iOS setup above.

## Package Structure

```txt
android/                         Android native module
ios/                             iOS bridge and Share Extension helper
src/                             TypeScript public API
example/                         React Native example app
react-native-advanced-share-intent.podspec
react-native.config.js
```

## Publishing Checklist

Before publishing:

1. Replace `repository`, `homepage`, and `bugs` in `package.json`.
2. Run `npm run typecheck`.
3. Run `npm pack --dry-run` and inspect the included files.
4. Test Android shares with text, one file, and multiple large files.
5. Test iOS Share Extension delivery with the real App Group and URL scheme.
6. Publish with `npm publish --access public`.

## PartySharing Integration Notes

Keep PartySharing-specific routing, upload logic, auth, analytics, and domain parsing inside PartySharing. This package should only deliver normalized share payloads. A clean integration usually looks like:

```ts
const share = await ShareIntent.getInitialShare();
if (share) {
  navigation.navigate('ShareImport', { share });
}
```

The native implementation was shaped from the PartySharing production flow but generalized:

- Android keeps pending shares and retries delivery while the React bridge/listener becomes ready.
- Android reads `OpenableColumns`, `MediaStore.MediaColumns.DATE_TAKEN`, MIME type, and multi-file `ClipData`/`EXTRA_STREAM`.
- iOS stores extension payloads in an App Group, emits when the main app becomes active, preserves Photos `localIdentifier`, and sorts mixed image/video batches by capture date when needed.
- Legacy PartySharing keys are only read as a migration convenience; new apps use the generic `AdvancedShareIntentPayload` key.

## License

MIT
