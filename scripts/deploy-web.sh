#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting deployment process...${NC}"

# 1. Build the web version
echo -e "${BLUE}📦 Building Flutter web...${NC}"
flutter build web --release --base-href="/prayer-time-manager-web/"

# 2. Navigate to your web deployment repo
# Update this path to where you created the web repo
WEB_REPO_PATH="$HOME/Projects/prayer-time-manager-web"

# Check if web repo exists
if [ ! -d "$WEB_REPO_PATH" ]; then
    echo "❌ Web repository not found at $WEB_REPO_PATH"
    echo "Please update the WEB_REPO_PATH in this script or create the repo first"
    exit 1
fi

cd "$WEB_REPO_PATH"

# 3. Remove old files (except .git)
echo -e "${BLUE}🧹 Cleaning old files...${NC}"
find . -not -path "./.git*" -not -name "." -delete

# 4. Copy new build files
echo -e "${BLUE}📁 Copying new build files...${NC}"
cp -r ~/Projects/MINE/prayer_time_manager/build/web/* .

# 5. Add .nojekyll if it doesn't exist
touch .nojekyll

# 6. Git operations
echo -e "${BLUE}📤 Pushing to GitHub...${NC}"
git add .
git commit -m "Update app - $(date '+%Y-%m-%d %H:%M:%S')"
git push

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}🌐 Your app will be available at: https://anissmail-2.github.io/prayer-time-manager-web/${NC}"
echo -e "${BLUE}⏳ Note: GitHub Pages may take a few minutes to update${NC}"