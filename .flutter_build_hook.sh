#!/bin/bash
# Flutter 빌드 후 자동으로 실행되는 훅
# 이 스크립트는 flutter build 후 자동으로 fix_registrant.sh를 실행합니다

if [ -f "ios/fix_registrant.sh" ]; then
    echo "Running fix_registrant.sh after build..."
    ./ios/fix_registrant.sh
fi
