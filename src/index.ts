import {
  NativeEventEmitter,
  NativeModules,
  Platform,
  type EmitterSubscription,
} from 'react-native';

type NativeShareIntentModule = {
  getInitialShare(): Promise<ShareIntentPayload | null>;
  clearSharedData(): Promise<void>;
  setAppGroupIdentifier?(identifier: string): Promise<void>;
  setContainingAppScheme?(scheme: string): Promise<void>;
};

export type ShareIntentType = 'text' | 'image' | 'video' | 'document' | 'unknown';

export type SharedFile = {
  uri: string;
  fileName?: string;
  mimeType?: string;
  size?: number;
  type: ShareIntentType;
  dateTaken?: number;
  localIdentifier?: string;
  originalUri?: string;
};

export type ShareIntentPayload = {
  text?: string;
  subject?: string;
  title?: string;
  mimeType?: string;
  files: SharedFile[];
  webUrl?: string;
  isInitial: boolean;
  receivedAt: number;
};

export type ShareIntentListener = (payload: ShareIntentPayload) => void;

const LINKING_ERROR =
  'react-native-advanced-share-intent is not linked. Rebuild the native app after installing the package.';

const NativeAdvancedShareIntent =
  NativeModules.AdvancedShareIntent as NativeShareIntentModule | undefined;

const nativeModule = new Proxy({} as NativeShareIntentModule, {
  get(_target, property: keyof NativeShareIntentModule) {
    if (!NativeAdvancedShareIntent) {
      throw new Error(LINKING_ERROR);
    }

    const value = NativeAdvancedShareIntent[property];
    if (typeof value === 'function') {
      return value.bind(NativeAdvancedShareIntent);
    }
    return value;
  },
});

const emitter = NativeAdvancedShareIntent
  ? new NativeEventEmitter(NativeAdvancedShareIntent as any)
  : null;

const EVENT_NAME = 'AdvancedShareIntentReceived';

function normalizePayload(payload: ShareIntentPayload | null): ShareIntentPayload | null {
  if (!payload) {
    return null;
  }

  return {
    ...payload,
    files: Array.isArray(payload.files) ? payload.files : [],
    receivedAt: payload.receivedAt ?? Date.now(),
    isInitial: Boolean(payload.isInitial),
  };
}

const ShareIntent = {
  async getInitialShare(): Promise<ShareIntentPayload | null> {
    return normalizePayload(await nativeModule.getInitialShare());
  },

  addShareListener(listener: ShareIntentListener): EmitterSubscription {
    if (!emitter) {
      throw new Error(LINKING_ERROR);
    }

    return emitter.addListener(EVENT_NAME, (payload: ShareIntentPayload) => {
      const normalizedPayload = normalizePayload(payload);
      if (normalizedPayload) {
        listener(normalizedPayload);
      }
    });
  },

  async clearSharedData(): Promise<void> {
    await nativeModule.clearSharedData();
  },

  async setAppGroupIdentifier(identifier: string): Promise<void> {
    if (Platform.OS !== 'ios') {
      return;
    }

    if (!nativeModule.setAppGroupIdentifier) {
      throw new Error('setAppGroupIdentifier is not available on this platform.');
    }

    await nativeModule.setAppGroupIdentifier(identifier);
  },

  async setContainingAppScheme(scheme: string): Promise<void> {
    if (Platform.OS !== 'ios') {
      return;
    }

    if (!nativeModule.setContainingAppScheme) {
      throw new Error('setContainingAppScheme is not available on this platform.');
    }

    await nativeModule.setContainingAppScheme(scheme);
  },
};

export default ShareIntent;
