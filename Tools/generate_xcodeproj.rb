#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
PROJECT_DIR = File.join(ROOT, "LuneX.xcodeproj")

def uuid(key)
  Digest::MD5.hexdigest(key).upcase[0, 24]
end

def q(value)
  value.to_s.inspect
end

sources = [
  "Sources/LuneXApp/LuneXApp.swift",
  "Sources/LuneXApp/RootView.swift",
  "Sources/LuneXCore/AppModel.swift",
  "Sources/LuneXCore/AppSettings.swift",
  "Sources/LuneXCore/ClientIdentity.swift",
  "Sources/LuneXCore/ClientIdentityGenerator.swift",
  "Sources/LuneXCore/ClientIdentityManager.swift",
  "Sources/LuneXCore/HostLibrary.swift",
  "Sources/LuneXCore/Models.swift",
  "Sources/LuneXCore/RuntimeProviders.swift",
  "Sources/LuneXCore/SessionResourceTracker.swift",
  "Sources/LuneXCore/SessionState.swift",
  "Sources/LuneXCore/X509CertificateDER.swift",
  "Sources/LuneXPlatform/ContinuityPolicy.swift",
  "Sources/LuneXPlatform/PlatformLifecycle.swift",
  "Sources/LuneXPlatform/AppKitLifecycleMonitor.swift",
  "Sources/LuneXPlatform/UIKitLifecycleMonitor.swift",
  "Sources/LuneXRendering/DisplayHeadroom.swift",
  "Sources/LuneXRendering/MetalStreamSurface.swift",
  "Sources/LuneXInput/GameControllerInputAdapter.swift",
  "Sources/LuneXInput/InputEvents.swift",
  "Sources/LuneXInput/InputDiagnostics.swift",
  "Sources/LuneXInput/InputMapper.swift",
  "Sources/LuneXInput/MacInputAdapter.swift",
  "Sources/LuneXInput/TVRemoteFocusInputAdapter.swift",
  "Sources/LuneXInput/TouchInputAdapter.swift",
  "Sources/LuneXAudio/AudioSessionPipeline.swift",
  "Sources/LuneXAudio/AudioRouteState.swift",
  "Sources/LuneXDiagnostics/DiagnosticsStore.swift",
  "Sources/LuneXDiagnostics/RuntimeDiagnostics.swift",
  "Sources/LuneXNetworking/HostDiscovery.swift",
  "Sources/LuneXNetworking/AppCatalog.swift",
  "Sources/LuneXNetworking/BoundedFrameDecoder.swift",
  "Sources/LuneXNetworking/HostEndpoint.swift",
  "Sources/LuneXNetworking/NetworkChannels.swift",
  "Sources/LuneXNetworking/Pairing.swift",
  "Sources/LuneXNetworking/PairingCrypto.swift",
  "Sources/LuneXNetworking/PinnedHTTPSClient.swift",
  "Sources/LuneXNetworking/ServerInfo.swift",
  "Sources/LuneXNetworking/StreamNegotiation.swift",
  "Sources/LuneXPersistence/JSONFileStores.swift",
  "Sources/LuneXPersistence/KeychainClientIdentityStore.swift"
]

test_support_sources = [
  "Sources/LuneXCore/AppModel.swift",
  "Sources/LuneXCore/AppSettings.swift",
  "Sources/LuneXCore/ClientIdentity.swift",
  "Sources/LuneXCore/ClientIdentityGenerator.swift",
  "Sources/LuneXCore/ClientIdentityManager.swift",
  "Sources/LuneXCore/HostLibrary.swift",
  "Sources/LuneXCore/Models.swift",
  "Sources/LuneXCore/RuntimeProviders.swift",
  "Sources/LuneXCore/SessionResourceTracker.swift",
  "Sources/LuneXCore/SessionState.swift",
  "Sources/LuneXCore/X509CertificateDER.swift",
  "Sources/LuneXPlatform/ContinuityPolicy.swift",
  "Sources/LuneXPlatform/PlatformLifecycle.swift",
  "Sources/LuneXRendering/DisplayHeadroom.swift",
  "Sources/LuneXInput/GameControllerInputAdapter.swift",
  "Sources/LuneXInput/InputEvents.swift",
  "Sources/LuneXInput/InputDiagnostics.swift",
  "Sources/LuneXInput/InputMapper.swift",
  "Sources/LuneXInput/MacInputAdapter.swift",
  "Sources/LuneXInput/TVRemoteFocusInputAdapter.swift",
  "Sources/LuneXInput/TouchInputAdapter.swift",
  "Sources/LuneXAudio/AudioSessionPipeline.swift",
  "Sources/LuneXAudio/AudioRouteState.swift",
  "Sources/LuneXDiagnostics/DiagnosticsStore.swift",
  "Sources/LuneXDiagnostics/RuntimeDiagnostics.swift",
  "Sources/LuneXNetworking/HostDiscovery.swift",
  "Sources/LuneXNetworking/AppCatalog.swift",
  "Sources/LuneXNetworking/BoundedFrameDecoder.swift",
  "Sources/LuneXNetworking/HostEndpoint.swift",
  "Sources/LuneXNetworking/NetworkChannels.swift",
  "Sources/LuneXNetworking/Pairing.swift",
  "Sources/LuneXNetworking/PairingCrypto.swift",
  "Sources/LuneXNetworking/PinnedHTTPSClient.swift",
  "Sources/LuneXNetworking/ServerInfo.swift",
  "Sources/LuneXNetworking/StreamNegotiation.swift",
  "Sources/LuneXPersistence/JSONFileStores.swift",
  "Sources/LuneXPersistence/KeychainClientIdentityStore.swift"
]

test_sources = [
  "Tests/LuneXCoreTests/AppCatalogTests.swift",
  "Tests/LuneXCoreTests/AppModelWorkflowTests.swift",
  "Tests/LuneXCoreTests/AudioPipelineTests.swift",
  "Tests/LuneXCoreTests/ClientIdentityGenerationTests.swift",
  "Tests/LuneXCoreTests/ClientIdentityLifecycleTests.swift",
  "Tests/LuneXCoreTests/ControllerAndDiagnosticsTests.swift",
  "Tests/LuneXCoreTests/ContinuityPolicyTests.swift",
  "Tests/LuneXCoreTests/DiscoveryTests.swift",
  "Tests/LuneXCoreTests/LifecycleRenderPolicyTests.swift",
  "Tests/LuneXCoreTests/NetworkChannelTests.swift",
  "Tests/LuneXCoreTests/HostAndPersistenceTests.swift",
  "Tests/LuneXCoreTests/InputAdapterTests.swift",
  "Tests/LuneXCoreTests/PairingStateMachineTests.swift",
  "Tests/LuneXCoreTests/PairingCryptoTests.swift",
  "Tests/LuneXCoreTests/RuntimeProviderContractTests.swift",
  "Tests/LuneXCoreTests/RuntimeDiagnosticsTests.swift",
  "Tests/LuneXCoreTests/SessionResourceTrackerTests.swift",
  "Tests/LuneXCoreTests/StreamNegotiationTests.swift"
]

resources = [
  "Resources/Assets.xcassets"
]

targets = [
  {
    name: "LuneX-macOS",
    product: "LuneX-macOS.app",
    sdk: "macosx",
    platforms: "macosx",
    deployment_key: "MACOSX_DEPLOYMENT_TARGET",
    deployment: "26.0",
    bundle: "dev.lunex.client.macos",
    extra: {
      "INFOPLIST_KEY_LSApplicationCategoryType" => "public.app-category.games"
    }
  },
  {
    name: "LuneX-iOS",
    product: "LuneX-iOS.app",
    sdk: "iphoneos",
    platforms: "iphoneos iphonesimulator",
    deployment_key: "IPHONEOS_DEPLOYMENT_TARGET",
    deployment: "26.0",
    bundle: "dev.lunex.client.ios",
    extra: {
      "TARGETED_DEVICE_FAMILY" => "1,2",
      "INFOPLIST_KEY_UIBackgroundModes" => "audio",
      "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone" => "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
      "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad" => "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
    }
  },
  {
    name: "LuneX-tvOS",
    product: "LuneX-tvOS.app",
    sdk: "appletvos",
    platforms: "appletvos appletvsimulator",
    deployment_key: "TVOS_DEPLOYMENT_TARGET",
    deployment: "26.0",
    bundle: "dev.lunex.client.tvos",
    extra: {
      "TARGETED_DEVICE_FAMILY" => "3",
      "INFOPLIST_KEY_UIBackgroundModes" => "audio"
    }
  },
  {
    name: "LuneX-visionOS",
    product: "LuneX-visionOS.app",
    sdk: "xros",
    platforms: "xros xrsimulator",
    deployment_key: "XROS_DEPLOYMENT_TARGET",
    deployment: "26.0",
    bundle: "dev.lunex.client.visionos",
    extra: {
      "TARGETED_DEVICE_FAMILY" => "7",
      "INFOPLIST_KEY_UIBackgroundModes" => "audio"
    }
  }
]

FileUtils.mkdir_p(PROJECT_DIR)

objects = []

file_refs = {}
build_files = {}

(sources + resources + test_sources).each do |path|
  key = "file:#{path}"
  file_refs[path] = uuid(key)
  last_known = path.end_with?(".swift") ? "sourcecode.swift" : "folder.assetcatalog"
  objects << "#{file_refs[path]} /* #{File.basename(path)} */ = {isa = PBXFileReference; lastKnownFileType = #{last_known}; path = #{q(path)}; sourceTree = \"<group>\"; };"
end

targets.each do |target|
  product_id = uuid("product:#{target[:name]}")
  target[:product_id] = product_id
  objects << "#{product_id} /* #{target[:product]} */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = #{q(target[:product])}; sourceTree = BUILT_PRODUCTS_DIR; };"

  (sources + resources).each do |path|
    id = uuid("build:#{target[:name]}:#{path}")
    build_files[[target[:name], path]] = id
    objects << "#{id} /* #{File.basename(path)} in #{path.end_with?(".swift") ? "Sources" : "Resources"} */ = {isa = PBXBuildFile; fileRef = #{file_refs[path]} /* #{File.basename(path)} */; };"
  end
end

test_target = {
  name: "LuneXCoreTests",
  product: "LuneXCoreTests.xctest",
  sdk: "macosx",
  platforms: "macosx",
  deployment_key: "MACOSX_DEPLOYMENT_TARGET",
  deployment: "26.0",
  bundle: "dev.lunex.client.coretests"
}

test_product_id = uuid("product:#{test_target[:name]}")
test_target[:product_id] = test_product_id
objects << "#{test_product_id} /* #{test_target[:product]} */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = #{q(test_target[:product])}; sourceTree = BUILT_PRODUCTS_DIR; };"

(test_support_sources + test_sources).each do |path|
  id = uuid("build:#{test_target[:name]}:#{path}")
  build_files[[test_target[:name], path]] = id
  objects << "#{id} /* #{File.basename(path)} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_refs[path]} /* #{File.basename(path)} */; };"
end

group_ids = {
  main: uuid("group:main"),
  sources: uuid("group:sources"),
  tests: uuid("group:tests"),
  resources: uuid("group:resources"),
  products: uuid("group:products")
}

source_children = sources.map { |path| "#{file_refs[path]} /* #{File.basename(path)} */" }.join(",\n\t\t\t\t")
test_children = test_sources.map { |path| "#{file_refs[path]} /* #{File.basename(path)} */" }.join(",\n\t\t\t\t")
resource_children = resources.map { |path| "#{file_refs[path]} /* #{File.basename(path)} */" }.join(",\n\t\t\t\t")
product_children = (targets + [test_target]).map { |target| "#{target[:product_id]} /* #{target[:product]} */" }.join(",\n\t\t\t\t")

objects << "#{group_ids[:sources]} /* Sources */ = {isa = PBXGroup; children = (\n\t\t\t\t#{source_children}\n\t\t\t); name = Sources; sourceTree = \"<group>\"; };"
objects << "#{group_ids[:tests]} /* Tests */ = {isa = PBXGroup; children = (\n\t\t\t\t#{test_children}\n\t\t\t); name = Tests; sourceTree = \"<group>\"; };"
objects << "#{group_ids[:resources]} /* Resources */ = {isa = PBXGroup; children = (\n\t\t\t\t#{resource_children}\n\t\t\t); name = Resources; sourceTree = \"<group>\"; };"
objects << "#{group_ids[:products]} /* Products */ = {isa = PBXGroup; children = (\n\t\t\t\t#{product_children}\n\t\t\t); name = Products; sourceTree = \"<group>\"; };"
objects << "#{group_ids[:main]} = {isa = PBXGroup; children = (\n\t\t\t\t#{group_ids[:sources]} /* Sources */,\n\t\t\t\t#{group_ids[:tests]} /* Tests */,\n\t\t\t\t#{group_ids[:resources]} /* Resources */,\n\t\t\t\t#{group_ids[:products]} /* Products */,\n\t\t\t); sourceTree = \"<group>\"; };"

config_list_project = uuid("config-list:project")
project_debug = uuid("config:project:Debug")
project_release = uuid("config:project:Release")

%w[Debug Release].each do |cfg|
  cfg_id = cfg == "Debug" ? project_debug : project_release
  optimization = cfg == "Debug" ? "-Onone" : "-O"
  debug_settings = cfg == "Debug" ? "YES" : "NO"
  objects << "#{cfg_id} /* #{cfg} */ = {isa = XCBuildConfiguration; buildSettings = {ALWAYS_SEARCH_USER_PATHS = NO; CLANG_ENABLE_MODULES = YES; CODE_SIGN_STYLE = Automatic; ENABLE_USER_SCRIPT_SANDBOXING = NO; GCC_NO_COMMON_BLOCKS = YES; SWIFT_OPTIMIZATION_LEVEL = #{optimization}; SWIFT_VERSION = 6.0; DEBUG_INFORMATION_FORMAT = dwarf; ONLY_ACTIVE_ARCH = #{debug_settings};}; name = #{cfg}; };"
end
objects << "#{config_list_project} /* Build configuration list for PBXProject */ = {isa = XCConfigurationList; buildConfigurations = (#{project_debug} /* Debug */, #{project_release} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"

native_target_ids = []

targets.each do |target|
  native_id = uuid("target:#{target[:name]}")
  native_target_ids << native_id
  sources_phase = uuid("phase:sources:#{target[:name]}")
  resources_phase = uuid("phase:resources:#{target[:name]}")
  frameworks_phase = uuid("phase:frameworks:#{target[:name]}")
  config_list = uuid("config-list:#{target[:name]}")
  debug = uuid("config:#{target[:name]}:Debug")
  release = uuid("config:#{target[:name]}:Release")

  source_builds = sources.map { |path| "#{build_files[[target[:name], path]]} /* #{File.basename(path)} in Sources */" }.join(",\n\t\t\t\t")
  resource_builds = resources.map { |path| "#{build_files[[target[:name], path]]} /* #{File.basename(path)} in Resources */" }.join(",\n\t\t\t\t")

  objects << "#{sources_phase} /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n\t\t\t\t#{source_builds}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };"
  objects << "#{resources_phase} /* Resources */ = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (\n\t\t\t\t#{resource_builds}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };"
  objects << "#{frameworks_phase} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"

  %w[Debug Release].each do |cfg|
    cfg_id = cfg == "Debug" ? debug : release
    optimization = cfg == "Debug" ? "-Onone" : "-O"
    settings = {
      "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME" => "AccentColor",
      "CODE_SIGN_STYLE" => "Automatic",
      "CURRENT_PROJECT_VERSION" => "1",
      "DEVELOPMENT_TEAM" => "",
      "ENABLE_HARDENED_RUNTIME" => "YES",
      "ENABLE_USER_SCRIPT_SANDBOXING" => "NO",
      "GENERATE_INFOPLIST_FILE" => "YES",
      "INFOPLIST_KEY_CFBundleDisplayName" => "LuneX",
      "INFOPLIST_KEY_NSHumanReadableCopyright" => "Copyright © 2026 LuneX.",
      "MARKETING_VERSION" => "0.1.0",
      "PRODUCT_BUNDLE_IDENTIFIER" => target[:bundle],
      "PRODUCT_NAME" => "$(TARGET_NAME)",
      "SDKROOT" => target[:sdk],
      "SUPPORTED_PLATFORMS" => target[:platforms],
      "SWIFT_EMIT_LOC_STRINGS" => "YES",
      "SWIFT_OPTIMIZATION_LEVEL" => optimization,
      "SWIFT_STRICT_CONCURRENCY" => "complete",
      "SWIFT_VERSION" => "6.0",
      target[:deployment_key] => target[:deployment]
    }.merge(target[:extra])
    settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG" if cfg == "Debug"
    build_settings = settings.map { |key, value| "\t\t\t\t#{key} = #{q(value)};" }.join("\n")
    objects << "#{cfg_id} /* #{cfg} */ = {isa = XCBuildConfiguration; buildSettings = {\n#{build_settings}\n\t\t\t}; name = #{cfg}; };"
  end
  objects << "#{config_list} /* Build configuration list for #{target[:name]} */ = {isa = XCConfigurationList; buildConfigurations = (#{debug} /* Debug */, #{release} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
  objects << "#{native_id} /* #{target[:name]} */ = {isa = PBXNativeTarget; buildConfigurationList = #{config_list} /* Build configuration list for #{target[:name]} */; buildPhases = (#{sources_phase} /* Sources */, #{frameworks_phase} /* Frameworks */, #{resources_phase} /* Resources */); buildRules = (); dependencies = (); name = #{q(target[:name])}; productName = #{q(target[:name])}; productReference = #{target[:product_id]} /* #{target[:product]} */; productType = \"com.apple.product-type.application\"; };"
end

test_native_id = uuid("target:#{test_target[:name]}")
native_target_ids << test_native_id
test_sources_phase = uuid("phase:sources:#{test_target[:name]}")
test_frameworks_phase = uuid("phase:frameworks:#{test_target[:name]}")
test_config_list = uuid("config-list:#{test_target[:name]}")
test_debug = uuid("config:#{test_target[:name]}:Debug")
test_release = uuid("config:#{test_target[:name]}:Release")
test_source_builds = (test_support_sources + test_sources).map { |path| "#{build_files[[test_target[:name], path]]} /* #{File.basename(path)} in Sources */" }.join(",\n\t\t\t\t")

objects << "#{test_sources_phase} /* Sources */ = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n\t\t\t\t#{test_source_builds}\n\t\t\t); runOnlyForDeploymentPostprocessing = 0; };"
objects << "#{test_frameworks_phase} /* Frameworks */ = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };"

%w[Debug Release].each do |cfg|
  cfg_id = cfg == "Debug" ? test_debug : test_release
  optimization = cfg == "Debug" ? "-Onone" : "-O"
  settings = {
    "CODE_SIGN_STYLE" => "Automatic",
    "CURRENT_PROJECT_VERSION" => "1",
    "DEVELOPMENT_TEAM" => "",
    "ENABLE_USER_SCRIPT_SANDBOXING" => "NO",
    "GENERATE_INFOPLIST_FILE" => "YES",
    "MARKETING_VERSION" => "0.1.0",
    "PRODUCT_BUNDLE_IDENTIFIER" => test_target[:bundle],
    "PRODUCT_NAME" => "$(TARGET_NAME)",
    "SDKROOT" => test_target[:sdk],
    "SUPPORTED_PLATFORMS" => test_target[:platforms],
    "SWIFT_OPTIMIZATION_LEVEL" => optimization,
    "SWIFT_STRICT_CONCURRENCY" => "complete",
    "SWIFT_VERSION" => "6.0",
    "WRAPPER_EXTENSION" => "xctest",
    test_target[:deployment_key] => test_target[:deployment]
  }
  settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG" if cfg == "Debug"
  build_settings = settings.map { |key, value| "\t\t\t\t#{key} = #{q(value)};" }.join("\n")
  objects << "#{cfg_id} /* #{cfg} */ = {isa = XCBuildConfiguration; buildSettings = {\n#{build_settings}\n\t\t\t}; name = #{cfg}; };"
end

objects << "#{test_config_list} /* Build configuration list for #{test_target[:name]} */ = {isa = XCConfigurationList; buildConfigurations = (#{test_debug} /* Debug */, #{test_release} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };"
objects << "#{test_native_id} /* #{test_target[:name]} */ = {isa = PBXNativeTarget; buildConfigurationList = #{test_config_list} /* Build configuration list for #{test_target[:name]} */; buildPhases = (#{test_sources_phase} /* Sources */, #{test_frameworks_phase} /* Frameworks */); buildRules = (); dependencies = (); name = #{q(test_target[:name])}; productName = #{q(test_target[:name])}; productReference = #{test_target[:product_id]} /* #{test_target[:product]} */; productType = \"com.apple.product-type.bundle.unit-test\"; };"

project_id = uuid("project")
target_attrs = (targets + [test_target]).map { |target| "#{uuid("target:#{target[:name]}")} = {CreatedOnToolsVersion = 26.4; LastSwiftMigration = 2640;};" }.join(" ")
objects << "#{project_id} /* Project object */ = {isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 2640; LastUpgradeCheck = 2640; TargetAttributes = {#{target_attrs}};}; buildConfigurationList = #{config_list_project} /* Build configuration list for PBXProject */; compatibilityVersion = \"Xcode 15.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = #{group_ids[:main]}; productRefGroup = #{group_ids[:products]} /* Products */; projectDirPath = \"\"; projectRoot = \"\"; targets = (#{native_target_ids.join(", ")}); };"

pbxproj = <<~PBX
  // !$*UTF8*$!
  {
    archiveVersion = 1;
    classes = {};
    objectVersion = 77;
    objects = {
  \t\t#{objects.sort.join("\n\t\t")}
    };
    rootObject = #{project_id} /* Project object */;
  }
PBX

File.write(File.join(PROJECT_DIR, "project.pbxproj"), pbxproj)
puts "Generated #{File.join(PROJECT_DIR, "project.pbxproj")}"
