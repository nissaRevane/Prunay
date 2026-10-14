# Un champ corrigé au clic rappelle en filigrane la valeur que la création aurait proposée.
class InlineEditFormBuilder < ActionView::Helpers::FormBuilder
  def number_field(method, options = {})
    super(method, { placeholder: @template.default_placeholder(object.defaults[method.to_s]) }.merge(options))
  end
end
