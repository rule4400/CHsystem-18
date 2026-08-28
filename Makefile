.PHONY: project test build-ios build-ios-device build-macos verify clean-derived-data

PROJECT := CHRemoteMonitor.xcodeproj
DERIVED_DATA := .build/DerivedData

project:
	xcodegen generate

test:
	swift test

build-ios: project
	xcodebuild -quiet -project $(PROJECT) -scheme SiteCamera -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA)/ios CODE_SIGNING_ALLOWED=NO build

build-ios-device: project
	xcodebuild -quiet -project $(PROJECT) -scheme SiteCamera -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED_DATA)/ios-device CODE_SIGNING_ALLOWED=NO build

build-macos: project
	xcodebuild -quiet -project $(PROJECT) -scheme HQMonitor -destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED_DATA)/macos CODE_SIGNING_ALLOWED=NO build

verify: test build-ios build-macos

clean-derived-data: project
	xcodebuild -quiet -project $(PROJECT) -scheme SiteCamera -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA)/ios clean
	xcodebuild -quiet -project $(PROJECT) -scheme HQMonitor -destination 'platform=macOS,arch=arm64' -derivedDataPath $(DERIVED_DATA)/macos clean
