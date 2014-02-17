require 'xcodeproj'

module Liftoff
  class Project

    def initialize(name, company, prefix)
      @name = name
      set_prefix(prefix)
      set_company_name(company)
    end

    def app_target
      @app_target ||= new_app_target
    end

    def unit_test_target
      @unit_test_target ||= new_test_target('UnitTests')
    end

    def save
      xcode_project.save
    end

    def new_group(name, path=name)
      xcode_project.new_group(name, path)
    end

    private

    def new_app_target
      xcode_project.new_target(:application, @name, :ios, 7.0)
    end

    def set_prefix(prefix)
      xcode_project.root_object.attributes['CLASSPREFIX'] = prefix
    end

    def set_company_name(company)
      xcode_project.root_object.attributes['ORGANIZATIONNAME'] = company
    end

    def new_test_target(name)
      target = xcode_project.new_resources_bundle(name, :ios)
      target.add_dependency(app_target)
      configure_search_paths(target)
      target.frameworks_build_phases.add_file_reference(xctest_framework)
      target.build_configurations.each do |configuration|
        configuration.build_settings['BUNDLE_LOADER'] = "$(BUILT_PRODUCTS_DIR)/#{@name}.app/#{@name}"
        configuration.build_settings['WRAPPER_EXTENSION'] = 'xctest'
        configuration.build_settings['TEST_HOST'] = '$(BUNDLE_LOADER)'
      end
      target
    end

    def create_xctest_framework
      xctest = xcode_project.frameworks_group.new_file('XCTest.framework')
      xctest.set_source_tree(:developer_dir)
      xctest.set_path('Library/Frameworks/XCTest.framework')
      xctest.name = 'XCTest.framework'
      xctest
    end

    def configure_search_paths(target)
      target.build_configurations.each do |configuration|
        configuration.build_settings['FRAMEWORK_SEARCH_PATHS'] = ['$(SDKROOT)/Developer/Library/Frameworks', '$(inherited)', '$(DEVELOPER_FRAMEWORKS_DIR)']
      end
    end

    def xctest_framework
      @xctest_framework ||= create_xctest_framework
    end

    def xcode_project
      path = Pathname.new("#{@name}.xcodeproj").expand_path
      puts path
      @project ||= Xcodeproj::Project.new(path)
    end
  end
end
