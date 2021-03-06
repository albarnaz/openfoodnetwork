require 'spree/localized_number'

module Spree
  Calculator::PerItem.class_eval do
    extend Spree::LocalizedNumber

    localize_number :preferred_amount

    def self.description
      I18n.t(:flat_rate_per_item)
    end

    def compute(object=nil)
      return 0 if object.nil?
      self.preferred_amount * line_items_for(object).reduce(0) do |sum, value|
        if matching_products.blank? || matching_products.include?(value.product)
          value_to_add = value.quantity
        else
          value_to_add = 0
        end
        sum + value_to_add
      end
    end
  end
end
