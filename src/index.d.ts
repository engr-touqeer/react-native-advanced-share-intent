import type { EmitterSubscription } from 'react-native';

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

declare const ShareIntent: {
  getInitialShare(): Promise<ShareIntentPayload | null>;
  addShareListener(listener: ShareIntentListener): EmitterSubscription;
  clearSharedData(): Promise<void>;
  setAppGroupIdentifier(identifier: string): Promise<void>;
  setContainingAppScheme(scheme: string): Promise<void>;
};

export default ShareIntent;
