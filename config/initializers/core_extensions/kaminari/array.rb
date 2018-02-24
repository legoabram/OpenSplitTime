class Array
  def page(page_number)
    Kaminari.paginate_array(self).page(page_number)
  end
end
