# frozen_string_literal: true

module DocumentationHelper
  def documentation_section_entries(page)
    sections = t("documentation.#{page}.sections", default: {})
    return [] unless sections.is_a?(Hash)

    sections.map do |key, section|
      section = section.with_indifferent_access if section.is_a?(Hash)
      [key, section]
    end
  end
end
