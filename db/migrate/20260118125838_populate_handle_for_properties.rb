class PopulateHandleForProperties < ActiveRecord::Migration[8.0]
  require 'securerandom'

  def up
    Property.where(handle: nil).find_each do |property|
      handle = generate_handle(property.title)
      
      # Убеждаемся что handle уникален
      counter = 1
      base_handle = handle
      while Property.where.not(id: property.id).exists?(handle: handle)
        handle = "#{base_handle}_#{counter}"
        counter += 1
      end
      
      property.update_column(:handle, handle)
    end
  end

  def down
    # Не нужно ничего делать при откате
  end

  private

  def transliterate(text)
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

  def generate_handle(title)
    transliterated = transliterate(title)
    handle = transliterated.downcase
      .gsub(/[^a-z0-9\s]/, '')
      .gsub(/\s+/, '_')
      .gsub(/_+/, '_')
      .gsub(/^_|_$/, '')
    
    if handle.blank? || handle.length < 2
      handle = "property_#{SecureRandom.hex(4)}"
    end
    
    handle
  end
end
