class TimeConversion

  MILITARY_TIME_LIMITS = {hours: 23, minutes: 59, seconds: 59}

  def self.hms_to_seconds(hms)
    return nil unless hms.present?
    negative = hms.start_with?('-')
    components = hms.sub(/\A-/, '').split(':')
    milliseconds_present = components.last.include?('.')
    numeric_method = milliseconds_present ? :to_f : :to_i
    units = %w(hours minutes seconds)
    seconds = components.zip(units).map { |component, unit| component.send(numeric_method).send(unit) }
        .sum.send(numeric_method)
    negative ? -seconds : seconds
  end

  def self.seconds_to_hms(seconds_elapsed)
    seconds_elapsed ? to_hms(seconds_elapsed / 1.hour,
                             (seconds_elapsed / 1.minute) % 1.minute,
                             seconds_elapsed % 1.minute) : ''
  end

  def self.absolute_to_hms(absolute)
    return '' unless absolute
    time = absolute.is_a?(Date) ? absolute.to_time : absolute
    to_hms(time.hour, time.min, time.sec)
  end

  def self.components_to_absolute(components)
    DateTime.new(components['date(1i)'].to_i,
                 components['date(2i)'].to_i,
                 components['date(3i)'].to_i,
                 components['date(4i)'].to_i,
                 components['date(5i)'].to_i)
  end

  def self.to_hms(hours, minutes, seconds)
    hundredths = (seconds % 1 * 100).to_i
    seconds.is_a?(Integer) ?
        format('%02d:%02d:%02d', hours, minutes, seconds) :
        format('%02d:%02d:%02d.%02d', hours, minutes, seconds, hundredths)
  end

  def self.file_to_military(time_string)
    number_string = time_string ? time_string.gsub(/[^\d]/, '') : ''
    return nil unless number_string.length.between?(3, 6)
    military = number_string.rjust((number_string.length / 2.0).ceil * 2, '0').ljust(6, '0')
                   .chars.each_slice(2).map(&:join).join(':')
    valid_military?(military) ? military : nil
  end

  def self.valid_military?(military)
    time_components = %w(hours minutes seconds).zip(military.split(':')).to_h.symbolize_keys
    time_components.all? { |component, value| value.between?('0', MILITARY_TIME_LIMITS[component].to_s) }
  end

  def self.absolute_to_offset(datetime, event)
    time_zone = ActiveSupport::TimeZone[event.home_time_zone] || Time.zone
    new_datetime = case
                   when datetime.is_a?(Hash)
                     time_zone.local(*datetime.values)
                   when datetime.is_a?(String)
                     time_zone.parse(datetime)
                   else
                     datetime
                   end
    new_datetime - event.start_time
  end
end
