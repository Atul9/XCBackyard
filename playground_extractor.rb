def make_project_playground(source_project_path, result_dir_path)
    require 'fileutils'

    if Dir.exist?(result_dir_path)
        FileUtils.rm_r(result_dir_path)
    end

    Dir.mkdir(result_dir_path)

    result_path = File.join(result_dir_path, File.basename(source_project_path))

    FileUtils.cp_r(source_project_path, result_dir_path, remove_destination:true)

    return result_path    
end

def change_base_path(xcodeproj_path, source_xcodeproj_path)

    require 'xcodeproj'

    source_project = Xcodeproj::Project.open(source_xcodeproj_path)
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

def create_workspace(source_dir_path, xcodeproj_path)

    require 'xcodeproj'

    result_path = File.join(source_dir_path, "Test.xcworkspace")

    if File.exist?(result_path)
        FileUtils.rm_r(result_path)
    end

    workspace = Xcodeproj::Workspace.new_from_xcworkspace(result_path)

    workspace << xcodeproj_path

    workspace.save_as(result_path)

    return result_path

end

def create_framework_dir(source_dir_path, framework_name)

    def create_info_plist(dir_path)

        require 'erb'

        result_path = File.join(dir_path, "Info.plist")
        template = ERB.new(File.read(File.join("Templates", "Info.plist.erb")))
        result_content = template.result(binding)
        File.open(result_path, "w") do |file|
            file.puts result_content
        end
    end

    def create_header_file(dir_path, framework_name)

        require 'erb'

        result_path = File.join(dir_path, framework_name + ".h")
        template = ERB.new(File.read(File.join("Templates", "Framework.h.erb")))
        result_content = template.result(binding)
        File.open(result_path, "w") do |file|
            file.puts result_content
        end
    end

    result_dir_path = File.join(source_dir_path, framework_name)

    if not Dir.exist?(result_dir_path)
        Dir.mkdir(result_dir_path)
    end

    create_info_plist(result_dir_path)
    create_header_file(result_dir_path, framework_name)

    return result_dir_path
end

def create_playground(source_dir_path, framework_name)
    
    require 'erb'

    def create_contents_swift(dir_path, framework_name)

        result_path = File.join(dir_path, "Contents.swift")
        template = ERB.new(File.read(File.join("Templates", "Playground", "Contents.swift.erb")))
        result_content = template.result(binding)
        File.open(result_path, "w") do |file|
            file.puts result_content
        end
    end

    def create_contents_config(dir_path, framework_name)

        result_path = File.join(dir_path, "contents.xcplayground")
        template = ERB.new(File.read(File.join("Templates", "Playground", "contents.xcplayground.erb")))
        result_content = template.result(binding)
        File.open(result_path, "w") do |file|
            file.puts result_content
        end
    end

    result_dir_path = File.join(source_dir_path, framework_name + ".playground")

    if not Dir.exist?(result_dir_path)
        Dir.mkdir(result_dir_path)
    end

    create_contents_swift(result_dir_path, framework_name)
    create_contents_config(result_dir_path, framework_name)

    return result_dir_path
end

def add_playground_framework_target(xcodeproj_path, workspace_path)

    require 'xcodeproj'

    project = Xcodeproj::Project.open(xcodeproj_path)

    # first_non_test_target = project.targets.select{ |x| not x.test_target_type? }.first

    dir_path = File.dirname(xcodeproj_path)
    framework_name = "TestPlaygroundFramework"
    framework_dir_path = create_framework_dir(dir_path, framework_name)
    framework_group = project.new_group(framework_name, framework_dir_path)
    Dir.entries(framework_dir_path).select{|x| x != "." && x != ".."}.each {|x| framework_group.new_file(x) }

    target = project.new_target(:framework, framework_name, :ios, nil, nil, :swift)

    header_file = framework_group.files.select { |file| File.extname(file.path) == '.h'}.first
    headers_build_phase = project.new(Xcodeproj::Project::Object::PBXHeadersBuildPhase)
    target.build_phases << headers_build_phase
    
    headers_build_phase.add_file_reference(header_file)
    header_file.build_files.each do |buildFile|
      buildFile.settings = { "ATTRIBUTES" => ["Public"] }
    end

    target.build_settings('Debug')['INFOPLIST_FILE'] = File.join(framework_name, "Info.plist")
    
    project.save

    # Create playground

    playground_path = create_playground(dir_path, framework_name)

    # Add playground to workspace

    workspace = Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)

    workspace << playground_path

    workspace.save_as(workspace_path)

end

# ruby playground_extractor.rb "/Users/gregoryvit/Development/Swift/surf/NaviAddress-iOS/NaviAddress-iOS.xcodeproj" "/Users/gregoryvit/Development/Swift/surf"

proj_file = ARGV[0]
result_dir = File.join(ARGV[1], "TestDir")

result_proj_path = make_project_playground(proj_file, result_dir)

change_base_path(result_proj_path, proj_file)

workspace_path = create_workspace(result_dir, result_proj_path)

add_playground_framework_target(result_proj_path, workspace_path)

system("open " + workspace_path)

# system("sleep 3; osascript run_xcode.scpt")

