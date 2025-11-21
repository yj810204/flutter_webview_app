#!/bin/bash
# Flutter 빌드 후 GeneratedPluginRegistrant.m 수정
# 이 스크립트는 빌드 후 자동으로 실행되어 PathProviderPlugin EXC_BAD_ACCESS를 방지합니다

set -e

FILE="ios/Runner/GeneratedPluginRegistrant.m"
if [ ! -f "$FILE" ]; then
    echo "⚠️  $FILE not found, skipping fix"
    exit 0
fi

# 이미 수정되었는지 확인
if grep -q "PathProviderPlugin registrar 유효" "$FILE"; then
    echo "✅ GeneratedPluginRegistrant.m already fixed"
    exit 0
fi

echo "🔧 Fixing GeneratedPluginRegistrant.m..."

# Python 스크립트로 메서드 교체
python3 << 'PYTHON_SCRIPT'
import re
import sys

with open('ios/Runner/GeneratedPluginRegistrant.m', 'r') as f:
    content = f.read()

# 전체 메서드 내용을 정확히 찾기
lines = content.split('\n')
new_lines = []
in_method = False
method_start = -1
method_end = -1
brace_count = 0

for i, line in enumerate(lines):
    if '+ (void)registerWithRegistry:' in line:
        in_method = True
        method_start = i
        brace_count = line.count('{') - line.count('}')
    elif in_method:
        brace_count += line.count('{') - line.count('}')
        if brace_count == 0 and '}' in line:
            method_end = i
            break

if method_start >= 0 and method_end >= 0:
    # 새 메서드 내용
    new_method = '''+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  if (registry == nil) {
    NSLog(@"❌ GeneratedPluginRegistrant: registry is nil");
    return;
  }
  
  id<FlutterPluginRegistrar> registrar;
  
  registrar = [registry registrarForPlugin:@"FLTFirebaseCorePlugin"];
  if (registrar != nil) { [FLTFirebaseCorePlugin registerWithRegistrar:registrar]; }
  
  registrar = [registry registrarForPlugin:@"FLTFirebaseMessagingPlugin"];
  if (registrar != nil) { [FLTFirebaseMessagingPlugin registerWithRegistrar:registrar]; }
  
  registrar = [registry registrarForPlugin:@"GeolocatorPlugin"];
  if (registrar != nil) { [GeolocatorPlugin registerWithRegistrar:registrar]; }
  
  registrar = [registry registrarForPlugin:@"FPPPackageInfoPlusPlugin"];
  if (registrar != nil) { [FPPPackageInfoPlusPlugin registerWithRegistrar:registrar]; }
  
  registrar = [registry registrarForPlugin:@"PathProviderPlugin"];
  if (registrar != nil) {
    NSLog(@"✅ PathProviderPlugin registrar 유효, 등록 시작");
    @try {
      [PathProviderPlugin registerWithRegistrar:registrar];
      NSLog(@"✅ PathProviderPlugin 등록 완료");
    } @catch (NSException *exception) {
      NSLog(@"❌ PathProviderPlugin 등록 실패: %@", exception.reason);
    }
  } else {
    NSLog(@"❌ PathProviderPlugin registrar is nil");
  }
  
  registrar = [registry registrarForPlugin:@"PermissionHandlerPlugin"];
  if (registrar != nil) { [PermissionHandlerPlugin registerWithRegistrar:registrar]; }
  
  registrar = [registry registrarForPlugin:@"URLLauncherPlugin"];
  if (registrar != nil) { [URLLauncherPlugin registerWithRegistrar:registrar]; }
  
  registrar = [registry registrarForPlugin:@"WebViewFlutterPlugin"];
  if (registrar != nil) {
    NSLog(@"✅ WebViewFlutterPlugin registrar 유효, 등록 시작");
    @try {
      [WebViewFlutterPlugin registerWithRegistrar:registrar];
      NSLog(@"✅ WebViewFlutterPlugin 등록 완료");
    } @catch (NSException *exception) {
      NSLog(@"❌ WebViewFlutterPlugin 등록 실패: %@", exception.reason);
    }
  } else {
    NSLog(@"❌ WebViewFlutterPlugin registrar is nil");
  }
  
  NSLog(@"✅ GeneratedPluginRegistrant: 모든 플러그인 등록 시도 완료");
}'''
    
    result = lines[:method_start] + [new_method] + lines[method_end+1:]
    
    with open('ios/Runner/GeneratedPluginRegistrant.m', 'w') as f:
        f.write('\n'.join(result))
    
    print(f"✅ 수정 완료: 라인 {method_start+1}-{method_end+1} 교체")
    sys.exit(0)
else:
    print("❌ 메서드를 찾을 수 없음")
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo "✅ GeneratedPluginRegistrant.m fixed successfully"
else
    echo "❌ Failed to fix GeneratedPluginRegistrant.m"
    exit 1
fi
