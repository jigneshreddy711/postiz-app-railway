# Railway Build Optimization Script (Windows)
Write-Host "🧹 Cleaning up unnecessary files..." -ForegroundColor Cyan

# Remove test files
Get-ChildItem -Recurse -Filter "*.test.ts" | Remove-Item -Force
Get-ChildItem -Recurse -Filter "*.spec.ts" | Remove-Item -Force
Get-ChildItem -Recurse -Filter "*.test.tsx" | Remove-Item -Force
Get-ChildItem -Recurse -Filter "*.spec.tsx" | Remove-Item -Force

# Remove source maps in node_modules
Get-ChildItem -Path node_modules -Recurse -Filter "*.map" | Remove-Item -Force

# Clean nx cache
if (Test-Path .nx) { Remove-Item -Recurse -Force .nx }

# Clean dist folders
Get-ChildItem -Path apps -Recurse -Directory -Filter dist | Remove-Item -Recurse -Force
Get-ChildItem -Path apps -Recurse -Directory -Filter .next | Remove-Item -Recurse -Force

Write-Host "✅ Cleanup complete! Ready for Railway deployment." -ForegroundColor Green
