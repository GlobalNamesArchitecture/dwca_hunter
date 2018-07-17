module DwcaHunter
  module XML
    def self.escape(input)
      result = input.dup.strip

      result.gsub!(/[&<>'"]/) do | match |
          case match
          when '&' then '&amp;'
          when '<' then '&lt;'
          when '>' then '&gt;'
          when "'" then '&apos;'
          when '"' then '&quot;'
          end
      end
      result
    end

    def self.unescape(input)
      result = input.dup.strip

      result.gsub!(/&[a-z]+;/) do | match |
          case match
          when '&amp;'  then '&'
          when '&lt;'   then '<'
          when '&gt;'   then '>'
          when '&apos;' then "'"
          when '&quot;' then '"'
          end
      end
      result
    end
  end
end
