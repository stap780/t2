# frozen_string_literal: true

class IncaseReportService
  def initialize(scope:)
    @scope = scope
  end

  def rows
    @scope
  end

  def totals
    scope = @scope
    {
      totalsum: scope.sum { |i| (i.totalsum || 0).to_f },
      items_sum: scope.sum { |i| i.items_sum.to_f },
      items_sale_sum: scope.sum { |i| i.items_sale_sum.to_f },
      strah_amount: scope.sum { |i| i.strah_amount.to_f },
      count: scope.size,
      priced_count: scope.count(&:priced?),
      unpriced_count: scope.count { |i| !i.priced? }
    }
  end

  def chart_data
    # Single pass: accumulate totalsum, items_sum, items_sale_sum, strah_amount per month
    acc = Hash.new { |h, k| h[k] = { totalsum: 0.0, items_sum: 0.0, items_sale_sum: 0.0, strah_amount: 0.0 } }
    @scope.each do |i|
      next unless i.date.present?
      month_key = Date.new(i.date.year, i.date.month, 1)
      acc[month_key][:totalsum] += (i.totalsum || 0).to_f
      acc[month_key][:items_sum] += i.items_sum.to_f
      acc[month_key][:items_sale_sum] += i.items_sale_sum.to_f
      acc[month_key][:strah_amount] += i.strah_amount.to_f
    end
    sorted_months = acc.keys.sort
    labels = sorted_months.map { |d| I18n.l(d, format: '%B %Y') }

    {
      labels: labels,
      datasets: [
        {
          label: 'Сумма',
          data: sorted_months.map { |d| acc[d][:totalsum] },
          backgroundColor: 'rgba(124, 58, 237, 0.5)',
          borderColor: 'rgb(124, 58, 237)'
        },
        {
          label: 'Сумма деталей',
          data: sorted_months.map { |d| acc[d][:items_sum] },
          backgroundColor: 'rgba(59, 130, 246, 0.5)',
          borderColor: 'rgb(59, 130, 246)'
        },
        {
          label: 'Сумма продажных цен',
          data: sorted_months.map { |d| acc[d][:items_sale_sum] },
          backgroundColor: 'rgba(34, 197, 94, 0.5)',
          borderColor: 'rgb(34, 197, 94)'
        },
        {
          label: 'В страховую',
          data: sorted_months.map { |d| acc[d][:strah_amount] },
          backgroundColor: 'rgba(234, 88, 12, 0.5)',
          borderColor: 'rgb(234, 88, 12)'
        }
      ]
    }
  end
end
