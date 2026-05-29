# react-native-advanced-share-intent

Lightweight React Native share intent handling for Android and iOS Share Extensions.

`react-native-advanced-share-intent` exposes a small typed API for reading content shared into your app from Android share sheets and iOS Share Extensions. It supports cold starts, foreground shares, text, URLs, images, videos, documents, multiple files, metadata, and explicit cleanup.

## Features

- Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE`
- iOS Share Extension support with App Groups
- Cold-start delivery with `getInitialShare()`
- Foreground delivery with `addShareListener()`
- Cleanup with `clearSharedData()`
- Text, URL, image, video, document, and multi-file shares
- File name, size, MIME type, original URI, and capture date metadata where available
- iOS Photos asset preservation with `ph://` local identifiers when available
- TypeScript definitions
- No runtime dependencies
- React Native autolinking support

## Installation

Using npm:

```sh
npm install react-native-advanced-share-intent
```

Using Yarn:

```sh
yarn add react-native-advanced-share-intent
```

For iOS, install pods after adding the package:

```sh
cd ios && pod install
```

Rebuild the native app after installation.

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

Android returns shared files as provider-backed `content://` URIs. The library does not copy large file bytes into JavaScript memory. Pass the URI to your uploader, media pipeline, or a native file-copy step when your app needs a local copy.

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

5. Configure the App Group from JavaScript before reading initial data:

```ts
import ShareIntent from 'react-native-advanced-share-intent';

await ShareIntent.setAppGroupIdentifier('group.com.example.myapp');
await ShareIntent.setContainingAppScheme('myapp');

const initialShare = await ShareIntent.getInitialShare();
```

The extension preserves Photos library items as `ph://` URIs with `localIdentifier` when iOS exposes a `PHAsset`. Other files are copied into the App Group container and returned as `file://` URLs. For long-running uploads, copy or consume those files promptly after receiving the payload, then call `clearSharedData()` to remove cached share-extension files.

## Usage

Read the share that launched the app:

```ts
import ShareIntent from 'react-native-advanced-share-intent';

const share = await ShareIntent.getInitialShare();

if (share) {
  console.log(share.text);
  console.log(share.files);
}
```

Listen for new shares while the app is running:

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

Clear processed shared data:

```ts
await ShareIntent.clearSharedData();
```

Named function exports are also available:

```ts
import {
  getInitialShare,
  addShareListener,
  clearSharedData,
} from 'react-native-advanced-share-intent';
```

For a compact copyable component, see [`examples/BasicShareIntent.tsx`](examples/BasicShareIntent.tsx).

## API Reference

### `getInitialShare()`

```ts
getInitialShare(): Promise<ShareIntentPayload | null>
```

Returns the share payload that launched the app, or `null` when the app was not opened from a share.

### `addShareListener(listener)`

```ts
addShareListener(listener: ShareIntentListener): EmitterSubscription
```

Subscribes to share payloads delivered after the app is already running. Call `subscription.remove()` during cleanup.

### `clearSharedData()`

```ts
clearSharedData(): Promise<void>
```

Clears the cached share payload and removes iOS App Group files created by the Share Extension.

### `setAppGroupIdentifier(identifier)`

```ts
setAppGroupIdentifier(identifier: string): Promise<void>
```

iOS only. Sets the App Group used by the containing app and Share Extension.

### `setContainingAppScheme(scheme)`

```ts
setContainingAppScheme(scheme: string): Promise<void>
```

iOS only. Stores the URL scheme used by the Share Extension to reopen the containing app.

### Types

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
  name?: string;
  mimeType?: string;
  size?: number;
  type: 'text' | 'image' | 'video' | 'document' | 'unknown';
  dateTaken?: number;
  localIdentifier?: string;
  originalUri?: string;
};
```

## Example App

The example app stays in the GitHub repository so contributors and users can test the native behavior. It is excluded from the npm package through the root `package.json` `files` allowlist.

Clone and run the example app with npm:

```sh
git clone https://github.com/engr-touqeer/react-native-advanced-share-intent
cd react-native-advanced-share-intent/example
npm install
cd ios && pod install
cd ..
npm run ios
npm run android
```

Or run it with Yarn:

```sh
git clone https://github.com/engr-touqeer/react-native-advanced-share-intent
cd react-native-advanced-share-intent/example
yarn install
cd ios && pod install
cd ..
yarn ios
yarn android
```

The Android example is configured to receive share intents and display the parsed payload. For iOS testing, add a Share Extension target to the example app and follow the iOS setup above with your own App Group and URL scheme.

## Publishing

Install, build, and inspect the package with npm:

```sh
npm install
npm run build
npm pack --dry-run
```

Install, build, and inspect the package with Yarn:

```sh
yarn install
yarn build
yarn pack --dry-run
```

Publish manually only after reviewing the dry-run output:

```sh
npm login
npm whoami
npm publish --access public
```

npm requires either account 2FA or a granular access token with publish access and bypass 2FA enabled. If publish fails with `E403`, confirm 2FA is enabled for your npm account or create a granular npm access token with the required publishing permissions.

The npm package is intentionally limited to:

```txt
android/
ios/
src/
index.js
index.mjs
index.d.ts
react-native.config.js
react-native-advanced-share-intent.podspec
README.md
LICENSE
```

This keeps the published package lightweight while preserving the full example app in GitHub.

## Lockfile Policy

Use one package manager lockfile style in committed changes. This repository uses npm as the primary lockfile source with `package-lock.json`. Yarn is supported for installs and scripts, but `yarn.lock` should not be committed unless the project intentionally switches to Yarn as the primary package manager.

## Troubleshooting

### The native module is not linked

Run `pod install` for iOS, rebuild the native app, and make sure React Native autolinking can see the package.

### Android shares do not arrive while the app is open

Confirm the host activity uses `android:launchMode="singleTask"` and has the `SEND` or `SEND_MULTIPLE` intent filters for the MIME types you want to support.

### iOS returns `null`

Confirm the main app and Share Extension use the same App Group, the Share Extension subclasses `AdvancedShareIntentShareExtension`, and JavaScript calls `setAppGroupIdentifier()` before `getInitialShare()`.

### Large files are slow or fail to upload

The library returns provider or App Group file URIs. Copy, stream, or upload those files from a native-capable file pipeline instead of reading large files into JavaScript memory.

## Contributing

Issues and pull requests are welcome. Please keep changes focused, preserve Android and iOS share intent behavior, and test with text, one file, and multiple files where possible.

Before opening a pull request:

```sh
npm install
npm run build
npm pack --dry-run
```

## License

MIT
