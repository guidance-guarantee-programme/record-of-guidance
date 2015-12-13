class OutputDocument
  class HTMLRenderer
    include ActionView::Helpers::TextHelper

    attr_accessor :output_document

    def initialize(output_document)
      @output_document = output_document
    end

    def render
      template.render(output_document)
    end

    private

    def template
      template_id = case output_document.variant
                    when 'other'    then 'ineligible'
                    when 'standard' then 'base'
                    end

      Output::Templates.template(template_id)
    end
  end
end
