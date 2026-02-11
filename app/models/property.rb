class Property < ApplicationRecord
  include ActionView::RecordIdentifier

  has_many :features, dependent: :destroy
  has_many :products, -> { where(features: { featureable_type: 'Product' }) }, through: :features, source: :featureable, source_type: 'Product'
  has_many :detal_features, -> { where(featureable_type: 'Detal') }, class_name: 'Feature'
  has_many :detals, through: :detal_features, source: :featureable, source_type: 'Detal'
  has_many :characteristics, -> { order(title: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :characteristics, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true, uniqueness: true
  validates :handle, uniqueness: true, allow_nil: true

  before_validation :generate_handle_from_title, if: -> { handle.blank? || title_changed? }

  private

  def generate_handle_from_title
    # Транслитерация русского текста в латиницу
    transliterated = transliterate(title)
    # Убираем все кроме букв, цифр и пробелов, заменяем пробелы на подчеркивания
    self.handle = transliterated.downcase
      .gsub(/[^a-z0-9\s]/, '')
      .gsub(/\s+/, '_')
      .gsub(/_+/, '_')
      .gsub(/^_|_$/, '')
    
    # Если handle пустой или слишком короткий, используем fallback
    if handle.blank? || handle.length < 2
      self.handle = "property_#{SecureRandom.hex(4)}"
    end
    
    # Убеждаемся что handle уникален
    ensure_unique_handle
  end

  def ensure_unique_handle
    base_handle = handle
    counter = 1
    while Property.where.not(id: id || 0).exists?(handle: handle)
      self.handle = "#{base_handle}_#{counter}"
      counter += 1
    end
  end

  def transliterate(text)
    # Простая транслитерация русского текста в латиницу
    text.to_s
      .gsub(/[аА]/, 'a').gsub(/[бБ]/, 'b').gsub(/[вВ]/, 'v').gsub(/[гГ]/, 'g')
      .gsub(/[дД]/, 'd').gsub(/[еЕёЁ]/, 'e').gsub(/[жЖ]/, 'zh').gsub(/[зЗ]/, 'z')
      .gsub(/[иИ]/, 'i').gsub(/[йЙ]/, 'y').gsub(/[кК]/, 'k').gsub(/[лЛ]/, 'l')
      .gsub(/[мМ]/, 'm').gsub(/[нН]/, 'n').gsub(/[оО]/, 'o').gsub(/[пП]/, 'p')
      .gsub(/[рР]/, 'r').gsub(/[сС]/, 's').gsub(/[тТ]/, 't').gsub(/[уУ]/, 'u')
      .gsub(/[фФ]/, 'f').gsub(/[хХ]/, 'h').gsub(/[цЦ]/, 'ts').gsub(/[чЧ]/, 'ch')
      .gsub(/[шШ]/, 'sh').gsub(/[щЩ]/, 'sch').gsub(/[ъЪьЬ]/, '').gsub(/[ыЫ]/, 'y')
      .gsub(/[эЭ]/, 'e').gsub(/[юЮ]/, 'yu').gsub(/[яЯ]/, 'ya')
  end
end
