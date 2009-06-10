
module Librarian

  class << self
    def libs opts={}
      opts[:libs] ||= {}
      #puts opts.inspect
      path = opts[:path] || $LOAD_PATH
      if path.is_a? Array
        path.each {|lp| libs(opts.merge :path => lp) }
      else
        sub = opts[:sub_path] || ''
        full = File.join(path, sub)
        if File.exist? full
          if File.directory? full
            #puts "[searching dir #{path}]"
            if opts[:depth].nil? || opts[:depth] > 0
              Dir.new(full).
                reject{|p| ['.','..'].include? File.basename(p) }.
                each {|p| libs opts.merge :sub_path => File.join(sub,p),
                                          :depth => (if opts[:depth]
                                                     then opts[:depth]-1
                                                     else nil end) }
            end
          elsif full =~ /\.rb$/
            opts[:libs][sub.gsub(/^[\.\/]*|\.rb$/,'')] = full
          end
        end
      end
      return opts[:libs]
    end # def libs

  end
end

class Object
  def lslibs
    puts Librarian.libs(:depth=>1).keys.sort.columnize((ENV["COLUMNS"].to_i rescue 78))
  end
end
