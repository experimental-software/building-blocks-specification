#!/usr/bin/env ruby

mode, changelog_file, examples_dir = ARGV
abort "usage: migrate-example-properties.rb check|migrate CHANGELOG EXAMPLES_DIR" unless
  ["check", "migrate"].include?(mode) && changelog_file && examples_dir

def changelog_operations(changelog_file)
  lines = File.readlines(changelog_file, chomp: true)
  unreleased = []
  in_unreleased = false

  lines.each do |line|
    if line.start_with?("## ")
      break if in_unreleased
      in_unreleased = line == "## [Unreleased]"
      next
    end
    unreleased << line if in_unreleased
  end

  operations = []
  unreleased.each do |line|
    text = line.sub(/\A-\s*/, "").sub(/\*\*BREAKING:\*\*\s*/, "")
    backticks = text.scan(/`([^`]+)`/).flatten

    if text =~ /\b(?:renamed|rename|moved|move|replaced|replace|changed|change)\b/i &&
       text =~ /\b(?:to|as|with|into)\b/i
      old_name, new_name = backticks.first(2)
      unless old_name && new_name
        names = text.scan(/(?<![A-Za-z0-9_-])([A-Za-z][A-Za-z0-9_-]*)(?![A-Za-z0-9_-])/).flatten
        old_name ||= names[0]
        new_name ||= names[1]
      end
      if old_name && new_name
        operations << [:rename, old_name, new_name, component_type(text)]
      end
    elsif text =~ /\b(?:removed|remove|deleted|delete)\b/i
      name = backticks.first
      unless name
        names = text.scan(/(?<![A-Za-z0-9_-])([A-Za-z][A-Za-z0-9_-]*)(?![A-Za-z0-9_-])/).flatten
        name = names.find { |candidate| !%w[property properties component components from].include?(candidate.downcase) }
      end
      operations << [:remove, name, nil, component_type(text)] if name
    end
  end
  operations
end

def component_type(text)
  match = text.match(/(?:for|on|of|in)\s+`?([A-Za-z][A-Za-z0-9_-]*)`?\s+components?/i)
  match ? match[1] : nil
end

def key_line?(line, name)
  line.match?(/^\s*(?:["']#{Regexp.escape(name)}["']|#{Regexp.escape(name)})\s*:/)
end

def migrate_text(text, operations)
  changed = false
  output = []
  lines = text.lines
  index = 0

  while index < lines.length
    line = lines[index]
    operation_applied = false

    operations.each do |operation, old_name, new_name, _component_type|
      next unless key_line?(line, old_name)

      case operation
      when :rename
        indent = line[/^\s*/]
        if line =~ /^(\s*)(["'])#{Regexp.escape(old_name)}\2/
          line = line.sub(/^(\s*)(["'])#{Regexp.escape(old_name)}\2/, "\\1\\2#{new_name}\\2")
        elsif line =~ /^#{Regexp.escape(indent)}#{Regexp.escape(old_name)}\s*:/
          line = line.sub(/^(#{Regexp.escape(indent)})#{Regexp.escape(old_name)}(\s*:)/, "\\1#{new_name}\\2")
        end
        output << line
        changed = true
        operation_applied = true
      when :remove
        indent_length = line[/^\s*/].length
        changed = true
        operation_applied = true
        index += 1
        while index < lines.length
          child = lines[index]
          break if child.strip.empty? == false && child[/^\s*/].length <= indent_length
          index += 1
        end
        next
      end
      break if operation_applied
    end

    unless operation_applied
      output << line
    end
    index += 1
  end

  [output.join, changed]
end

operations = changelog_operations(changelog_file)
exit 0 if operations.empty?

stale = false
changed_files = []
Dir.glob(File.join(examples_dir, "**", "*.{yml,yaml}")).sort.each do |file|
  next unless File.file?(file)

  text = File.read(file)
  migrated, changed = migrate_text(text, operations)
  stale ||= changed

  if mode == "migrate" && changed
    File.write(file, migrated)
    changed_files << file
  end
end

if mode == "check"
  exit stale ? 1 : 0
end

changed_files.each { |file| puts "Migrated #{file}" }
