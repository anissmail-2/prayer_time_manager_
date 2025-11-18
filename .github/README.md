# GitHub Workflows Directory

## CI/CD Workflow

The CI/CD workflow file (`workflows/ci.yml`) has been created locally but cannot be pushed via the Claude Code GitHub App due to permission restrictions.

### Manual Setup Required

To enable the CI/CD pipeline:

1. **Option 1: Via GitHub Web UI**
   - Navigate to your repository on GitHub
   - Go to the "Actions" tab
   - Click "New workflow" or "Set up a workflow yourself"
   - Copy the contents from `.github/workflows/ci.yml` in your local repository
   - Commit the file

2. **Option 2: Via Local Git (Outside Claude Code)**
   ```bash
   git add .github/workflows/ci.yml
   git commit -m "Add CI/CD workflow"
   git push
   ```

### Workflow Features

Once added, the CI/CD pipeline will automatically:
- ✅ Run code analysis (flutter analyze, format check)
- ✅ Execute all tests with coverage reporting
- ✅ Build Android APK and App Bundle
- ✅ Perform security scanning
- ✅ Upload artifacts and coverage reports

### Workflow File Location

The complete workflow configuration is available at:
`/home/user/prayer_time_manager_/.github/workflows/ci.yml`

For details on the CI/CD pipeline, see `docs/TESTING.md`.
