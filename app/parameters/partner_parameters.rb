class PartnerParameters < BaseParameters

  def self.permitted
    [:id, :name, :event_id, :banner, :banner_link, :weight]
  end
end
