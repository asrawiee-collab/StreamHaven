# StreamHaven Deployment Setup Guide

This document covers deploying to TestFlight using the GitHub Actions macOS runner. You can trigger the deploy manually from the Actions tab or via the GitHub API. The workflow file lives at `.github/workflows/deploy.yml` and builds with Xcode 16 on `macos-latest`, then runs `bundle exec fastlane beta --verbose`.

---

## Quick Start: TestFlight via GitHub Actions

1. Add three GitHub Secrets (Settings → Secrets and variables → Actions):
   - `APP_STORE_CONNECT_API_KEY_ID`
   - `APP_STORE_CONNECT_API_ISSUER_ID`
   - `APP_STORE_CONNECT_API_KEY_CONTENT` (Base64 of your `.p8`)
2. Trigger the workflow (Actions → "Deploy to TestFlight" → Run workflow → branch `main`).
3. Watch logs. If it fails, download the `fastlane-logs` artifact.

---

## GitHub Secrets Required

To successfully deploy to TestFlight via GitHub Actions, you need to configure the following secrets in your repository settings:

### Go to: Repository → Settings → Secrets and variables → Actions → New repository secret

### Required Secrets

#### Option 1: App Store Connect API Key (Recommended ✅)

This is the most reliable and secure method for CI/CD deployments.

1. **APP_STORE_CONNECT_API_KEY_ID**
   - Get from: [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/api)
   - Click "+" to generate a new key
   - Select "Admin" or "App Manager" role
   - Copy the Key ID

2. **APP_STORE_CONNECT_API_ISSUER_ID**
   - Found on the same Keys page
   - Copy the Issuer ID at the top

3. **APP_STORE_CONNECT_API_KEY_CONTENT**
    - Download the .p8 file when creating the API key (only shown once!)
    - Convert to Base64:
       - macOS/Linux (bash):
          ```bash
          base64 -i AuthKey_XXXXXXXXXX.p8
          ```
       - Windows (PowerShell):
          ```powershell
          [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\\Path\\To\\AuthKey_XXXXXXXXXX.p8"))
          ```
    - Paste the Base64 string as the secret value

#### Option 2: Apple ID Authentication (Alternative)

If you prefer using Apple ID instead of API keys:

1. **APPLE_ID**
   - Your Apple ID email address

2. **FASTLANE_SESSION**
   - Generate using:
     ```bash
     fastlane spaceauth -u your-apple-id@example.com
     ```
   - Copy the session string
   - Note: This expires and needs renewal periodically

#### Code Signing (Optional - if using Fastlane Match)

3. **MATCH_PASSWORD**
   - Encryption password for your certificates repository
   - Create a strong password

4. **MATCH_GIT_URL**
   - Git repository URL for storing certificates
   - Example: `https://github.com/yourusername/certificates`

5. **GIT_USERNAME** & **GIT_TOKEN**
   - Your GitHub username
   - Personal Access Token with `repo` scope
   - Generate at: GitHub → Settings → Developer settings → Personal access tokens

---

## Local Fastlane Setup

### 1. Install Dependencies

```bash
# Install Fastlane
gem install fastlane

# Or use Bundler (recommended)
bundle install
```

### 2. Update Appfile

Edit `fastlane/Appfile` with your actual credentials:

```ruby
app_identifier("com.asrawiee.StreamHaven") # Your app bundle ID
apple_id("your-apple-id@example.com")      # Your Apple ID
team_id("YOUR_TEAM_ID")                    # Your Team ID (10 characters)
```

To find your Team ID:
- Visit [Apple Developer Membership](https://developer.apple.com/account/#/membership/)
- Copy the Team ID

### 3. Test Locally

```bash
# Test build
fastlane beta --verbose

# Test with dry run
fastlane beta --verbose --skip_upload_to_testflight
```

Note: Building and signing iOS apps requires macOS with Xcode installed. Running `fastlane beta` on Windows or Linux will fail. Use a Mac (or the GitHub Actions macOS runner) for builds.

---

## Triggering the GitHub Actions Workflow

### A) From GitHub UI (Recommended)
1. Open your repo → Actions
2. Select "Deploy to TestFlight"
3. Click "Run workflow"
4. Choose branch: `main`
5. Click "Run workflow" and watch logs

### B) From Windows with PowerShell (GitHub REST API)
```powershell
$token = "ghp_your_token_here"  # GitHub token with repo + actions:write scope
$owner = "asrawiee-collab"
$repo  = "StreamHaven"

$uri = "https://api.github.com/repos/$owner/$repo/actions/workflows/deploy.yml/dispatches"
$body = @{ ref = "main" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $token"; "Accept" = "application/vnd.github+json" } -Body $body
```

On failure, the workflow uploads a `fastlane-logs` artifact containing `~/Library/Logs/gym`, `~/Library/Logs/scan`, and `fastlane/report.xml`.

---

## Troubleshooting Common Issues

### Issue 1: "No API key provided"

**Solution**: Ensure all three API key secrets are set:
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_CONTENT`

### Issue 2: "Code signing error"

**Solutions**:
1. Make sure your Xcode project has proper signing configuration
2. Use automatic signing in Xcode
3. Or set up Fastlane Match for team signing

### Issue 3: "Invalid credentials"

**Solutions**:
- Regenerate `FASTLANE_SESSION` (it expires)
- Verify Apple ID has access to the app in App Store Connect
- Check 2FA is properly configured

### Issue 4: "Build number already exists"

**Solution**: The updated Fastfile now auto-increments `bundleVersion` in `Package.swift` (SwiftPM App)

### Issue 5: Ruby version mismatch

**Solution**: The workflow now explicitly sets Ruby 3.3.0

---

## Workflow Features

The updated deployment workflow includes:

✅ **Verbose logging** - Full error details displayed
✅ **Proper Ruby setup** - Consistent Ruby 3.3.0 environment
✅ **Build log artifacts** - Logs uploaded on failure for debugging
✅ **Auto build increment** - No more duplicate build number errors
✅ **Error handling** - Detailed error messages in Fastlane

---

## Manual Deployment

If GitHub Actions fails, you can deploy manually:

```bash
# From project root
cd fastlane

# Set environment variables
export APPLE_ID="your-apple-id@example.com"

# Run deployment
fastlane beta --verbose
```

---

## Verification Steps

After setting up secrets:

1. ✅ Push a commit to `main` branch
2. ✅ Go to Actions tab in GitHub
3. ✅ Watch the "Deploy to TestFlight" workflow
4. ✅ Check the logs for detailed output
5. ✅ If it fails, download the build logs artifact

---

## Next Steps

1. **Set up all required GitHub secrets** (see above)
2. **Update `fastlane/Appfile`** with your actual Team ID
3. **Test locally first**: `fastlane beta --verbose`
4. **Push to main branch** to trigger automatic deployment
5. **Monitor GitHub Actions** for success/failure

---

## Additional Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Fastlane Match](https://docs.fastlane.tools/actions/match/)
- [GitHub Actions for iOS](https://docs.github.com/en/actions/deployment/deploying-xcode-applications)

---

## Support

If you encounter issues:

1. Check workflow logs with `--verbose` flag enabled
2. Review build logs artifact (auto-uploaded on failure)
3. Test locally with the same configuration
4. Verify all secrets are correctly set
5. Check that certificates are valid in Apple Developer Portal

**Common workflow run location**: 
`https://github.com/asrawiee-collab/StreamHaven/actions`
