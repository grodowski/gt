# frozen_string_literal: true

module GT
  class Stack
    # Walk UP from a branch to its root, returns [root, ..., from]
    def self.build(from: GT::Git.current_branch)
      branches = []
      branch = from
      while (parent = GT::Git.gt_parent(branch))
        branches.unshift(branch)
        branch = parent
      end
      branches.unshift(branch)
      branches
    end

    # Build the full linear stack from root down, scanning all local branches.
    # Returns [root, child, grandchild, ...] regardless of current branch.
    def self.build_all
      all = GT::Git.all_branches
      managed = all.select { |b| GT::Git.gt_parent(b) }
      return [GT::Git.current_branch] if managed.empty?

      # Walk from any managed branch up to find root
      root = GT::Git.gt_parent(managed.first)
      root = GT::Git.gt_parent(root) while GT::Git.gt_parent(root)

      # Walk down from root following parent pointers
      result = [root]
      loop do
        child = managed.find { |b| GT::Git.gt_parent(b) == result.last }
        break unless child

        result << child
        managed.delete(child)
      end
      result
    end

    def self.print(from: GT::Git.current_branch, output: $stdout)
      current = GT::Git.current_branch
      branches = build(from: from)
      branches.each_with_index do |branch, i|
        prefix = i == 0 ? "" : ("  " * i) + "└─ "
        marker = branch == current ? " *" : ""
        output.puts "#{prefix}#{branch}#{marker}"
      end
    end
  end
end
