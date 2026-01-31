# Railway Build Optimization Script
# Run this before deploying to Railway to reduce build size

echo "🧹 Cleaning up unnecessary files..."

# Remove all test files
find . -name "*.test.ts" -type f -delete
find . -name "*.spec.ts" -type f -delete
find . -name "*.test.tsx" -type f -delete
find . -name "*.spec.tsx" -type f -delete

# Remove source maps in node_modules
find node_modules -name "*.map" -type f -delete

# Remove documentation
find . -name "*.md" -not -path "./README.md" -type f -delete

# Remove examples and demos
rm -rf apps/extension/examples
rm -rf apps/sdk/examples
rm -rf **/examples
rm -rf **/demos

# Clean nx cache
rm -rf .nx

# Clean dist folders (will be rebuilt)
rm -rf apps/*/dist
rm -rf apps/*/.next

echo "✅ Cleanup complete! Ready for Railway deployment."
