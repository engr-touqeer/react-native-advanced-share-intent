const {
  NativeEventEmitter,
  NativeModules,
  Platform,
} = require('react-native');

const LINKING_ERROR =
  'react-native-advanced-share-intent is not linked. Rebuild the native app after installing the package.';

const NativeAdvancedShareIntent = NativeModules.AdvancedShareIntent;
const EVENT_NAME = 'AdvancedShareIntentReceived';

const emitter = NativeAdvancedShareIntent
  ? new NativeEventEmitter(NativeAdvancedShareIntent)
  : null;

function getNativeModule() {
  if (!NativeAdvancedShareIntent) {
    throw new Error(LINKING_ERROR);
  }
  return NativeAdvancedShareIntent;
}

function normalizePayload(payload) {
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
  async getInitialShare() {
    return normalizePayload(await getNativeModule().getInitialShare());
  },

  addShareListener(listener) {
    if (!emitter) {
      throw new Error(LINKING_ERROR);
    }

    return emitter.addListener(EVENT_NAME, payload => {
      const normalizedPayload = normalizePayload(payload);
      if (normalizedPayload) {
        listener(normalizedPayload);
      }
    });
  },

  async clearSharedData() {
    await getNativeModule().clearSharedData();
  },

  async setAppGroupIdentifier(identifier) {
    if (Platform.OS !== 'ios') {
      return;
    }

    const nativeModule = getNativeModule();
    if (!nativeModule.setAppGroupIdentifier) {
      throw new Error('setAppGroupIdentifier is not available on this platform.');
    }

    await nativeModule.setAppGroupIdentifier(identifier);
  },

  async setContainingAppScheme(scheme) {
    if (Platform.OS !== 'ios') {
      return;
    }

    const nativeModule = getNativeModule();
    if (!nativeModule.setContainingAppScheme) {
      throw new Error('setContainingAppScheme is not available on this platform.');
    }

    await nativeModule.setContainingAppScheme(scheme);
  },
};

module.exports = ShareIntent;
module.exports.default = ShareIntent;
