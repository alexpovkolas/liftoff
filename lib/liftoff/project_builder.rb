require 'fileutils'
require 'xcodeproj'
require 'erb'

module Liftoff
  class ProjectBuilder

    def initialize(project_configuration)
      @project_configuration = project_configuration
    end

    def create_project
      application_target_groups = [{ @project_configuration.name => @project_configuration.application_target_groups }]
      unit_test_target_groups = [{ 'UnitTests' => @project_configuration.unit_test_target_groups }]

      application_target_groups.each do |directory|
        create_tree(directory, xcode_project.app_target)
      end

      unit_test_target_groups.each do |directory|
        create_tree(directory, xcode_project.unit_test_target)
      end

      xcode_project.save
    end

    private

    def create_tree(tree, target, path = [], parent_group = xcode_project)
      if tree.class == String
        mkdir_gitkeep(path)
        move_template(path, tree)
        link_file(tree, parent_group, path, target)
        return
      end

      tree.each_pair do |raw_directory, child|
        directory = rendered_string(raw_directory)
        path += [directory]
        mkdir_gitkeep(path)
        created_group = parent_group.new_group(directory, directory)
        if child
          child.each do |c|
            create_tree(c, target, path, created_group)
          end
        end
      end
    end

    def mkdir_gitkeep(path)
      dir_path = File.join(*path)
      FileUtils.mkdir_p(dir_path)
      FileUtils.touch(File.join(dir_path, '.gitkeep'))
    end

    def move_template(path, raw_template_name)
      rendered_template_name = rendered_string(raw_template_name)
      destination_template_path = File.join(*path, rendered_template_name)
      FileManager.new.generate(raw_template_name, destination_template_path, @project_configuration)
    end

    def link_file(raw_template_name, parent_group, path, target)
      rendered_template_name = rendered_string(raw_template_name)
      file = parent_group.new_file(rendered_template_name)
      unless rendered_template_name.end_with?('h', 'plist')
        target.add_file_references([file])
      end

      if rendered_template_name.end_with?('plist')
        target.build_configurations.each do |configuration|
          configuration.build_settings['INFOPLIST_FILE'] = File.join(*path, rendered_template_name)
        end
      elsif rendered_template_name.end_with?('pch')
        target.build_configurations.each do |configuration|
          configuration.build_settings['GCC_PREFIX_HEADER'] = File.join(*path, rendered_template_name)
        end
      end
    end

    def rendered_string(raw_string)
      ERB.new(raw_string).result(@project_configuration.get_binding)
    end

    def xcode_project
      @xcode_project ||= Project.new(@project_configuration.name, @project_configuration.company, @project_configuration.prefix)
    end
  end
end
