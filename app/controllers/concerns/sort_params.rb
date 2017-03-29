module SortParams
  def self.sort_fields(sort, allowed, default)
    allowed = allowed.map(&:to_s)
    fields = sort.to_s.split(',')

    ordered_fields = convert_to_ordered_hash(fields)
    filtered_fields = ordered_fields.slice(*allowed)

    filtered_fields.present? ? filtered_fields.symbolize_keys : default
  end

  def self.sql_string(sort_fields)
    sort_fields.to_h.map { |field, direction| "#{field} #{direction}"}.join(', ')
  end

  def self.convert_to_ordered_hash(fields)
    fields.each_with_object({}) do |field, hash|
      if field.start_with?('-')
        field = field[1..-1]
        hash[field] = :desc
      else
        hash[field] = :asc
      end
    end
  end
end