# StreamHaven UI Tests

This directory contains UI tests for the StreamHaven application using XCTest UI testing framework.

## Running UI Tests

UI tests require Xcode and cannot be run via Swift Package Manager's `swift test` command.

### Using Xcode

1. **Open Project:**

   ```bash
   open StreamHaven.xcodeproj
   ```

2. **Select Test Target:**
   - In Xcode, select the `StreamHavenUITests` scheme
   - Choose an iOS Simulator (e.g., iPhone 15 Pro)

3. **Run All UI Tests:**
   - Press `Cmd + U` to run all tests
   - Or: Product → Test

4. **Run Specific Test File:**
   - Open the test file (e.g., `PiPSettingsUITests.swift`)
   - Click the diamond icon in the gutter next to the class or test method
   - Or: Right-click → Run "testName"

### Using xcodebuild (Command Line)

```bash
# Run all UI tests
xcodebuild test \
  -project StreamHaven.xcodeproj \
  -scheme StreamHaven \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:StreamHavenUITests

# Run specific test class
xcodebuild test \
  -project StreamHaven.xcodeproj \
  -scheme StreamHaven \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:StreamHavenUITests/PiPSettingsUITests

# Run specific test method
xcodebuild test \
  -project StreamHaven.xcodeproj \
  -scheme StreamHaven \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:StreamHavenUITests/PiPSettingsUITests/testPiPToggleExistsAndDefaultsToEnabled
```

## Test Files

### PiPSettingsUITests.swift

**Purpose:** Tests Picture-in-Picture settings UI and persistence.

**Coverage:**

- ✅ PiP toggle exists and defaults to enabled
- ✅ Toggle can be disabled
- ✅ Toggle can be re-enabled
- ✅ Settings persist across navigation
- ✅ Description text is present
- ✅ Platform-specific availability (iOS only)
- ✅ Complete settings workflow

**Why UI Tests?**
The unit test `PiPSupportTests.testPiPSettingDefaultValue` skips because AppStorage doesn't work properly in XCTest environments. These UI tests provide comprehensive coverage by testing the actual user interface and UserDefaults integration in a real app environment.

**Platform:** iOS only (PiP not supported on tvOS)

**Test Count:** 7 tests

### Other UI Tests

- **FavoritesManagementUITests.swift** - Tests favorites functionality
- **PlaybackControlsUITests.swift** - Tests playback controls
- **PlaylistImportUITests.swift** - Tests playlist import flow
- **ProfileSelectionUITests.swift** - Tests profile selection
- **SearchUITests.swift** - Tests search functionality
- **iPadSplitViewUITests.swift** - Tests iPad split view layout
- **tvOSFocusEngineUITests.swift** - Tests tvOS focus engine

## Debugging UI Tests

### Enable Verbose Output

```bash
xcodebuild test \
  -project StreamHaven.xcodeproj \
  -scheme StreamHaven \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:StreamHavenUITests/PiPSettingsUITests \
  | xcpretty --color --test
```

### Common Issues

**Issue:** "UI Testing Failure - No element found"

- **Solution:** Check accessibility identifiers in the app
- **Solution:** Use `.waitForExistence(timeout:)` for async elements
- **Solution:** Verify the UI hierarchy with Xcode's Accessibility Inspector

**Issue:** "Toggle value not updating"

- **Solution:** Add `sleep(1)` after tap to allow state to propagate
- **Solution:** Use `.waitForExistence()` with a predicate for the new state

**Issue:** "Test times out"

- **Solution:** Increase timeout values in `waitForExistence(timeout:)`
- **Solution:** Check if app is stuck on a loading screen or alert

### UI Test Best Practices

1. **Use Accessibility Identifiers:** Add `.accessibilityIdentifier("uniqueID")` to SwiftUI views
2. **Wait for Existence:** Always use `.waitForExistence(timeout:)` before assertions
3. **Clean State:** Reset UserDefaults or use launch arguments for clean test state
4. **Platform Guards:** Use `#if os(iOS)` to skip tests on unsupported platforms
5. **Descriptive Failures:** Use clear assertion messages for easier debugging

## CI/CD Integration

### GitHub Actions Example

```yaml
- name: Run UI Tests
  run: |
    xcodebuild test \
      -project StreamHaven.xcodeproj \
      -scheme StreamHaven \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -only-testing:StreamHavenUITests \
      -resultBundlePath TestResults.xcresult
      
- name: Upload Test Results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: ui-test-results
    path: TestResults.xcresult
```

## Performance

UI tests are slower than unit tests because they:

- Launch the full app
- Interact with the UI layer
- Wait for animations and transitions

**Typical Runtime:**

- Unit tests: < 10 seconds for 150+ tests
- UI tests: 30-60 seconds per test file

**Optimization Tips:**

- Run UI tests separately from unit tests
- Use parallel testing in Xcode (Edit Scheme → Test → Options → Execute in Parallel)
- Skip UI tests in local development, run in CI/CD only

## Documentation

For more information on XCTest UI testing, see:

- [Apple XCTest UI Testing Guide](https://developer.apple.com/documentation/xctest/user_interface_tests)
- [WWDC: Testing in Xcode](https://developer.apple.com/videos/play/wwdc2019/413/)
