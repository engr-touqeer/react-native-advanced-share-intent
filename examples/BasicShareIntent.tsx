import React, { useCallback, useEffect, useState } from 'react';
import { Button, FlatList, SafeAreaView, Text, View } from 'react-native';
import ShareIntent, {
  type ShareIntentPayload,
  type SharedFile,
} from 'react-native-advanced-share-intent';

function SharedFileRow({ file }: { file: SharedFile }) {
  return (
    <View>
      <Text>{file.fileName ?? file.name ?? 'Shared file'}</Text>
      <Text>{file.mimeType ?? file.type}</Text>
      <Text>{file.uri}</Text>
    </View>
  );
}

export default function BasicShareIntentExample() {
  const [share, setShare] = useState<ShareIntentPayload | null>(null);

  useEffect(() => {
    ShareIntent.getInitialShare().then(setShare);

    const subscription = ShareIntent.addShareListener(setShare);
    return () => subscription.remove();
  }, []);

  const clearShare = useCallback(async () => {
    await ShareIntent.clearSharedData();
    setShare(null);
  }, []);

  return (
    <SafeAreaView>
      <Button title="Clear shared data" onPress={clearShare} />

      {share?.text ? <Text>{share.text}</Text> : null}
      {share?.webUrl ? <Text>{share.webUrl}</Text> : null}

      <FlatList
        data={share?.files ?? []}
        keyExtractor={(item, index) => `${item.uri}-${index}`}
        renderItem={({ item }) => <SharedFileRow file={item} />}
        ListEmptyComponent={<Text>No shared files yet.</Text>}
      />
    </SafeAreaView>
  );
}
