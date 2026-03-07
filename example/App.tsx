/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { NewAppScreen } from '@react-native/new-app-screen';

import { GestureHandlerRootView } from 'react-native-gesture-handler';
import {
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';

function AppContent() {
  const safeAreaInsets = useSafeAreaInsets();

  return (
    <View style={styles.container}>
      <NewAppScreen
        templateFileName="App.tsx"
        safeAreaInsets={safeAreaInsets}
      />
    </View>
  );
}

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
        <AppContent />
      </GestureHandlerRootView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'red',
  },
});

export default App;
