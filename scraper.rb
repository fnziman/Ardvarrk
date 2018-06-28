require 'nokogiri'
require 'net/http'
require 'byebug'

def scan_page
  uri = URI('http://dv.njtransit.com/mobile/tid-mobile.aspx?sid=NY')
  body = Net::HTTP.get(uri)

  document = Nokogiri::HTML(body)
  rows = document.css('tr')[3..-1]

  rows = rows_to_a(rows)
  log_boarding = Hash.new
  log_other = Hash.new

  status = [
    'BOARDING',
    'STAND BY',
    'DELAYED',
  ]

  rows.each do |row|
      next unless status.include?(row.last) && !amtrack?(row)
      parsed = parse_row(row, row.last)
      timestamp = create_timestamp(row)

      if parsed[:status] == status.first
          log_boarding[timestamp] = parsed
      elsif status[1..2].include?(parsed[:status])
          log_other[timestamp] = parsed
      end

  end

  unless log_boarding.empty?
      puts "BOARDING LOG"
      pretty_print(log_boarding)
  end

  unless log_other.empty?
      puts "OTHER LOGS"
      pretty_print(log_other)
  end
end

def rows_to_a(rows)
    arr = rows.map do |row|
        half_parsed = row.text.split("\n").map{|el| el.chomp!.strip}
        full_parsed = half_parsed.select{|el| el != ""}
    end

    arr.uniq! #for some reason there are duplicates
end

def amtrack?(row)
    row[-2][0] == 'A'  ##Amtrack train numbers start with 'A'
end

def parse_row(row, status)
    result = Hash.new

    result[:time] = row[0]
    result[:track] = status == 'BOARDING' ? row[2] : nil
    result[:line] = row[-3]
    result[:train_number] = row[-2]
    result[:status] = row[-1]

    result
end

def determine_unit(train_time)
    train_hour = train_time.split(':').first.to_i
    cur_time = Time.now
    cur_hour = cur_time.hour

    if cur_hour == train_hour || cur_hour % 12 == train_hour
        return cur_time.strftime("%p")
    ##In the case that the train starts boarding on the next hour,
    ##which is the opposit unit of the current hour
    ##vvvvvvv##
    elsif train_hour == cur_hour % 12 + 1
        return cur_hour + 1 < 12 ? 'AM' : 'PM'
    else
        puts "ERROR IN DETEMINE UNIT TIME"
    end
end

def create_timestamp(row)
  time = Time.now
  unit = determine_unit(row.first)

  timestamp = time.year.to_s + time.month.to_s + time.day.to_s + '-' + row.first + unit
end

def pretty_print(hash)
    print "TIME     TRACK         LINE          TRAIN #     STATUS\n"
    hash.each_value do |info|
        puts info.values.join('     ')
    end
end

scan_page
