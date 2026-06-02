class ExportFilterRulesController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_export
  before_action :set_export_filter_rule, only: %i[edit update destroy characteristics]


  def new
    @export_filter_rule = @export.export_filter_rules.build(
      rule_key: ExportFilterRule::RULE_KEY_FEATURE,
      rule_condition: "eq"
    )
    respond_to do |format|
      format.turbo_stream
    end
  end

  def create
    @export_filter_rule = @export.export_filter_rules.build(export_filter_rule_params)
    respond_to do |format|
      if @export_filter_rule.save
        format.turbo_stream
      end
    end
  end

  def edit; end

  def update
    @export_filter_rule.update(export_filter_rule_params)
    respond_to do |format|
      if @export_filter_rule.update(export_filter_rule_params)
        format.turbo_stream
      end
    end
  end

  def destroy
    @export_filter_rule.destroy if @export_filter_rule.persisted?
    respond_to do |format|
      format.turbo_stream do
        flash.now[:success] = t('.success')
        render turbo_stream: [
          turbo_stream.remove(dom_id(@export_filter_rule)),
          render_turbo_flash
        ]
      end
      format.html { redirect_to edit_export_path(@export), notice: t('.success') }
    end
  end

  def characteristics
    property_id = params[:property_id]
    @export_filter_rule.property_id = property_id.to_i

    respond_to do |format|
      format.turbo_stream do
        flash.now[:success] = t('.success')
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(@export_filter_rule),
            partial: "export_filter_rules/export_filter_rule",
            locals: { export: @export, export_filter_rule: @export_filter_rule }
          ),
          render_turbo_flash
        ]
      end
      format.html { redirect_to edit_export_path(@export) }
    end
  end

  private

  def set_export
    if params[:export_id].present?
      @export = Export.find(params[:export_id])
    else
      # Для новых записей создаем временный объект
      @export = Export.new
    end
  end

  def set_export_filter_rule
    @export_filter_rule = @export.export_filter_rules.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @export_filter_rule = @export.export_filter_rules.build(id: params[:id])
  end

end
