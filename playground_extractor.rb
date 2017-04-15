require 'fileutils'
require 'xcodeproj'
require 'erb'

module XCBackyard

    ROOT_PATH = Pathname.new(File.expand_path('..', __FILE__))
    TEMPLATES_DIR_PATH = Pathname.new(File.join(ROOT_PATH, "Templates"))

    class BackyardBuilder
        def initialize(source_project_path)
            @source_project_path = source_project_path
        end

        def source_project_path
            @source_project_path
        end

        # Create directory and copy source xcodeproj
        def copy_xcodeproj_file(result_dir_path)

            if Dir.exist?(result_dir_path)
                FileUtils.rm_r(result_dir_path)
            end

            Dir.mkdir(result_dir_path)

            result_path = File.join(result_dir_path, File.basename(@source_project_path))

            FileUtils.cp_r(@source_project_path, result_dir_path, remove_destination:true)

            return result_path    
        end

        # Set paths in xcodeproj to source xcodeproj paths
        def change_base_path(xcodeproj_path)

            source_project = Xcodeproj::Project.open(@source_project_path)
            project = Xcodeproj::Project.open(xcodeproj_path)

            project.groups.each do |group|
                source_group = source_project.groups.select{|x| x.name == group.name && x.path == group.path}.first
                if not source_group.nil?
                    if source_group.path.nil?
                        group.name = source_group.name
                    else
                        group.name = File.basename(source_group.path, ".*")
                    end
                    group.path = source_group.real_path.to_s
                end
            end

            project.save
        end

        # Create new workspace with xcodeproj
        def create_workspace(name, source_dir_path, xcodeproj_path)

            # Configure path

            result_path = File.join(source_dir_path, name + ".xcworkspace")

            if File.exist?(result_path)
                FileUtils.rm_r(result_path)
            end

            # Create and configure workspace

            workspace = Xcodeproj::Workspace.new_from_xcworkspace(result_path)

            workspace << xcodeproj_path

            workspace.save_as(result_path)

            return result_path

        end

        # Create framework directory with Info.plist and header file
        def create_framework_dir(source_dir_path, framework_name)

            result_dir_path = File.join(source_dir_path, framework_name)

            if not Dir.exist?(result_dir_path)
                Dir.mkdir(result_dir_path)
            end

            [["Info.plist", "Info.plist.erb"], [framework_name + ".h", "Framework.h.erb"]]
            .each { | (result_file_name, template_file_name) |
                result_path = File.join(result_dir_path, result_file_name)
                template = ERB.new(File.read(File.join(TEMPLATES_DIR_PATH, template_file_name)))
                result_content = template.result(binding)
                File.open(result_path, "w") do |file|
                    file.puts result_content
                end
            }

            return result_dir_path
        end

        # Create playground package
        def create_playground(source_dir_path, playground_name, framework_name)
            
            result_dir_path = File.join(source_dir_path, playground_name + ".playground")

            if not Dir.exist?(result_dir_path)
                Dir.mkdir(result_dir_path)
            end

            [["Contents.swift", "Contents.swift.erb"], ["contents.xcplayground", "contents.xcplayground.erb"]]
            .each { | (result_file_name, template_file_name) |
                result_path = File.join(result_dir_path, result_file_name)
                template = ERB.new(File.read(File.join(TEMPLATES_DIR_PATH, "Playground", template_file_name)))
                result_content = template.result(binding)
                File.open(result_path, "w") do |file|
                    file.puts result_content
                end
            }

            return result_dir_path
        end

         # Add framework target to xcodeproj
        def add_framework_target(framework_name, xcodeproj_path)

            project = Xcodeproj::Project.open(xcodeproj_path)

            # Create framework support files
            dir_path = File.dirname(xcodeproj_path)
            framework_dir_path = create_framework_dir(dir_path, framework_name)
            
            # Create group and add files to xcodeproj
            framework_group = project.new_group(framework_name, framework_dir_path)
            Dir.entries(framework_dir_path).select{|x| x != "." && x != ".."}.each {|x| framework_group.new_file(x) }

            # Create framework target
            target = project.new_target(:framework, framework_name, :ios, nil, nil, :swift)

            # Add header file build phase
            header_file = framework_group.files.select { |file| File.extname(file.path) == '.h'}.first
            headers_build_phase = project.new(Xcodeproj::Project::Object::PBXHeadersBuildPhase)
            target.build_phases << headers_build_phase
            
            headers_build_phase.add_file_reference(header_file)
            header_file.build_files.each do |buildFile|
              buildFile.settings = { "ATTRIBUTES" => ["Public"] }
            end

            # Set path to Info.plist file
            target.build_configurations.each { |configuration| target.build_settings(configuration.name)['INFOPLIST_FILE'] = File.join(framework_name, "Info.plist") }

            # Save changes
            project.save
        end

        # Create Xcode Playground package and add to workspace
        def add_playground_to_workspace(playground_name, framework_name, workspace_path)
            
            # Create playground
            dir_path = File.dirname(workspace_path)
            playground_path = create_playground(dir_path, playground_name, framework_name)

            # Add playground to workspace
            workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)
            workspace << playground_path

            # Save changes
            workspace.save_as(workspace_path)
        end

        # Copy xcodeproj to external path and wrap it into workspace with playground
        def create_separate_workspace_with_backyard(result_dir_path)

            base_name = "Backyard"
            framework_name = base_name + "Framework"
            playground_name = base_name + "Playground"
            workspace_name = File.basename(@source_project_path, ".*") + "-" + base_name

            # Copy xcodeproj and update paths
            result_proj_path = self.copy_xcodeproj_file(result_dir_path)
            self.change_base_path(result_proj_path)

            # Add framework target in result xcodeproj
            self.add_framework_target(framework_name, result_proj_path)

            # Create workspace with result xcodeproj
            workspace_path = self.create_workspace(workspace_name, result_dir_path, result_proj_path)

            # Add playground to workspace
            self.add_playground_to_workspace(playground_name, framework_name, workspace_path)

            return workspace_path, result_proj_path
        end

    end

end

proj_file = ARGV[0]
result_dir = File.join(ARGV[1], "TestDir")

backyard = XCBackyard::BackyardBuilder.new(proj_file)

workspace_path, result_proj_path = backyard.create_separate_workspace_with_backyard(result_dir)

system("open " + workspace_path)

