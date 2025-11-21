#!/bin/bash
# iOS 빌드 스크립트 - 빌드 후 자동으로 fix_registrant.sh 실행

echo "🔨 Building iOS..."
flutter build ios --no-codesign --debug "$@"

if [ $? -eq 0 ]; then
    echo ""
    echo "🔧 Running fix_registrant.sh..."
    ./ios/fix_registrant.sh
    echo ""
    echo "✅ Build complete!"
else
    echo "❌ Build failed"
    exit 1
fi
