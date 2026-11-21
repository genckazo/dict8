#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

root = '/Users/kazo/Documents/VoiceKeyboard'
project_path = File.join(root, 'VoiceKeyboard.xcodeproj')
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2720'
project.root_object.attributes['LastUpgradeCheck'] = '2720'

app = project.new_target(:application, 'VoiceKeyboard', :ios, '17.0')
kb = project.new_target(:app_extension, 'VoiceKeyboardKeyboard', :ios, '17.0')

app_group = project.main_group.new_group('VoiceKeyboard', 'VoiceKeyboard')
kb_group = project.main_group.new_group('KeyboardExt', 'KeyboardExt')
shared_group = project.main_group.new_group('Shared', 'Shared')

app_files = %w[VoiceKeyboardApp.swift RootView.swift].map { |f| app_group.new_file(f) }
app_group.new_file('Info.plist')
kb_files = %w[KeyboardViewController.swift KeyButton.swift KeyRowView.swift WebAudioCapture.swift KeyboardTheme.swift TopBarView.swift ActionPillRow.swift EmojiCatalog.swift EmojiPanelView.swift SuggestionEngine.swift TextPolisher.swift PersonalModel.swift Autocorrector.swift DictationFormatter.swift].map { |f| kb_group.new_file(f) }
kb_group.new_file('Info.plist')
shared_files = %w[KeyboardPreferences.swift KeyboardLayoutDefinition.swift].map { |f| shared_group.new_file(f) }

app.add_file_references(app_files + shared_files)
app.resources_build_phase.add_file_reference(app_group.new_file('Assets.xcassets'))
kb.add_file_references(kb_files + shared_files)

app.add_dependency(kb)
copy_phase = app.new_copy_files_build_phase('Embed App Extensions')
copy_phase.dst_subfolder_spec = '13'
build_file = copy_phase.add_file_reference(kb.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }

def configure(target, bundle_id, plist, entitlements)
  target.build_configurations.each do |config|
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
    s['INFOPLIST_FILE'] = plist
    s['CODE_SIGN_STYLE'] = 'Automatic'
    s['DEVELOPMENT_TEAM'] = '5YKGZQWSA3'
    s['SWIFT_VERSION'] = '5.0'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    s['TARGETED_DEVICE_FAMILY'] = '1'
    s['GENERATE_INFOPLIST_FILE'] = 'NO'
    s['CODE_SIGN_ENTITLEMENTS'] = entitlements if entitlements
    s['CURRENT_PROJECT_VERSION'] = '2'
    s['MARKETING_VERSION'] = '2.1'
    s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end
end

configure(app, 'com.kazo.voicekeyboard', 'VoiceKeyboard/Info.plist', 'VoiceKeyboard/VoiceKeyboard.entitlements')
configure(kb, 'com.kazo.voicekeyboard.keyboard', 'KeyboardExt/Info.plist', 'KeyboardExt/KeyboardExt.entitlements')
kb.build_configurations.each do |config|
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
end
app.build_configurations.each do |config|
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
end

project.build_configurations.each do |config|
  config.build_settings['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
  config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
  config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if config.name == 'Debug'
  config.build_settings['ENABLE_TESTABILITY'] = 'YES' if config.name == 'Debug'
end

project.save
puts 'project written'
