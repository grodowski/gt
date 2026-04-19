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

    # Build the full linear stack containing `from`, from root to tip.
    # Walks UP from `from` to find the root, then DOWN to find any children.
    def self.build_all(from: GT::Git.current_branch)
      all = GT::Git.all_branches
      managed = all.select { |b| GT::Git.gt_parent(b) }
      return [from] if managed.empty?

      # Walk UP from `from` to root (reuse build)
      result = build(from: managed.include?(from) ? from : managed.first)

      # Walk DOWN from the tip following child pointers
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
      branches = build_all
      branches.each_with_index do |branch, i|
        prefix = i == 0 ? "" : ("  " * i) + "└─ "
        if branch == current
          output.puts GT::UI.render("#{prefix}{{green:#{branch} *}}")
        else
          output.puts "#{prefix}#{branch}"
        end
      end
    end
  end
end
