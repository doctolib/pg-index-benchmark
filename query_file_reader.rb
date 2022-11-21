# frozen_string_literal: true

class QueryFileReader
  def initialize(file_path)
    @input_file_path = file_path
  end
  def parse
    incomplete_query = ''
    File.open(@input_file_path, 'r') do |f|
      f.each_line do |query|
        # Merge file lines until we have a full query string ending with a ;
        query.strip!
        query = incomplete_query + query
        next if query.empty? || query == '\n'
        unless query =~ /^.+;$/
          incomplete_query = query + '\n'
          next
        end
        incomplete_query = ''
        query = query.gsub(/\\n/, ' ')

        yield(query)
      end
    end
  end
end
