require 'xcodeproj'

project_path = 'MomentumMemosV2.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

main_group = project.main_group.groups.find { |g| g.name == 'MomentumMemosV2' } || project.main_group.groups.find { |g| g.path == 'MomentumMemosV2' }

managers_group = main_group.groups.find { |g| g.name == 'Managers' || g.path == 'Managers' }
viewmodels_group = main_group.groups.find { |g| g.name == 'ViewModels' || g.path == 'ViewModels' }
views_group = main_group.groups.find { |g| g.name == 'Views' || g.path == 'Views' }

unless managers_group && viewmodels_group && views_group
  puts "Groups not found: Managers=#{!!managers_group}, ViewModels=#{!!viewmodels_group}, Views=#{!!views_group}"
  exit 1
end

# Check if files are already added to avoid duplication
def add_file_if_missing(group, target, path)
  file = group.files.find { |f| f.path == path || f.name == path }
  unless file
    file = group.new_file(path)
    target.add_file_references([file])
    puts "Added #{path} to #{group.name}"
  else
    puts "#{path} is already in #{group.name}"
  end
end

add_file_if_missing(managers_group, target, 'StreamingAudioManager.swift')
add_file_if_missing(managers_group, target, 'StreamingTranscriptionClient.swift')
add_file_if_missing(viewmodels_group, target, 'StreamingViewModel.swift')
add_file_if_missing(views_group, target, 'StreamingRecordView.swift')

project.save
puts "Project saved successfully"
