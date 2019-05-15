module CustomAttributes
  module CustomAttributeDefinition
    extend ActiveSupport::Concern
    included do
      scope :by_sort_order, -> { order('sort_order ASC') }
      validates :attr_name, presence: true, format: { with: /^[a-zA-Z\_\s]+$/, multiline: true, message: 'cannot contain special characters.' }
      validates :default_value, format: { with: /^[\+\-]?\d*\.?\d*$/, multiline: true, message: 'should be a number.' }, if: :number_type?
      validate  :can_be_marked_as_unique

      def number_type?
        [CustomAttributes::CustomAttribute::TYPE_NUMBER, CustomAttributes::CustomAttribute::TYPE_DECIMAL].include?(attr_type)
      end

      def text_type?
        attr_type == CustomAttributes::CustomAttribute::TYPE_TEXT
      end
      
      def boolean_type?
        attr_type == CustomAttributes::CustomAttribute::TYPE_BOOLEAN
      end

      def dropdown_type?
        attr_type == CustomAttributes::CustomAttribute::TYPE_DROPDOWN
      end

      def paragraph_type?
        attr_type == CustomAttributes::CustomAttribute::TYPE_MULTILINE_TEXT
      end

      def has_options?
        dropdown_type?
      end

      def save_custom_attribute(selected_option_label)
        begin
          transaction do
            self.custom_attribute_options = [] unless has_options?
            default_value = "" if unique?
            save!
            if has_options?
              update! default_value: custom_attribute_options.find_by(label: selected_option_label).try(:id)
            end
            true
          end
        rescue ActiveRecord::ActiveRecordError => e
          false
        end
      end

      def update_custom_attribute(custom_attribute_params, selected_option_label)
        begin
          transaction do
            custom_attribute_params[:default_value] = "" if unique?
            update!(custom_attribute_params)
            if has_options?
              update! default_value: custom_attribute_options.find_by(label: selected_option_label).try(:id)
            end
            true
          end
        rescue ActiveRecord::ActiveRecordError => e
          false
        end
      end

      def default_option
        custom_attribute_options.find_by(id: default_value)
      end

      def can_be_marked_as_unique
        if unique? 
          if !can_be_unique?
            errors.add :base, 'Can not be made as unique!'
          elsif has_duplicate_values?
            errors.add :base, 'Remove duplicate values first to make is unique.'
          end
        end
        errors.blank?
      end

      def can_be_unique?
        text_type? || number_type?
      end

      def has_duplicate_values?
        column = {
          CustomAttributes::CustomAttribute::TYPE_TEXT    => 'string_value', 
          CustomAttributes::CustomAttribute::TYPE_NUMBER  => 'integer_value', 
          CustomAttributes::CustomAttribute::TYPE_DECIMAL => 'double_value', 
        }[attr_type]
        return false if column.blank?
        cavs_counts = custom_attribute_values.where("#{column} IS NOT NULL").select("#{column}, count(*) as values_count").group(column).order('values_count desc')
        duplicate = false
        cavs_counts.each do |cav_count|
          if cav_count.values_count > 1
            duplicate = true
            break
          end
        end
        duplicate
      end
    end
  end
end