import React, { useCallback, useEffect, useState } from 'react';
import {
  FlatList,
  Pressable,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import ShareIntent, {
  type ShareIntentPayload,
  type SharedFile,
} from 'react-native-advanced-share-intent';

function FileRow({ file }: { file: SharedFile }) {
  return (
    <View style={styles.fileRow}>
      <Text style={styles.fileName}>{file.fileName ?? file.uri}</Text>
      <Text style={styles.fileMeta}>
        {[file.type, file.mimeType, file.size ? `${file.size} bytes` : undefined]
          .filter(Boolean)
          .join(' | ')}
      </Text>
      <Text style={styles.uri} numberOfLines={2}>
        {file.uri}
      </Text>
    </View>
  );
}

function EmptyState() {
  return (
    <View style={styles.empty}>
      <Text style={styles.emptyTitle}>No shared data yet</Text>
      <Text style={styles.emptyText}>
        Share text, photos, videos, PDFs, or other files to this example app.
      </Text>
    </View>
  );
}

export default function App() {
  const isDarkMode = useColorScheme() === 'dark';
  const [payload, setPayload] = useState<ShareIntentPayload | null>(null);

  const loadInitialShare = useCallback(async () => {
    const initialShare = await ShareIntent.getInitialShare();
    setPayload(initialShare);
  }, []);

  useEffect(() => {
    loadInitialShare();
    const subscription = ShareIntent.addShareListener(setPayload);
    return () => subscription.remove();
  }, [loadInitialShare]);

  const clear = useCallback(async () => {
    await ShareIntent.clearSharedData();
    setPayload(null);
  }, []);

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>Advanced Share Intent</Text>
          <Text style={styles.subtitle}>Cold start and foreground listener demo</Text>
        </View>
        <Pressable style={styles.button} onPress={clear}>
          <Text style={styles.buttonText}>Clear</Text>
        </Pressable>
      </View>

      {payload ? (
        <FlatList
          contentContainerStyle={styles.content}
          data={payload.files}
          keyExtractor={(item, index) => `${item.uri}-${index}`}
          ListHeaderComponent={
            <View style={styles.summary}>
              <Text style={styles.label}>Received</Text>
              <Text style={styles.value}>
                {new Date(payload.receivedAt).toLocaleString()}
              </Text>
              <Text style={styles.label}>MIME</Text>
              <Text style={styles.value}>{payload.mimeType ?? 'n/a'}</Text>
              {payload.text ? (
                <>
                  <Text style={styles.label}>Text</Text>
                  <Text style={styles.value}>{payload.text}</Text>
                </>
              ) : null}
              {payload.webUrl ? (
                <>
                  <Text style={styles.label}>URL</Text>
                  <Text style={styles.value}>{payload.webUrl}</Text>
                </>
              ) : null}
            </View>
          }
          ListEmptyComponent={<Text style={styles.noFiles}>No files in this share.</Text>}
          renderItem={({ item }) => <FileRow file={item} />}
        />
      ) : (
        <EmptyState />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#f7f8fb',
  },
  header: {
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderBottomColor: '#d9deea',
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
  },
  title: {
    color: '#172033',
    fontSize: 22,
    fontWeight: '700',
  },
  subtitle: {
    color: '#596272',
    marginTop: 4,
  },
  button: {
    backgroundColor: '#1769e0',
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  buttonText: {
    color: '#fff',
    fontWeight: '700',
  },
  content: {
    padding: 20,
    gap: 12,
  },
  summary: {
    gap: 6,
    marginBottom: 8,
  },
  label: {
    color: '#596272',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  value: {
    color: '#172033',
    fontSize: 15,
    marginBottom: 8,
  },
  fileRow: {
    backgroundColor: '#fff',
    borderColor: '#d9deea',
    borderRadius: 8,
    borderWidth: StyleSheet.hairlineWidth,
    padding: 14,
    gap: 6,
  },
  fileName: {
    color: '#172033',
    fontSize: 16,
    fontWeight: '700',
  },
  fileMeta: {
    color: '#596272',
  },
  uri: {
    color: '#1769e0',
    fontSize: 12,
  },
  noFiles: {
    color: '#596272',
  },
  empty: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  emptyTitle: {
    color: '#172033',
    fontSize: 22,
    fontWeight: '700',
  },
  emptyText: {
    color: '#596272',
    marginTop: 8,
    textAlign: 'center',
    lineHeight: 21,
  },
});
