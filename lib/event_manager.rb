require 'csv'
require 'google/apis/civicinfo_v2'
require "erb"
require "time"


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def get_hour(time)
    date = convert_to_date(time)
    date.hour

end

def get_day(time)
    date = convert_to_date(time)
    date.strftime("%A")
end

def convert_to_date(time)
    date = time.split(" ")[0].split("/")
    hours = time.split(" ")[1].split(":")

    date[2] = date[2].rjust(4, "20")
    date = Time.strptime(date.join(" "), "%m %d %Y")

    date += (hours[0].to_i * 60 * 60) + (hours[1].to_i * 60)

    date
end

def clean_phonenumber(phonenumber)


    phonenumber = phonenumber.scan(/\d/).join

    if  phonenumber.length < 10 || phonenumber.length > 11
        "0000000000"
    elsif phonenumber.length == 11 && phonenumber[0] == "1"
        phonenumber[1..10]
    elsif phonenumber.length == 11 && phonenumber[0] != "1"
        "0000000000"
    else
        phonenumber
    end


end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    )
    legislators = legislators.officials
    legislator_names = legislators.map(&:name)
    legislator_names.join(", ")
  rescue
    legislators_names = 'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exists?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
      file.puts form_letter
  end
end
puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter

$mostRegisterHour = {}
$mostRegisterDay = {}
def most_register_hour(hour)
    if $mostRegisterHour.has_key?("#{hour}")
      $mostRegisterHour["#{hour}"] += 1
    else
      $mostRegisterHour["#{hour}"] = 1
    end
end

def most_register_day(day)
    if $mostRegisterDay.has_key?("#{day}")
      $mostRegisterDay["#{day}"] += 1
    else
      $mostRegisterDay["#{day}"] = 1
    end
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phonenumber = clean_phonenumber(row[:homephone])
  registrationHour = row[:regdate]
  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)


  save_thank_you_letter(id, form_letter)
  clean_phonenumber(phonenumber)
  most_register_hour(get_hour(registrationHour))
  most_register_day(get_day(registrationHour))


end

def largest_hash_key(hash)
  hash.max_by{|k,v| v}
end

puts "The most visited hours is #{largest_hash_key($mostRegisterHour)[0]}, #{largest_hash_key($mostRegisterHour)[1]} times"

puts "The most visited day is #{largest_hash_key($mostRegisterDay)[0]}, #{largest_hash_key($mostRegisterDay)[1]} times"


